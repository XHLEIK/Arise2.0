package com.arise.controller;

import com.arise.service.ModelConfigService;
import com.arise.service.ModelManagerService;
import com.arise.util.EncryptionUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import org.springframework.http.HttpMethod;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;

import java.util.Map;
import java.util.Collection;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@RestController
@RequestMapping("/api/models")
public class ModelController {

    private final ModelManagerService modelManagerService;
    private final ModelConfigService modelConfigService;
    private final EncryptionUtil encryptionUtil;
    private final WebClient webClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    // In-memory secure store for Cloud API Keys (in production, use Vault or a secure DB)
    private final Map<String, String> cloudApiKeys = new ConcurrentHashMap<>();

    // Globally track installation streams so Flutter can poll `GET /installing`
    private final Map<String, Map<String, Object>> activePulls = new ConcurrentHashMap<>();

    private static final Set<String> VALID_ROLES = Set.of("Conversation", "Coding", "Both", "Idle");
    private static final Set<String> VALID_PROVIDERS = Set.of("openai", "anthropic", "google", "mistral", "groq");
    private static final int MAX_MODEL_NAME_LENGTH = 128;

    public ModelController(
            ModelManagerService modelManagerService,
            ModelConfigService modelConfigService,
            EncryptionUtil encryptionUtil,
            @Qualifier("ollamaWebClient") WebClient webClient) {
        this.modelManagerService = modelManagerService;
        this.modelConfigService = modelConfigService;
        this.encryptionUtil = encryptionUtil;
        this.webClient = webClient;
    }

    @GetMapping("/installing")
    public ResponseEntity<Collection<Map<String, Object>>> getInstallingModels() {
        return ResponseEntity.ok(activePulls.values());
    }

    @GetMapping("/ollama/status")
    public Mono<ResponseEntity<Map<String, Object>>> getOllamaStatus() {
        return webClient.get()
                .uri("/version")
                .retrieve()
                .bodyToMono(Map.class)
                .map(response -> ResponseEntity.ok(Map.<String, Object>of(
                        "installed", true,
                        "running", true,
                        "version", response.get("version"))))
                .onErrorResume(e -> {
                    log.warn("Ollama is not running or not installed.");
                    return Mono.just(ResponseEntity.ok(Map.of(
                            "installed", false,
                            "running", false,
                            "version", "null")));
                });
    }

    @GetMapping("/list")
    public Mono<ResponseEntity<String>> listModels() {
        return webClient.get()
                .uri("/tags")
                .retrieve()
                .bodyToMono(String.class)
                .map(ResponseEntity::ok)
                .onErrorResume(e -> Mono
                        .just(ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body("Ollama unreachable")));
    }

    @GetMapping("/config")
    public ResponseEntity<Map<String, String>> getAllConfigs() {
        return ResponseEntity.ok(modelConfigService.getAllConfigs());
    }

    // Apply configuration roles (Conversation, Coding, Both) to models
    @PostMapping("/config")
    public ResponseEntity<?> configModelRole(@RequestBody Map<String, String> request) {
        String modelName = request.get("model");
        String role = request.get("role");

        if (modelName == null || modelName.isBlank() || role == null || role.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Model and role required"));
        }

        if (!isValidModelName(modelName)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid model name"));
        }

        if (!VALID_ROLES.contains(role)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid role. Allowed: " + VALID_ROLES));
        }

        modelConfigService.setModelRole(modelName, role);
        return ResponseEntity.ok(Map.of("status", "success", "model", modelName, "role", role));
    }

    @PostMapping("/select")
    public ResponseEntity<?> selectModel(@RequestBody Map<String, String> request) {
        String modelName = request.get("model");
        if (modelName == null || modelName.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Model name required"));
        }

        if (!isValidModelName(modelName)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid model name"));
        }

        // This coordinates safe load/unload via Redis Event Bus
        boolean success = modelManagerService.switchModel(modelName);

        if (success) {
            return ResponseEntity.ok(Map.of("status", "success", "active", modelName));
        } else {
            return ResponseEntity.internalServerError().body(Map.of("error", "Failed to switch models safely"));
        }
    }

