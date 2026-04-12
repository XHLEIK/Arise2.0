package com.arise.controller;

import com.arise.service.ModelConfigService;
import com.arise.service.ModelManagerService;
import com.arise.util.EncryptionUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@RestController
@RequestMapping("/api/models")
@RequiredArgsConstructor
public class ModelController {

    private final ModelManagerService modelManagerService;
    private final ModelConfigService modelConfigService;
    private final EncryptionUtil encryptionUtil;

    private final WebClient webClient = WebClient.builder().baseUrl("http://localhost:11434/api").build();
    private final ObjectMapper objectMapper = new ObjectMapper();

    // In-memory secure store for Cloud API Keys (in production, use Vault or a
    // secure DB)
    private final Map<String, String> cloudApiKeys = new ConcurrentHashMap<>();

    // Globally track installation streams so Flutter can poll `GET /installing`
    private final Map<String, Map<String, Object>> activePulls = new ConcurrentHashMap<>();

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

        if (modelName == null || role == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Model and role required"));
        }

        modelConfigService.setModelRole(modelName, role);
        return ResponseEntity.ok(Map.of("status", "success", "model", modelName, "role", role));
    }

    @PostMapping("/select")
    public ResponseEntity<?> selectModel(@RequestBody Map<String, String> request) {
        String modelName = request.get("model");
        if (modelName == null || modelName.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Model name required"));
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
        if (modelName == null || modelName.isEmpty()) {
            return Flux.just("{\"error\": \"Model name required\"}");
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
                        // ignore malformed chunks
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
                .onErrorResume(e -> Flux.just("{\"error\": \"" + e.getMessage() + "\"}"));
    }

    @PostMapping("/cloud/add")
    public ResponseEntity<?> addCloudModel(@RequestBody Map<String, String> request) {
        String provider = request.get("provider");
        String apiKey = request.get("apiKey");

        if (provider == null || apiKey == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Provider and apiKey required"));
        }

        // Encrypt and store API key securely
        String encryptedKey = encryptionUtil.encrypt(apiKey);
        cloudApiKeys.put(provider.toLowerCase(), encryptedKey);

        log.info("Successfully added and encrypted API key for cloud provider: {}", provider);
        return ResponseEntity.ok(Map.of("status", "success", "provider", provider));
    }

    @DeleteMapping("/{name}")
    public Mono<ResponseEntity<Map<String, String>>> deleteModel(@PathVariable String name) {
        return webClient.method(java.util.Objects.requireNonNull(HttpMethod.DELETE))
                .uri("/delete")
                .bodyValue(java.util.Objects.requireNonNull(Map.of("name", name)))
                .retrieve()
                .toBodilessEntity()
                .map(response -> ResponseEntity.ok(Map.of("status", "deleted", "model", name)))
                .onErrorResume(e -> Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                        .body(Map.of("error", e.getMessage() != null ? e.getMessage() : "Unknown exception"))));
    }
}
