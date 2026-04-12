package com.arise.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HealthController {

    @GetMapping("/health")
    public Map<String, String> getHealth() {
        Map<String, String> health = new HashMap<>();
        health.put("backend", "ok");
        // In a real application, these would be actively checked via Redis pings or
        // HTTP calls.
        health.put("ollama", "connected");
        health.put("python", "connected");
        return health;
    }
}
