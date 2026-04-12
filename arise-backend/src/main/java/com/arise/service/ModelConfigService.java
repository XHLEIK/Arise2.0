package com.arise.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.reactive.function.client.WebClient;

@Slf4j
@Service
public class ModelConfigService {

    private static final String CONFIG_FILE = "models_config.json";
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final WebClient ollamaClient = WebClient.builder().baseUrl("http://localhost:11434/api").build();

    @Autowired
    private EventService eventService;

    // Map of modelName -> role (Conversation, Coding, Both, Idle)
    private final Map<String, String> modelRoles = new ConcurrentHashMap<>();

    @PostConstruct
    public void init() {
        loadConfig();
    }

    public synchronized void setModelRole(String modelName, String role) {
        if (role.equals("Conversation") || role.equals("Coding") || role.equals("Both")) {
            eventService.publishEvent("action", "Switching " + role.toLowerCase() + " model...");
        }

        if (role.equals("Conversation")) {
            modelRoles.replaceAll((name, currentRole) -> {
                if (name.equals(modelName))
                    return currentRole;
                if ("Conversation".equals(currentRole) || "Both".equals(currentRole))
                    return "Idle";
                return currentRole;
            });
            preloadModel(modelName);
        } else if (role.equals("Coding")) {
            modelRoles.replaceAll((name, currentRole) -> {
                if (name.equals(modelName))
                    return currentRole;
                if ("Coding".equals(currentRole) || "Both".equals(currentRole))
                    return "Idle";
                return currentRole;
            });
            preloadModel(modelName);
        } else if (role.equals("Both")) {
            modelRoles.replaceAll((name, currentRole) -> {
                if (name.equals(modelName))
                    return currentRole;
                return "Idle";
            });
            preloadModel(modelName);
        }

        modelRoles.put(modelName, role);
        saveConfig();
        log.info("Set role {} for model {}", role, modelName);
    }

    private void preloadModel(String modelName) {
        log.info("Warming up model {} in Ollama memory...", modelName);
        eventService.publishEvent("info", "Loading " + modelName + "...");

        ollamaClient.post()
                .uri("/generate")
                .bodyValue(java.util.Objects.requireNonNull(Map.of("model", modelName, "keep_alive", "10m")))
                .retrieve()
                .bodyToMono(String.class)
                .subscribe(
                        res -> {
                            log.info("Model {} preloaded successfully.", modelName);
                            eventService.publishEvent("success", "Loaded " + modelName);
                            eventService.publishEvent("success", "Model ready for operations");
                        },
                        err -> {
                            log.error("Failed to preload model {}: {}", modelName, err.getMessage());
                            eventService.publishEvent("error", "Failed to load " + modelName);
                        });
    }

    public String getModelRole(String modelName) {
        return modelRoles.getOrDefault(modelName, "Idle"); // Default to 'Idle' if unassigned
    }

    public Map<String, String> getAllConfigs() {
        return new HashMap<>(modelRoles);
    }

    private void loadConfig() {
        File file = new File(CONFIG_FILE);
        if (file.exists()) {
            try {
                Map<String, String> loaded = objectMapper.readValue(file, new TypeReference<Map<String, String>>() {
                });
                modelRoles.putAll(loaded);
                log.info("Loaded model configurations: {}", modelRoles);

                // Instantly warm up active conversational models into VRAM to prevent
                // cold-start latency.
                for (Map.Entry<String, String> entry : modelRoles.entrySet()) {
                    if ("Conversation".equals(entry.getValue()) || "Both".equals(entry.getValue())) {
                        preloadModel(entry.getKey());
                    }
                }
            } catch (IOException e) {
                log.error("Failed to load model config", e);
            }
        }
    }

    private void saveConfig() {
        try {
            objectMapper.writerWithDefaultPrettyPrinter().writeValue(new File(CONFIG_FILE), modelRoles);
        } catch (IOException e) {
            log.error("Failed to save model config", e);
        }
    }
}
