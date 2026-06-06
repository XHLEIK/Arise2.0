"""Turbovec-backed local vector index for fast quantized semantic search."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import structlog

logger = structlog.get_logger()

DEFAULT_INDEX_DIR = Path(__file__).resolve().parent.parent.parent / "data" / "turbovec"


class TurbovecMemoryIndex:
    """Wrapper around turbovec.TurboQuantIndex for future memory embeddings."""

    def __init__(self, index_dir: Path | None = None, dim: int = 384, bit_width: int = 4):
        self.index_dir = (index_dir or DEFAULT_INDEX_DIR).resolve()
        self.index_dir.mkdir(parents=True, exist_ok=True)
        self.dim = dim
        self.bit_width = bit_width
        self._index = None
        self._ids: list[int] = []

    def initialize(self) -> bool:
        try:
            import turbovec

            index_path = self.index_dir / "arise_memories.tvec"
            self._index = turbovec.TurboQuantIndex(self.dim, self.bit_width)
            if index_path.exists():
                self._index.load(str(index_path))
            logger.info("Turbovec index ready", path=str(index_path), dim=self.dim)
            return True
        except Exception as exc:
            logger.warning("Turbovec unavailable", error=str(exc))
            self._index = None
            return False

    def add(self, vector: list[float]) -> int:
        if self._index is None:
            return -1
        handle = len(self._ids)
        arr = np.asarray(vector, dtype=np.float32).reshape(1, -1)
        self._index.add(handle, arr)
        self._ids.append(handle)
        return handle

    def save(self) -> None:
        if self._index is None:
            return
        index_path = self.index_dir / "arise_memories.tvec"
        self._index.write(str(index_path))
        logger.info("Turbovec index saved", path=str(index_path), vectors=len(self._ids))

    @property
    def ready(self) -> bool:
        return self._index is not None
