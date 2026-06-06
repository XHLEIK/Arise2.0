package com.arise.service;

import com.arise.model.ChatMessage;
import com.arise.model.ChatSession;
import com.arise.repository.SessionRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
public class PersistenceManager {

    private final SessionRepository repository;
    private final SessionCacheService cache;

    @Value("${arise.session.flush-inactivity-seconds:30}")
    private long inactivitySeconds;

    public PersistenceManager(SessionRepository repository, SessionCacheService cache) {
        this.repository = repository;
        this.cache = cache;
    }

    public void flushSession(String sessionId) {
        if (!cache.isDirty(sessionId)) {
            return;
        }

        List<ChatMessage> messages = cache.getCachedMessages(sessionId);
        Optional<String> metaJson = cache.getSessionMeta(sessionId);
        Optional<ChatSession> existing = repository.findSessionById(sessionId);

        if (existing.isEmpty() && messages.isEmpty()) {
            cache.clearDirty(sessionId);
            return;
        }

        ChatSession session = existing.orElseGet(() -> new ChatSession(
                sessionId, "New Chat", messages.isEmpty() ? "" : messages.get(0).timestamp(),
                null, null, false, "active", false,
                messages.isEmpty() ? "" : messages.get(messages.size() - 1).timestamp(),
                messages.size(), List.of()
        ));

        ChatSession toPersist = new ChatSession(
                session.sessionId(),
                session.title(),
                session.startTimestamp(),
                session.endTimestamp(),
                session.conversationModel(),
                session.voiceModeEnabled(),
                session.sessionStatus(),
                session.pinned(),
                session.updatedAt(),
                messages.size(),
                List.of()
        );

        repository.upsertSession(toPersist);

        if (!messages.isEmpty()) {
            repository.insertMessagesBatch(messages);
        }

        cache.clearDirty(sessionId);
        log.debug("Flushed session {} ({} messages) to SQLite", sessionId, messages.size());

        if (metaJson.isPresent()) {
            // meta already persisted via upsert
        }
    }

    public void flushAllDirtySessions() {
        for (String sessionId : cache.findDirtySessionIds()) {
            try {
                flushSession(sessionId);
            } catch (Exception e) {
                log.error("Failed to flush session {}: {}", sessionId, e.getMessage());
            }
        }
    }

    @Scheduled(fixedDelayString = "${arise.session.safety-flush-interval-seconds:10}000")
    public void safetyFlush() {
        long now = System.currentTimeMillis();
        for (String sessionId : cache.findDirtySessionIds()) {
            try {
                Optional<Long> lastActivity = cache.getLastActivity(sessionId);
                boolean inactive = lastActivity.isPresent()
                        && (now - lastActivity.get()) >= (inactivitySeconds * 1000L);
                boolean overThreshold = cache.getPendingMessageCount(sessionId) >= 1;

                if (inactive || overThreshold) {
                    flushSession(sessionId);
                }
            } catch (Exception e) {
                log.warn("Safety flush failed for session {}: {}", sessionId, e.getMessage());
            }
        }
    }

    public void logSystemEvent(String eventType, String eventData) {
        repository.insertSystemEvent(
                UUID.randomUUID().toString(),
                eventType,
                eventData,
                java.time.Instant.now().toString()
        );
    }
}
