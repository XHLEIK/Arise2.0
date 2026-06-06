"""ChromaDB initialization for future semantic memory."""

from __future__ import annotations

from pathlib import Path

import structlog

logger = structlog.get_logger()

DEFAULT_CHROMA_DIR = Path(__file__).resolve().parent.parent.parent / "data" / "chroma"


def init_chroma(persist_dir: Path | None = None):
    """Initialize a persistent Chroma client. Returns (client, collection) or (None, None)."""
    path = (persist_dir or DEFAULT_CHROMA_DIR).resolve()
    path.mkdir(parents=True, exist_ok=True)
    try:
        import chromadb

        client = chromadb.PersistentClient(path=str(path))
        collection = client.get_or_create_collection(
            name="arise_memories",
            metadata={"hnsw:space": "cosine"},
        )
        logger.info("ChromaDB ready", path=str(path), count=collection.count())
        return client, collection
    except Exception as exc:
        logger.warning("ChromaDB unavailable (install chromadb to enable)", error=str(exc))
        return None, None
