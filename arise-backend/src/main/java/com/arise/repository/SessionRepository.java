package com.arise.repository;

import com.arise.model.ChatMessage;
import com.arise.model.ChatSession;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class SessionRepository {

    private static final RowMapper<ChatSession> SESSION_MAPPER = (rs, rowNum) -> new ChatSession(
            rs.getString("session_id"),
            rs.getString("title"),
            rs.getString("start_timestamp"),
            rs.getString("end_timestamp"),
            rs.getString("conversation_model"),
            rs.getInt("voice_mode_enabled") == 1,
            rs.getString("session_status"),
            rs.getInt("is_pinned") == 1,
            rs.getString("updated_at"),
            rs.getInt("message_count"),
            List.of()
    );

    private static final RowMapper<ChatMessage> MESSAGE_MAPPER = (rs, rowNum) -> new ChatMessage(
            rs.getString("message_id"),
            rs.getString("session_id"),
            rs.getString("role"),
            rs.getString("message_content"),
            rs.getString("timestamp"),
            rs.getString("language_detected")
    );

    private final JdbcTemplate jdbc;

    public SessionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<ChatSession> findAllSessions() {
        return jdbc.query(
                """
                SELECT session_id, title, start_timestamp, end_timestamp, conversation_model,
                       voice_mode_enabled, session_status, is_pinned, updated_at, message_count
                FROM conversation_sessions
                ORDER BY is_pinned DESC, updated_at DESC
                """,
                SESSION_MAPPER
        );
    }

    public Optional<ChatSession> findSessionById(String sessionId) {
        List<ChatSession> rows = jdbc.query(
                """
                SELECT session_id, title, start_timestamp, end_timestamp, conversation_model,
                       voice_mode_enabled, session_status, is_pinned, updated_at, message_count
                FROM conversation_sessions WHERE session_id = ?
                """,
                SESSION_MAPPER,
                sessionId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public void insertSession(ChatSession session) {
        jdbc.update(
                """
                INSERT INTO conversation_sessions
                (session_id, title, start_timestamp, end_timestamp, conversation_model,
                 voice_mode_enabled, session_status, is_pinned, updated_at, message_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                session.sessionId(),
                session.title(),
                session.startTimestamp(),
                session.endTimestamp(),
                session.conversationModel(),
                session.voiceModeEnabled() ? 1 : 0,
                session.sessionStatus(),
                session.pinned() ? 1 : 0,
                session.updatedAt(),
                session.messageCount()
        );
    }

    public void upsertSession(ChatSession session) {
        jdbc.update(
                """
                INSERT INTO conversation_sessions
                (session_id, title, start_timestamp, end_timestamp, conversation_model,
                 voice_mode_enabled, session_status, is_pinned, updated_at, message_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(session_id) DO UPDATE SET
                    title = excluded.title,
                    end_timestamp = excluded.end_timestamp,
                    conversation_model = excluded.conversation_model,
                    voice_mode_enabled = excluded.voice_mode_enabled,
                    session_status = excluded.session_status,
                    is_pinned = excluded.is_pinned,
                    updated_at = excluded.updated_at,
                    message_count = excluded.message_count
                """,
                session.sessionId(),
                session.title(),
                session.startTimestamp(),
                session.endTimestamp(),
                session.conversationModel(),
                session.voiceModeEnabled() ? 1 : 0,
                session.sessionStatus(),
                session.pinned() ? 1 : 0,
                session.updatedAt(),
                session.messageCount()
        );
    }

    public void updateSessionMeta(String sessionId, String title, Boolean pinned, String updatedAt) {
        if (title != null && pinned != null) {
            jdbc.update(
                    "UPDATE conversation_sessions SET title = ?, is_pinned = ?, updated_at = ? WHERE session_id = ?",
                    title, pinned ? 1 : 0, updatedAt, sessionId
            );
        } else if (title != null) {
            jdbc.update(
                    "UPDATE conversation_sessions SET title = ?, updated_at = ? WHERE session_id = ?",
                    title, updatedAt, sessionId
            );
        } else if (pinned != null) {
            jdbc.update(
                    "UPDATE conversation_sessions SET is_pinned = ?, updated_at = ? WHERE session_id = ?",
                    pinned ? 1 : 0, updatedAt, sessionId
            );
        }
    }

    public void deleteSession(String sessionId) {
        jdbc.update("DELETE FROM messages WHERE session_id = ?", sessionId);
        jdbc.update("DELETE FROM conversation_sessions WHERE session_id = ?", sessionId);
    }

    public List<ChatMessage> findMessagesBySessionId(String sessionId) {
        return jdbc.query(
                """
                SELECT message_id, session_id, role, message_content, timestamp, language_detected
                FROM messages WHERE session_id = ?
                ORDER BY timestamp ASC
                """,
                MESSAGE_MAPPER,
                sessionId
        );
    }

    public void insertMessage(ChatMessage message) {
        jdbc.update(
                """
                INSERT OR REPLACE INTO messages
                (message_id, session_id, role, message_content, timestamp, language_detected)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                message.messageId(),
                message.sessionId(),
                message.role(),
                message.content(),
                message.timestamp(),
                message.languageDetected()
        );
    }

    public void insertMessagesBatch(List<ChatMessage> messages) {
        jdbc.batchUpdate(
                """
                INSERT OR REPLACE INTO messages
                (message_id, session_id, role, message_content, timestamp, language_detected)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                messages,
                messages.size(),
                (ps, msg) -> {
                    ps.setString(1, msg.messageId());
                    ps.setString(2, msg.sessionId());
                    ps.setString(3, msg.role());
                    ps.setString(4, msg.content());
                    ps.setString(5, msg.timestamp());
                    ps.setString(6, msg.languageDetected());
                }
        );
    }

    public void insertSystemEvent(String eventId, String eventType, String eventData, String timestamp) {
        jdbc.update(
                "INSERT INTO system_events (event_id, event_type, event_data, timestamp) VALUES (?, ?, ?, ?)",
                eventId, eventType, eventData, timestamp
        );
    }
}
