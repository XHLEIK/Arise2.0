package com.arise.service;

import org.springframework.stereotype.Service;
import org.springframework.data.redis.core.RedisTemplate;
import reactor.core.publisher.Sinks;
import reactor.core.publisher.Flux;
import java.util.Map;
import java.util.HashMap;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

@Service
public class EventService {

    private final Sinks.Many<Map<String, String>> sink = Sinks.many().multicast().onBackpressureBuffer();
    private final RedisTemplate<String, Object> redisTemplate;

    public EventService(RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public void publishEvent(String type, String message) {
        Map<String, String> event = new HashMap<>();
        event.put("type", type);
        event.put("message", message);
        event.put("time", LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm:ss")));
        sink.tryEmitNext(event);
    }

    public void publishEvent(String channel, String type, String data) {
        // Stringify escaping to guarantee exact Python extraction
        String safeData = data.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
        String jsonPayload = String.format("{\"type\":\"%s\", \"data\":{\"text\":\"%s\"}}", type, safeData);
        redisTemplate.convertAndSend(java.util.Objects.requireNonNull(channel), java.util.Objects.requireNonNull(jsonPayload));
    }

    public Flux<Map<String, String>> getEventStream() {
        return sink.asFlux();
    }
}
