package com.arise.controller;

import com.arise.model.SystemMetrics;
import com.arise.service.AiRouterService;
import com.arise.service.EventService;
import com.arise.service.InstantDataService;
import com.arise.service.ModelConfigService;
import com.arise.service.SystemMetricsService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

@Slf4j
@RestController
@RequestMapping("/api/ai")
public class ChatController {

    private final ModelConfigService modelConfigService;
    private final AiRouterService aiRouterService;
    private final EventService eventService;
    private final InstantDataService instantDataService;
    private final SystemMetricsService metricsService;
    private final WebClient webClient;
    private final WebClient pythonWebClient;

    private static final Pattern URL_CHECK = Pattern.compile(
            "(?:https?://|www\\.)[^\\s]+|[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}",
            Pattern.CASE_INSENSITIVE
    );

    private static final Pattern AFFIRMATIVE_PATTERN = Pattern.compile(
            "^\\s*(yes|yep|yeah|sure|ok|okay|go\\s+ahead|do\\s+it|please|y|scan|confirm|fine|agree)\\b",
            Pattern.CASE_INSENSITIVE
    );

    private static final Pattern SCAN_COMMAND_PATTERN = Pattern.compile(
            "^\\s*(?:please\\s+)?(scan|rescan|refresh|update)(?:\\s+(?:my|the|this)?\\s*(?:system|apps|applications|installed|list|device))?\\s*[?.!]*$",
            Pattern.CASE_INSENSITIVE
    );

    @Value("${arise.security.api-key}")
    private String apiKey;

    private String lastUsedChatModel = "";
    private volatile boolean scanPending = false;
    private final String systemPrompt;

    private static final int MAX_MESSAGE_LENGTH = 50_000;
    private static final int MAX_TTS_LENGTH = 5_000;
    private static final String DEFAULT_SYSTEM_PROMPT =
            "You are Arise, the conversational intelligence of the A.R.I.S.E desktop AI assistant. "
            + "Your name is pronounced as the single word Arise. You were created by Subham Bose. "
            + "Respond naturally, concisely, and helpfully.";

    public ChatController(
            ModelConfigService modelConfigService,
            AiRouterService aiRouterService,
            EventService eventService,
            InstantDataService instantDataService,
            SystemMetricsService metricsService,
            @Qualifier("ollamaWebClient") WebClient webClient) {
        this.modelConfigService = modelConfigService;
        this.aiRouterService = aiRouterService;
        this.eventService = eventService;
        this.instantDataService = instantDataService;
        this.metricsService = metricsService;
        this.webClient = webClient;
        this.pythonWebClient = WebClient.builder().baseUrl("http://localhost:8002").build();
        this.systemPrompt = loadSystemPrompt();
    }

    /**
     * Load SYSTEM_PROMPT.md from workspace and cache it in memory.
     * Searches current directory and parent directory.
     */
    private String loadSystemPrompt() {
        Path[] candidates = {
                Path.of("SYSTEM_PROMPT.md"),
                Path.of("..", "SYSTEM_PROMPT.md")
        };
        for (Path candidate : candidates) {
            try {
                if (Files.exists(candidate)) {
                    String content = Files.readString(candidate).trim();
                    if (!content.isEmpty()) {
                        log.info("Loaded system prompt from {}", candidate.toAbsolutePath());
                        return content;
                    }
                }
            } catch (IOException e) {
                log.warn("Failed to read system prompt from {}: {}", candidate, e.getMessage());
            }
        }
        log.warn("SYSTEM_PROMPT.md not found, using default system prompt.");
        return DEFAULT_SYSTEM_PROMPT;
    }

