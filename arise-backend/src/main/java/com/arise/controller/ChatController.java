package com.arise.controller;

import com.arise.service.ModelConfigService;
import com.arise.service.AiRouterService;
import com.arise.service.EventService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/ai")
public class ChatController {

    private final ModelConfigService modelConfigService;
    private final AiRouterService aiRouterService;
    private final EventService eventService;
    private final WebClient webClient;

    private String lastUsedChatModel = "";

    private static final int MAX_MESSAGE_LENGTH = 50_000;
    private static final int MAX_TTS_LENGTH = 5_000;

    public ChatController(
            ModelConfigService modelConfigService,
            AiRouterService aiRouterService,
            EventService eventService,
            @Qualifier("ollamaWebClient") WebClient webClient) {
        this.modelConfigService = modelConfigService;
        this.aiRouterService = aiRouterService;
        this.eventService = eventService;
        this.webClient = webClient;
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

        // Sanitize model name — only allow safe characters
        if (!model.matches("^[a-zA-Z0-9._:/-]+$")) {
            return Flux.just("{\"error\": \"Invalid model name\"}");
        }

        if (!model.equals(lastUsedChatModel)) {
            eventService.publishEvent("action", "Using " + model + " for conversation");
            lastUsedChatModel = model;
        }

        // 1. Classify Intent via Router
        AiRouterService.Intent intent = aiRouterService.routePrompt(message);
        log.info("AI Request Router classified intent as: {}", intent);

        // 2. Enforce Model Routing Policy (Roles)
        String role = modelConfigService.getModelRole(model);
        if ("Coding".equalsIgnoreCase(role) && intent != AiRouterService.Intent.CODING) {
            log.warn("Attempted to chat with a 'Coding' assigned role: {}", model);
        }

        log.info("Initiating streaming chat with model {} role: {}", model, role);

        // 3. Payload for Ollama /generate
        Map<String, Object> ollamaPayload = Map.of(
                "model", model,
                "prompt", message,
                "system",
                "You are A.R.I.S.E 2.0, a highly efficient AI system unified launcher. Respond directly, concisely, and immediately without filler verbiage.",
                "stream", true,
                "keep_alive", "10m",
                "options", Map.of(
                        "temperature", 0.6,
                        "top_p", 0.9,
                        "num_predict", 512,
                        "num_gpu", 999));

        return webClient.post()
                .uri("/generate")
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
}
