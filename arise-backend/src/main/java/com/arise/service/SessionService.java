package com.arise.service;

import com.arise.model.ChatMessage;
import com.arise.model.ChatSession;
import com.arise.repository.SessionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
public class SessionService {

    private static final DateTimeFormatter TS_FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss").withZone(ZoneId.systemDefault());

    private final SessionRepository repository;
    private final SessionCacheService cache;
    private final PersistenceManager persistenceManager;
    private final ObjectMapper objectMapper;

    @Value("${arise.session.flush-message-threshold:10}")
    private int flushMessageThreshold;

    public SessionService(
            SessionRepository repository,
            SessionCacheService cache,
            PersistenceManager persistenceManager,
            ObjectMapper objectMapper) {
        this.repository = repository;
        this.cache = cache;
        this.persistenceManager = persistenceManager;
        this.objectMapper = objectMapper;
    }

    public List<ChatSession> listSessions() {
        return repository.findAllSessions();
    }

    public ChatSession getSessionWithMessages(String sessionId) {
        ChatSession session = repository.findSessionById(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("Session not found: " + sessionId));

        List<ChatMessage> cached = cache.getCachedMessages(sessionId);
        List<ChatMessage> messages = cached.isEmpty()
                ? repository.findMessagesBySessionId(sessionId)
                : cached;

        if (!cached.isEmpty()) {
            cache.replaceCachedMessages(sessionId, messages);
        } else if (!messages.isEmpty()) {
            cache.replaceCachedMessages(sessionId, messages);
        }

        return new ChatSession(
                session.sessionId(), session.title(), session.startTimestamp(),
                session.endTimestamp(), session.conversationModel(),
                session.voiceModeEnabled(), session.sessionStatus(),
                session.pinned(), session.updatedAt(), messages.size(), messages
        );
    }

    public ChatSession createSession(String title, String model) {
        flushActiveSessionIfNeeded();

        String now = nowTs();
        String sessionId = UUID.randomUUID().toString();
        String sessionTitle = (title == null || title.isBlank()) ? "New Chat" : title.trim();

        ChatSession session = new ChatSession(
                sessionId, sessionTitle, now, null, model,
                false, "active", false, now, 0, List.of()
        );

        repository.insertSession(session);
        cache.setActiveSessionId(sessionId);
        cache.cacheSessionMeta(sessionId, toMetaJson(session));
        cache.replaceCachedMessages(sessionId, List.of());

        log.info("Created session {} title='{}'", sessionId, sessionTitle);
        return session.withoutMessages();
    }

    public ChatSession activateSession(String sessionId) {
        ChatSession session = repository.findSessionById(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("Session not found: " + sessionId));

        flushActiveSessionIfNeeded();
        cache.setActiveSessionId(sessionId);
        getSessionWithMessages(sessionId);
        return session.withoutMessages();
    }

    public ChatSession updateSession(String sessionId, String title, Boolean pinned) {
        ChatSession existing = repository.findSessionById(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("Session not found: " + sessionId));

        String updatedAt = nowTs();
        repository.updateSessionMeta(sessionId, title, pinned, updatedAt);

        ChatSession updated = new ChatSession(
                sessionId,
                title != null ? title.trim() : existing.title(),
                existing.startTimestamp(),
                existing.endTimestamp(),
                existing.conversationModel(),
                existing.voiceModeEnabled(),
                existing.sessionStatus(),
                pinned != null ? pinned : existing.pinned(),
                updatedAt,
                existing.messageCount(),
                List.of()
        );

        repository.upsertSession(updated);
        cache.cacheSessionMeta(sessionId, toMetaJson(updated));
        return updated.withoutMessages();
    }

    public void deleteSession(String sessionId) {
        persistenceManager.flushSession(sessionId);
        repository.deleteSession(sessionId);
        cache.evictSession(sessionId);

        Optional<String> active = cache.getActiveSessionId();
        if (active.isPresent() && active.get().equals(sessionId)) {
            List<ChatSession> remaining = repository.findAllSessions();
            if (!remaining.isEmpty()) {
                cache.setActiveSessionId(remaining.get(0).sessionId());
            }
        }
        log.info("Deleted session {}", sessionId);
    }

    public String resolveSessionId(String requestedSessionId, String model) {
        if (requestedSessionId != null && !requestedSessionId.isBlank()) {
            if (repository.findSessionById(requestedSessionId).isPresent()) {
                cache.setActiveSessionId(requestedSessionId);
                return requestedSessionId;
            }
        }

        return cache.getActiveSessionId()
                .filter(id -> repository.findSessionById(id).isPresent())
                .orElseGet(() -> createSession("New Chat", model).sessionId());
    }

    public void appendUserMessage(String sessionId, String content, String model) {
        appendMessage(sessionId, "user", content, null, model);
    }

    public void appendAssistantMessage(String sessionId, String content, String model) {
        appendMessage(sessionId, "assistant", content, null, model);
    }

    private void appendMessage(String sessionId, String role, String content, String language, String model) {
        if (content == null || content.isBlank()) return;

        String now = nowTs();
        ChatMessage message = new ChatMessage(
                UUID.randomUUID().toString(),
                sessionId,
                role,
                content,
                now,
                language
        );

        cache.appendMessage(sessionId, message);

        ChatSession existing = repository.findSessionById(sessionId).orElse(null);
        int count = cache.getCachedMessages(sessionId).size();
        String title = existing != null ? existing.title() : "New Chat";

        if ("user".equals(role) && existing != null && ("New Chat".equals(existing.title()) || existing.title().isBlank())) {
            title = deriveTitle(content);
        }

        ChatSession updated = new ChatSession(
                sessionId,
                title,
                existing != null ? existing.startTimestamp() : now,
                null,
                model != null ? model : (existing != null ? existing.conversationModel() : null),
                existing != null && existing.voiceModeEnabled(),
                "active",
                existing != null && existing.pinned(),
                now,
                count,
                List.of()
        );

        repository.upsertSession(updated);
        cache.cacheSessionMeta(sessionId, toMetaJson(updated));

        if (cache.getPendingMessageCount(sessionId) >= flushMessageThreshold) {
            persistenceManager.flushSession(sessionId);
        }
    }

    public void flushActiveSessionIfNeeded() {
        cache.getActiveSessionId().ifPresent(persistenceManager::flushSession);
    }

    private String deriveTitle(String content) {
        String trimmed = content.trim().replaceAll("\\s+", " ");
        if (trimmed.length() <= 48) return trimmed;
        return trimmed.substring(0, 45) + "...";
    }

    private String nowTs() {
        return TS_FMT.format(Instant.now());
    }

    private String toMetaJson(ChatSession session) {
        try {
            return objectMapper.writeValueAsString(session.withoutMessages());
        } catch (Exception e) {
            return "{}";
        }
    }

    @PreDestroy
    public void onShutdown() {
        log.info("Flushing all session caches before shutdown");
        persistenceManager.flushAllDirtySessions();
    }
}
