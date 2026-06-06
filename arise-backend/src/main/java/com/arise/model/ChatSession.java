package com.arise.model;

import java.util.List;

public record ChatSession(
        String sessionId,
        String title,
        String startTimestamp,
        String endTimestamp,
        String conversationModel,
        boolean voiceModeEnabled,
        String sessionStatus,
        boolean pinned,
        String updatedAt,
        int messageCount,
        List<ChatMessage> messages
) {
    public ChatSession withoutMessages() {
        return new ChatSession(
                sessionId, title, startTimestamp, endTimestamp,
                conversationModel, voiceModeEnabled, sessionStatus,
                pinned, updatedAt, messageCount, List.of()
        );
    }
}
