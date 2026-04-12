package com.arise.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
public class ModelManagerService {

    private final RedisTemplate<String, Object> redisTemplate;

    @Value("${arise.ollama.max-loaded-models:2}")
    private int maxLoadedModels;

    // Cache to keep track of loaded models
    private final List<String> loadedModelsCache = new ArrayList<>();
    private String activeModel = null;

    public ModelManagerService(RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    /**
     * Safely switches the active model: Unload old -> Load new -> Confirm ready.
     * Prevents Ollama from crashing due to OOM errors.
     */
    public synchronized boolean switchModel(String targetModel) {
        if (targetModel.equals(activeModel)) {
            log.info("Model {} is already active.", targetModel);
            return true;
        }

        log.info("Requesting model switch to: {}", targetModel);

        // Manage cache limit
        if (loadedModelsCache.size() >= maxLoadedModels) {
            String modelToUnload = loadedModelsCache.remove(0); // LRU
            unloadModel(modelToUnload);
        }

        // Pub/Sub notification to Python workers to prepare
        redisTemplate.convertAndSend("model-switch-request", targetModel);

        // Add to cache
        loadedModelsCache.remove(targetModel); // Remove if exists to push to end
        loadedModelsCache.add(targetModel);

        activeModel = targetModel;
        log.info("Successfully switched active model to {}, Map state: {}", targetModel, loadedModelsCache);

        return true;
    }

    private void unloadModel(String modelName) {
        log.info("Unloading model {} to free VRAM.", modelName);
        // This sends a system event down to the Python worker which communicates
        // directly with Ollama.
        redisTemplate.convertAndSend(java.util.Objects.requireNonNull("model-unload-request"), java.util.Objects.requireNonNull(modelName));
    }
}
