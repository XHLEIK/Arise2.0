"""Shared SQLite schema and helpers for A.R.I.S.E persistent storage."""

from __future__ import annotations

import json
import os
import sqlite3
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import structlog

logger = structlog.get_logger()

_DB_LOCK = threading.RLock()

DEFAULT_DB_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "arise_memory.db"


def resolve_db_path() -> Path:
    env_path = os.environ.get("ARISE_DB_PATH")
    if env_path:
        return Path(env_path).expanduser().resolve()
    return DEFAULT_DB_PATH.resolve()


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def connect(db_path: Path | None = None) -> sqlite3.Connection:
    path = (db_path or resolve_db_path())
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path), timeout=10, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA synchronous=NORMAL")
    return conn


def init_schema(db_path: Path | None = None) -> Path:
    path = db_path or resolve_db_path()
    with _DB_LOCK:
        conn = connect(path)
        try:
            conn.executescript(
                """
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
                );

                CREATE TABLE IF NOT EXISTS messages (
                    message_id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    message_content TEXT NOT NULL,
                    timestamp TEXT NOT NULL,
                    language_detected TEXT,
                    FOREIGN KEY (session_id) REFERENCES conversation_sessions(session_id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS system_events (
                    event_id TEXT PRIMARY KEY,
                    event_type TEXT NOT NULL,
                    event_data TEXT,
                    timestamp TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS installed_applications (
                    app_id TEXT PRIMARY KEY,
                    app_name TEXT NOT NULL,
                    normalized_name TEXT NOT NULL UNIQUE,
                    launch_command TEXT NOT NULL,
                    app_type TEXT NOT NULL,
                    source_location TEXT,
                    last_scanned_timestamp TEXT NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id, timestamp);
                CREATE INDEX IF NOT EXISTS idx_sessions_updated ON conversation_sessions(is_pinned DESC, updated_at DESC);
                CREATE INDEX IF NOT EXISTS idx_apps_normalized ON installed_applications(normalized_name);
                """
            )
            conn.commit()
            logger.info("SQLite schema ready", path=str(path))
        finally:
            conn.close()
    return path


def migrate_apps_json(json_path: Path, db_path: Path | None = None) -> int:
    """Import legacy apps_db.json into installed_applications."""
    if not json_path.is_file():
        return 0
    try:
        data = json.loads(json_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        logger.warning("Could not migrate apps JSON", error=str(exc))
        return 0
    if not isinstance(data, dict) or not data:
        return 0

    now = _now_iso()
    rows: list[tuple[Any, ...]] = []
    for norm_name, launch_path in data.items():
        if not norm_name or not launch_path:
            continue
        app_type = "uwp" if str(launch_path).startswith("shell:AppsFolder") else "exe"
        rows.append(
            (
                str(uuid.uuid4()),
                norm_name.replace("_", " ").title(),
                norm_name,
                str(launch_path),
                app_type,
                str(launch_path),
                now,
            )
        )

    if not rows:
        return 0

    with _DB_LOCK:
        conn = connect(db_path)
        try:
            conn.executemany(
                """
                INSERT INTO installed_applications
                (app_id, app_name, normalized_name, launch_command, app_type, source_location, last_scanned_timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(normalized_name) DO UPDATE SET
                    launch_command = excluded.launch_command,
                    app_type = excluded.app_type,
                    source_location = excluded.source_location,
                    last_scanned_timestamp = excluded.last_scanned_timestamp
                """,
                rows,
            )
            conn.commit()
            logger.info("Migrated apps from JSON to SQLite", count=len(rows))
            return len(rows)
        finally:
            conn.close()


def load_apps_map(db_path: Path | None = None) -> dict[str, str]:
    with _DB_LOCK:
        conn = connect(db_path)
        try:
            cur = conn.execute(
                "SELECT normalized_name, launch_command FROM installed_applications"
            )
            return {row["normalized_name"]: row["launch_command"] for row in cur.fetchall()}
        finally:
            conn.close()


def upsert_apps(apps: dict[str, str], db_path: Path | None = None) -> None:
    if not apps:
        return
    now = _now_iso()
    rows = []
    for norm_name, launch_path in apps.items():
        app_type = "uwp" if str(launch_path).startswith("shell:AppsFolder") else "exe"
        rows.append(
            (
                str(uuid.uuid4()),
                norm_name.replace("_", " ").title(),
                norm_name,
                str(launch_path),
                app_type,
                str(launch_path),
                now,
            )
        )
    with _DB_LOCK:
        conn = connect(db_path)
        try:
            conn.executemany(
                """
                INSERT INTO installed_applications
                (app_id, app_name, normalized_name, launch_command, app_type, source_location, last_scanned_timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(normalized_name) DO UPDATE SET
                    launch_command = excluded.launch_command,
                    app_type = excluded.app_type,
                    source_location = excluded.source_location,
                    last_scanned_timestamp = excluded.last_scanned_timestamp
                """,
                rows,
            )
            conn.commit()
        finally:
            conn.close()


def log_system_event(event_type: str, event_data: str | None = None, db_path: Path | None = None) -> None:
    with _DB_LOCK:
        conn = connect(db_path)
        try:
            conn.execute(
                "INSERT INTO system_events (event_id, event_type, event_data, timestamp) VALUES (?, ?, ?, ?)",
                (str(uuid.uuid4()), event_type, event_data, _now_iso()),
            )
            conn.commit()
        finally:
            conn.close()
