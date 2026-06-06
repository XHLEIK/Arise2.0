package com.arise.controller;

import com.arise.model.ChatSession;
import com.arise.service.SessionService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/sessions")
public class SessionController {

    private final SessionService sessionService;

    public SessionController(SessionService sessionService) {
        this.sessionService = sessionService;
    }

    @GetMapping
    public List<ChatSession> listSessions() {
        return sessionService.listSessions();
    }

    @PostMapping
    public ChatSession createSession(@RequestBody(required = false) Map<String, String> body) {
        String title = body != null ? body.get("title") : null;
        String model = body != null ? body.get("model") : null;
        return sessionService.createSession(title, model);
    }

    @GetMapping("/{sessionId}")
    public ChatSession getSession(@PathVariable String sessionId) {
        return sessionService.getSessionWithMessages(sessionId);
    }

    @GetMapping("/{sessionId}/messages")
    public ChatSession getMessages(@PathVariable String sessionId) {
        return sessionService.getSessionWithMessages(sessionId);
    }

    @PatchMapping("/{sessionId}")
    public ChatSession updateSession(
            @PathVariable String sessionId,
            @RequestBody Map<String, Object> body) {
        String title = body.containsKey("title") ? String.valueOf(body.get("title")) : null;
        Boolean pinned = null;
        if (body.containsKey("pinned")) {
            Object raw = body.get("pinned");
            if (raw instanceof Boolean b) {
                pinned = b;
            } else {
                pinned = Boolean.parseBoolean(String.valueOf(raw));
            }
        }
        return sessionService.updateSession(sessionId, title, pinned);
    }

    @PostMapping("/{sessionId}/activate")
    public ChatSession activateSession(@PathVariable String sessionId) {
        return sessionService.activateSession(sessionId);
    }

    @DeleteMapping("/{sessionId}")
    public ResponseEntity<Map<String, String>> deleteSession(@PathVariable String sessionId) {
        sessionService.deleteSession(sessionId);
        return ResponseEntity.ok(Map.of("status", "deleted", "sessionId", sessionId));
    }
}
