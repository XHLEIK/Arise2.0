package com.arise.service;

import com.arise.model.ChatMessage;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
public class SessionCacheService {

    private static final String ACTIVE_SESSION_KEY = "arise:session:active";
    private static final String SESSION_META_PREFIX = "arise:session:";
    private static final String MESSAGES_SUFFIX = ":messages";
    private static final String META_SUFFIX = ":meta";
    private static final String DIRTY_SUFFIX = ":dirty";
    private static final String ACTIVITY_SUFFIX = ":last_activity";
    private static final String COUNT_SUFFIX = ":pending_count";

    private static final Duration CACHE_TTL = Duration.ofDays(7);

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;

    public SessionCacheService(StringRedisTemplate redis, ObjectMapper objectMapper) {
        this.redis = redis;
        this.objectMapper = objectMapper;
    }

    public void setActiveSessionId(String sessionId) {
        redis.opsForValue().set(ACTIVE_SESSION_KEY, sessionId, CACHE_TTL);
    }

    public Optional<String> getActiveSessionId() {
        return Optional.ofNullable(redis.opsForValue().get(ACTIVE_SESSION_KEY));
    }

    public void cacheSessionMeta(String sessionId, String jsonMeta) {
        redis.opsForValue().set(SESSION_META_PREFIX + sessionId + META_SUFFIX, jsonMeta, CACHE_TTL);
    }

    public Optional<String> getSessionMeta(String sessionId) {
        return Optional.ofNullable(redis.opsForValue().get(SESSION_META_PREFIX + sessionId + META_SUFFIX));
    }

    public List<ChatMessage> getCachedMessages(String sessionId) {
        String raw = redis.opsForValue().get(SESSION_META_PREFIX + sessionId + MESSAGES_SUFFIX);
        if (raw == null || raw.isBlank()) {
            return new ArrayList<>();
        }
        try {
            return objectMapper.readValue(raw, new TypeReference<List<ChatMessage>>() {});
        } catch (JsonProcessingException e) {
            log.warn("Failed to parse cached messages for session {}: {}", sessionId, e.getMessage());
            return new ArrayList<>();
        }
    }

    public void setCachedMessages(String sessionId, List<ChatMessage> messages) {
        try {
            String json = objectMapper.writeValueAsString(messages);
            redis.opsForValue().set(SESSION_META_PREFIX + sessionId + MESSAGES_SUFFIX, json, CACHE_TTL);
        } catch (JsonProcessingException e) {
            log.error("Failed to cache messages for session {}: {}", sessionId, e.getMessage());
        }
    }

    public void appendMessage(String sessionId, ChatMessage message) {
        List<ChatMessage> messages = getCachedMessages(sessionId);
        messages.add(message);
        setCachedMessages(sessionId, messages);
        markDirty(sessionId);
        redis.opsForValue().increment(SESSION_META_PREFIX + sessionId + COUNT_SUFFIX);
        redis.expire(SESSION_META_PREFIX + sessionId + COUNT_SUFFIX, CACHE_TTL);
        touchActivity(sessionId);
    }

    public void replaceCachedMessages(String sessionId, List<ChatMessage> messages) {
        setCachedMessages(sessionId, messages);
        markDirty(sessionId);
        touchActivity(sessionId);
    }

    public void markDirty(String sessionId) {
        redis.opsForValue().set(SESSION_META_PREFIX + sessionId + DIRTY_SUFFIX, "1", CACHE_TTL);
    }

    public boolean isDirty(String sessionId) {
        return "1".equals(redis.opsForValue().get(SESSION_META_PREFIX + sessionId + DIRTY_SUFFIX));
    }

    public void clearDirty(String sessionId) {
        redis.delete(SESSION_META_PREFIX + sessionId + DIRTY_SUFFIX);
        redis.delete(SESSION_META_PREFIX + sessionId + COUNT_SUFFIX);
    }

    public int getPendingMessageCount(String sessionId) {
        String val = redis.opsForValue().get(SESSION_META_PREFIX + sessionId + COUNT_SUFFIX);
        if (val == null) return 0;
        try {
            return Integer.parseInt(val);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    public void touchActivity(String sessionId) {
        redis.opsForValue().set(
                SESSION_META_PREFIX + sessionId + ACTIVITY_SUFFIX,
                String.valueOf(System.currentTimeMillis()),
                CACHE_TTL
        );
    }

    public Optional<Long> getLastActivity(String sessionId) {
        String val = redis.opsForValue().get(SESSION_META_PREFIX + sessionId + ACTIVITY_SUFFIX);
        if (val == null) return Optional.empty();
        try {
            return Optional.of(Long.parseLong(val));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }

    public List<String> findDirtySessionIds() {
        var keys = redis.keys(SESSION_META_PREFIX + "*" + DIRTY_SUFFIX);
        if (keys == null || keys.isEmpty()) {
            return Collections.emptyList();
        }
        List<String> sessionIds = new ArrayList<>();
        int prefixLen = SESSION_META_PREFIX.length();
        int suffixLen = DIRTY_SUFFIX.length();
        for (String key : keys) {
            if (key.endsWith(DIRTY_SUFFIX) && key.length() > prefixLen + suffixLen) {
                sessionIds.add(key.substring(prefixLen, key.length() - suffixLen));
            }
        }
        return sessionIds;
    }

    public void evictSession(String sessionId) {
        redis.delete(SESSION_META_PREFIX + sessionId + MESSAGES_SUFFIX);
        redis.delete(SESSION_META_PREFIX + sessionId + META_SUFFIX);
        redis.delete(SESSION_META_PREFIX + sessionId + DIRTY_SUFFIX);
        redis.delete(SESSION_META_PREFIX + sessionId + ACTIVITY_SUFFIX);
        redis.delete(SESSION_META_PREFIX + sessionId + COUNT_SUFFIX);
    }
}