    // Stream download progress back to Flutter using Server-Sent Events (SSE)
    @PostMapping(value = "/pull", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<String> pullModel(@RequestBody Map<String, String> request) {
        String modelName = request.get("name");
        if (modelName == null || modelName.isBlank()) {
            return Flux.just("{\"error\": \"Model name required\"}");
        }

        if (!isValidModelName(modelName)) {
            return Flux.just("{\"error\": \"Invalid model name\"}");
        }

        log.info("Initiating streaming pull for {}", modelName);

        // Initialize tracking map
        Map<String, Object> state = new ConcurrentHashMap<>();
        state.put("name", modelName);
        state.put("progress", 0);
        state.put("speed", "0 MB/s");
        state.put("status", "Starting...");
        activePulls.put(modelName, state);

        long startTime = System.currentTimeMillis();

        return webClient.post()
                .uri("/pull")
                .bodyValue(java.util.Objects.requireNonNull(Map.of("name", modelName, "stream", true)))
                .retrieve()
                .bodyToFlux(String.class)
                .doOnNext(chunk -> {
                    try {
                        JsonNode json = objectMapper.readTree(chunk);
                        String status = json.has("status") ? json.get("status").asText() : "";
                        state.put("status", status);

                        if (json.has("completed") && json.has("total")) {
                            long completed = json.get("completed").asLong();
                            long total = json.get("total").asLong();
                            if (total > 0) {
                                int percent = (int) ((completed * 100) / total);
                                state.put("progress", percent);

                                long elapsedMs = System.currentTimeMillis() - startTime;
                                if (elapsedMs > 1000) {
                                    long speedBps = (completed / (elapsedMs / 1000));
                                    long speedMbps = speedBps / (1024 * 1024);
                                    state.put("speed", speedMbps + " MB/s");
                                }
                            }
                        }
                    } catch (Exception e) {
                        log.debug("Malformed pull chunk: {}", e.getMessage());
                    }
                })
                .doOnComplete(() -> {
                    log.info("Completed pulling model {}", modelName);
                    activePulls.remove(modelName);
                })
                .doOnError(e -> {
                    log.error("Failed pulling model {}", modelName, e);
                    activePulls.remove(modelName);
                })
                .onErrorResume(e -> Flux.just("{\"error\": \"Failed to pull model. Please check Ollama is running.\"}"));
    }

    @PostMapping("/cloud/add")
    public ResponseEntity<?> addCloudModel(@RequestBody Map<String, String> request) {
        String provider = request.get("provider");
        String apiKey = request.get("apiKey");

        if (provider == null || provider.isBlank() || apiKey == null || apiKey.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Provider and apiKey required"));
        }

        String normalizedProvider = provider.toLowerCase().trim();
        if (!VALID_PROVIDERS.contains(normalizedProvider)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Unsupported provider. Allowed: " + VALID_PROVIDERS));
        }

        // Validate API key format — minimum length check
        if (apiKey.trim().length() < 10 || apiKey.trim().length() > 256) {
            return ResponseEntity.badRequest().body(Map.of("error", "API key must be between 10 and 256 characters"));
        }

        // Encrypt and store API key securely
        String encryptedKey = encryptionUtil.encrypt(apiKey.trim());
        cloudApiKeys.put(normalizedProvider, encryptedKey);

        log.info("Successfully added and encrypted API key for cloud provider: {}", normalizedProvider);
        return ResponseEntity.ok(Map.of("status", "success", "provider", normalizedProvider));
    }

    @DeleteMapping("/{name}")
    public Mono<ResponseEntity<Map<String, String>>> deleteModel(@PathVariable String name) {
        if (!isValidModelName(name)) {
            return Mono.just(ResponseEntity.badRequest().body(Map.of("error", "Invalid model name")));
        }

        return webClient.method(java.util.Objects.requireNonNull(HttpMethod.DELETE))
                .uri("/delete")
                .bodyValue(java.util.Objects.requireNonNull(Map.of("name", name)))
                .retrieve()
                .toBodilessEntity()
                .map(response -> ResponseEntity.ok(Map.of("status", "deleted", "model", name)))
                .onErrorResume(e -> Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                        .body(Map.of("error", "Failed to delete model. Please check Ollama is running."))));
    }

    private boolean isValidModelName(String name) {
        return name != null
                && !name.isBlank()
                && name.length() <= MAX_MODEL_NAME_LENGTH
                && name.matches("^[a-zA-Z0-9._:/-]+$");
    }
}