    /**
     * Streams a chat response from Ollama.
     * Enforces the Model Role (ensure it's not a Coding-only model).
     */
    @PostMapping(value = "/chat", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<String> chat(@RequestBody Map<String, Object> request) {
        String message = (String) request.get("message");
        String model = (String) request.get("model");
        Boolean muteTtsObj = (Boolean) request.get("mute_tts");
        boolean muteTts = muteTtsObj != null ? muteTtsObj : false;

        if (muteTts) {
            eventService.publishEvent("voice_commands", "mute_tts", "true");
        } else {
            eventService.publishEvent("voice_commands", "mute_tts", "false");
        }

        if (message == null || message.isBlank() || model == null || model.isBlank()) {
            return Flux.just("{\"error\": \"Message and model required\"}");
        }

        // Input length validation
        if (message.length() > MAX_MESSAGE_LENGTH) {
            return Flux.just("{\"error\": \"Message exceeds maximum length (" + MAX_MESSAGE_LENGTH + " chars)\"}");
        }

        // Check if a scan is pending and the user is confirming
        if (scanPending) {
            scanPending = false; // reset the state
            if (AFFIRMATIVE_PATTERN.matcher(message).find()) {
                log.info("User confirmed app scan. Triggering /scan-apps...");
                String scanningMsg = "Sure! I am scanning your system for installed applications now. This will take just a moment...";
                eventService.publishEvent("voice_events", "AI_STREAM",
                        "{\"response\": \"" + escapeJson(scanningMsg) + "\"}");
                
                // Call /scan-apps
                return pythonWebClient.post()
                        .uri("/scan-apps")
                        .header("X-API-KEY", apiKey)
                        .retrieve()
                        .bodyToMono(Map.class)
                        .map(res -> {
                            Integer count = (Integer) res.get("indexed_count");
                            if (count == null) count = 0;
                            String resultMsg = "Scan complete! I have found and indexed " + count + " applications on your system. What would you like me to open?";
                            eventService.publishEvent("voice_events", "AI_STREAM",
                                    "{\"response\": \"" + escapeJson(resultMsg) + "\"}");
                            eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
                            return "{\"response\": \"" + escapeJson(resultMsg) + "\", \"done\": true}";
                        })
                        .onErrorResume(e -> {
                            log.error("Failed to run app scan: {}", e.getMessage());
                            String errorMsg = "I encountered an error while scanning your system. Please try again later.";
                            eventService.publishEvent("voice_events", "AI_STREAM",
                                    "{\"response\": \"" + escapeJson(errorMsg) + "\"}");
                            eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
                            return Mono.just("{\"response\": \"" + escapeJson(errorMsg) + "\", \"done\": true}");
                        })
                        .flux();
            } else {
                log.info("User did not confirm scan. Proceeding with normal routing.");
            }
        }

        // Sanitize model name — only allow safe characters
        if (!model.matches("^[a-zA-Z0-9._:/-]+$")) {
            return Flux.just("{\"error\": \"Invalid model name\"}");
        }

        if (!model.equals(lastUsedChatModel)) {
            eventService.publishEvent("action", "Using " + model + " for conversation");
            lastUsedChatModel = model;
        }

        // 1. Classify Intent via Brain Router
        AiRouterService.RoutingDecision decision = aiRouterService.routePrompt(message);
        log.info("Router decision: intent={}, confidence={}, entities={}",
                decision.primaryIntent(), decision.confidence(), decision.extractedEntities());

        // 2. Enforce Model Routing Policy (Roles)
        String role = modelConfigService.getModelRole(model);
        log.info("Initiating streaming chat with model {} role: {}", model, role);

        // ── 3. Intent-based routing ─────────────────────────────────────

        // 3a. Clarification needed (PERFORMATIVE with no target)
        if (decision.clarificationNeeded()) {
            String clarification = decision.clarificationQuestion();
            log.info("Router: clarification required → {}", clarification);
            eventService.publishEvent("voice_events", "AI_STREAM",
                    "{\"response\": \"" + escapeJson(clarification) + "\"}");
            eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
            return Flux.just("{\"response\": \"" + escapeJson(clarification) + "\", \"done\": true}");
        }

        // 3b. INSTANT — serve data directly, send to TTS
        if (decision.primaryIntent() == AiRouterService.Intent.INSTANT) {
            String instantResponse = instantDataService.handleInstantQuery(message, decision.extractedEntities());
            log.info("Router: INSTANT response served (length={})", instantResponse.length());
            eventService.publishEvent("voice_events", "AI_STREAM",
                    "{\"response\": \"" + escapeJson(instantResponse) + "\"}");
            eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
            return Flux.just("{\"response\": \"" + escapeJson(instantResponse) + "\", \"done\": true}");
        }

        // 3c. PERFORMATIVE — dispatch action to Python backend
        if (decision.primaryIntent() == AiRouterService.Intent.PERFORMATIVE) {
            String target = decision.actionTargets().isEmpty()
                    ? "unknown" : decision.actionTargets().get(0);
            
            // Clean trailing punctuation (e.g. "youtube." -> "youtube")
            target = target.replaceAll("[.,?!;:]+$", "").trim();

            // Strip browser descriptors (e.g. "youtube on brave" -> "youtube")
            String cleanedTarget = target.toLowerCase()
                    .replaceAll("\\s+on\\s+brave(?:\\s+browser)?$", "")
                    .replaceAll("\\s+on\\s+chrome(?:\\s+browser)?$", "")
                    .replaceAll("\\s+on\\s+the\\s+browser$", "")
                    .replaceAll("\\s+in\\s+brave(?:\\s+browser)?$", "")
                    .replaceAll("\\s+in\\s+chrome(?:\\s+browser)?$", "")
                    .replaceAll("\\s+in\\s+the\\s+browser$", "")
                    .replaceAll("\\s+on\\s+browser$", "")
                    .replaceAll("\\s+in\\s+browser$", "")
                    .trim();

            // Map of popular web platforms to domains
            Map<String, String> webServices = Map.of(
                    "youtube", "youtube.com",
                    "google", "google.com",
                    "gmail", "gmail.com",
                    "github", "github.com",
                    "wikipedia", "wikipedia.org",
                    "facebook", "facebook.com",
                    "twitter", "twitter.com",
                    "instagram", "instagram.com",
                    "chatgpt", "chatgpt.com",
                    "reddit", "reddit.com"
            );

            String resolvedTarget;
            String actionType;

            // Check if it's a scan command
            if (SCAN_COMMAND_PATTERN.matcher(message).find() 
                    || "scan".equalsIgnoreCase(cleanedTarget) 
                    || "rescan".equalsIgnoreCase(cleanedTarget)
                    || "refresh".equalsIgnoreCase(cleanedTarget)) {
                actionType = "scan_apps";
                resolvedTarget = cleanedTarget;
            } else if (decision.extractedEntities().containsKey("browser_override") || webServices.containsKey(cleanedTarget)) {
                actionType = "open_url";
                resolvedTarget = webServices.containsKey(cleanedTarget) ? webServices.get(cleanedTarget) : cleanedTarget;
            } else if (URL_CHECK.matcher(cleanedTarget).find() || cleanedTarget.matches(".*\\.[a-z]{2,6}$")) {
                actionType = "open_url";
                resolvedTarget = cleanedTarget;
            } else {
                actionType = "launch_app";
                resolvedTarget = cleanedTarget;
            }

            final String finalTarget = resolvedTarget;
            final String finalActionType = actionType;

            Map<String, String> actionBody = Map.of("action", finalActionType, "target", finalTarget);
            log.info("Router: PERFORMATIVE → {} target={}", finalActionType, finalTarget);

            return pythonWebClient.post()
                    .uri("/execute-action")
                    .header("X-API-KEY", apiKey)
                    .bodyValue(actionBody)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .flatMap(responseMap -> {
                        String status = (String) responseMap.get("status");
                        String msg = (String) responseMap.get("message");
                        if ("scan_required".equals(status)) {
                            scanPending = true;
                            log.info("App database is empty. Scan is now pending user confirmation.");
                            eventService.publishEvent("voice_events", "AI_STREAM",
                                    "{\"response\": \"" + escapeJson(msg) + "\"}");
                            eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
                            return Mono.just("{\"response\": \"" + escapeJson(msg) + "\", \"done\": true}");
                        }

                        // Otherwise, it was success, error, or not_found.
                        // Let's check if there's a secondary intent (like INSTANT)
                        if (decision.secondaryIntent() == AiRouterService.Intent.INSTANT) {
                            String instantResponse = instantDataService.handleInstantQuery(message, decision.extractedEntities());
                            String combinedMsg = msg + " " + instantResponse;
                            eventService.publishEvent("voice_events", "AI_STREAM",
                                    "{\"response\": \"" + escapeJson(combinedMsg) + "\"}");
                            eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
                            return Mono.just("{\"response\": \"" + escapeJson(combinedMsg) + "\", \"done\": true}");
                        } else {
                            eventService.publishEvent("voice_events", "AI_STREAM",
                                    "{\"response\": \"" + escapeJson(msg) + "\"}");
                            eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
                            return Mono.just("{\"response\": \"" + escapeJson(msg) + "\", \"done\": true}");
                        }
                    })
                    .onErrorResume(e -> {
                        log.error("Action execution failed: {}", e.getMessage());
                        String fallback = "I tried to " + finalActionType.replace("_", " ")
                                + " '" + finalTarget + "' but encountered an error.";
                        eventService.publishEvent("voice_events", "AI_STREAM",
                                "{\"response\": \"" + escapeJson(fallback) + "\"}");
                        eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
                        return Mono.just("{\"response\": \"" + escapeJson(fallback) + "\", \"done\": true}");
                    })
                    .flux();
        }

        // 3d. GENERAL / INFORMATIVE — fall through to Ollama streaming

        // 4. Payload for Ollama /generate — inject cached SYSTEM_PROMPT.md + dynamic context
        return Mono.zip(metricsService.getLatestMetrics(), getAppCount())
                .flatMapMany(tuple -> {
                    SystemMetrics metrics = tuple.getT1();
                    int appCount = tuple.getT2();

                    String dynamicContext = String.format(
                            "\n\n[Current System Status]\n"
                            + "- Scanned/indexed applications: %d apps\n"
                            + "- CPU Usage: %.1f%%\n"
                            + "- CPU Temperature: %.1f°C\n"
                            + "- RAM Usage: %.1f%%\n"
                            + "- GPU Usage: %.1f%%\n"
                            + "- GPU Temperature: %.1f°C\n"
                            + "- Storage Usage: %.1f%%\n"
                            + "- Local Time: %s\n"
                            + "Note: If the user asks about system metrics, the app status, or scanned applications, use this real-time data to answer directly.",
                            appCount,
                            metrics.getCpuUsage(),
                            metrics.getCpuTemp(),
                            metrics.getRamUsage(),
                            metrics.getGpuUsage(),
                            metrics.getGpuTemp(),
                            metrics.getStorageUsage(),
                            java.time.LocalTime.now().format(java.time.format.DateTimeFormatter.ofPattern("hh:mm a"))
                    );

                    String fullSystemPrompt = systemPrompt + dynamicContext;

                    Map<String, Object> ollamaPayload = Map.of(
                            "model", model,
                            "prompt", message,
                            "system", fullSystemPrompt,
                            "stream", true,
                            "keep_alive", "10m",
                            "options", Map.of(
                                    "temperature", 0.6,
                                    "top_p", 0.9,
                                    "num_predict", 512,
                                    "num_gpu", 999));

                    return webClient.post()
                            .uri("/api/generate")
                            .bodyValue(java.util.Objects.requireNonNull(ollamaPayload))
                            .retrieve()
                            .bodyToFlux(String.class)
                            .doOnNext(chunk -> {
                                // Publish raw chunks concurrently to Redis for Python Voice Engine TTS Synthesizer
                                eventService.publishEvent("voice_events", "AI_STREAM", chunk);
                            })
                            .doFinally(signalType -> {
                                eventService.publishEvent("voice_events", "AI_DISPATCH_COMPLETE", "{}");
                            })
                            .onErrorResume(e -> {
                                log.error("Error during chat stream: {}", e.getMessage());
                                return Flux.just("{\"error\": \"An internal error occurred. Please try again.\"}");
                            });
                });
    }

    private Mono<Integer> getAppCount() {
        return pythonWebClient.get()
                .uri("/apps/count")
                .header("X-API-KEY", apiKey)
                .retrieve()
                .bodyToMono(Map.class)
                .map(res -> {
                    if (res != null && res.containsKey("count")) {
                        Object c = res.get("count");
                        if (c instanceof Number) {
                            return ((Number) c).intValue();
                        }
                    }
                    return 0;
                })
                .onErrorResume(e -> {
                    log.warn("Failed to retrieve app count: {}", e.getMessage());
                    return Mono.just(0);
                });
    }

    /**
     * Escapes a string for safe embedding inside a JSON value.
     */
    private static String escapeJson(String raw) {
        if (raw == null) return "";
        return raw.replace("\\", "\\\\")
                  .replace("\"", "\\\"")
                  .replace("\n", "\\n")
                  .replace("\r", "\\r")
                  .replace("\t", "\\t");
    }

    @PostMapping(value = "/voice/start", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, String> startVoice() {
        eventService.publishEvent("voice_commands", "start", "{}");
        return Map.of("status", "started");
    }

    @PostMapping(value = "/voice/tts", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, String> playTts(@RequestBody Map<String, String> request) {
        String text = request.get("text");
        if (text != null && !text.isBlank() && text.length() <= MAX_TTS_LENGTH) {
            eventService.publishEvent("voice_commands", "tts_play", text);
        }
        return Map.of("status", "tts_queued");
    }

    @PostMapping(value = "/voice/mute", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, String> muteVoice(@RequestBody Map<String, Object> request) {
        Boolean muteObj = (Boolean) request.get("mute");
        boolean mute = muteObj != null ? muteObj : false;
        eventService.publishEvent("voice_commands", "mute_tts", mute ? "true" : "false");
        return Map.of("status", mute ? "muted" : "unmuted");
    }

    @PostMapping(value = "/voice/stop", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, String> stopVoice() {
        eventService.publishEvent("voice_commands", "stop", "{}");
        return Map.of("status", "stopped");
    }

    @GetMapping(value = "/voice/devices", produces = MediaType.APPLICATION_JSON_VALUE)
    public reactor.core.publisher.Mono<String> getDevices() {
        return pythonWebClient.get()
                .uri("/devices")
                .header("X-API-KEY", apiKey)
                .retrieve()
                .bodyToMono(String.class)
                .onErrorResume(e -> {
                    log.error("Failed to fetch devices from Python service: {}", e.getMessage());
                    return reactor.core.publisher.Mono.just("[]");
                });
    }

    @PostMapping(value = "/voice/device", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public reactor.core.publisher.Mono<String> selectDevice(@RequestBody Map<String, Object> body) {
        return pythonWebClient.post()
                .uri("/device")
                .header("X-API-KEY", apiKey)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(String.class)
                .onErrorResume(e -> {
                    log.error("Failed to select device on Python service: {}", e.getMessage());
                    return reactor.core.publisher.Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}");
                });
    }
}
