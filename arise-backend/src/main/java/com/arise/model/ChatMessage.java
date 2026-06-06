package com.arise.model;

public record ChatMessage(
        String messageId,
        String sessionId,
        String role,
        String content,
        String timestamp,
        String languageDetected
) {}
