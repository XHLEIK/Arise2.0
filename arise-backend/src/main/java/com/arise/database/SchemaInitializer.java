package com.arise.database;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class SchemaInitializer {

    private final JdbcTemplate jdbc;

    public SchemaInitializer(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @PostConstruct
    public void init() {
        jdbc.execute("PRAGMA journal_mode=WAL");
        jdbc.execute("PRAGMA foreign_keys=ON");

        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS conversation_sessions (
                session_id TEXT PRIMARY KEY,
                title TEXT NOT NULL DEFAULT 'New Chat',
                start_timestamp TEXT NOT NULL,
                end_timestamp TEXT,
                conversation_model TEXT,
                voice_mode_enabled INTEGER NOT NULL DEFAULT 0,
                session_status TEXT NOT NULL DEFAULT 'active',
                is_pinned INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL,
                message_count INTEGER NOT NULL DEFAULT 0
            )
            """);

        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                message_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                message_content TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                language_detected TEXT,
                FOREIGN KEY (session_id) REFERENCES conversation_sessions(session_id) ON DELETE CASCADE
            )
            """);

        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS system_events (
                event_id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                event_data TEXT,
                timestamp TEXT NOT NULL
            )
            """);

        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS installed_applications (
                app_id TEXT PRIMARY KEY,
                app_name TEXT NOT NULL,
                normalized_name TEXT NOT NULL UNIQUE,
                launch_command TEXT NOT NULL,
                app_type TEXT NOT NULL,
                source_location TEXT,
                last_scanned_timestamp TEXT NOT NULL
            )
            """);

        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id, timestamp)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_sessions_updated ON conversation_sessions(is_pinned DESC, updated_at DESC)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_apps_normalized ON installed_applications(normalized_name)");

        log.info("SQLite schema initialized");
    }
}
