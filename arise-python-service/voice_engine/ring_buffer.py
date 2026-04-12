import numpy as np
import threading

class AudioRingBuffer:
    """Thread-safe circular buffer for non-blocking raw PCM audio ingestion."""
    def __init__(self, sample_rate=16000, channels=1, dtype=np.float32, buffer_seconds=10):
        self.sample_rate = sample_rate
        self.channels = channels
        self.dtype = dtype
        self.buffer_size = int(sample_rate * buffer_seconds)
        self.buffer = np.zeros((self.buffer_size, channels), dtype=self.dtype)
        self.write_index = 0
        self.is_full = False
        self._lock = threading.Lock()

    def append(self, data: np.ndarray):
        with self._lock:
            n = len(data)
            if n == 0: return
            
            if n >= self.buffer_size:
                self.buffer[:] = data[-self.buffer_size:]
                self.write_index = 0
                self.is_full = True
                return
                
            end_idx = self.write_index + n
            if end_idx <= self.buffer_size:
                self.buffer[self.write_index:end_idx] = data
            else:
                overflow = end_idx - self.buffer_size
                self.buffer[self.write_index:] = data[:-overflow]
                self.buffer[:overflow] = data[-overflow:]
                self.is_full = True
                
            self.write_index = (self.write_index + n) % self.buffer_size

    def get_last_ms(self, milliseconds: int) -> np.ndarray:
        """Retrieves the exact trailing N milliseconds of audio from the ring."""
        samples = int(self.sample_rate * (milliseconds / 1000.0))
        if samples > self.buffer_size: samples = self.buffer_size
        
        with self._lock:
            if not self.is_full and self.write_index < samples:
                return self.buffer[:self.write_index].copy()
            
            start_idx = self.write_index - samples
            if start_idx >= 0:
                return self.buffer[start_idx:self.write_index].copy()
            else:
                start_idx += self.buffer_size
                part1 = self.buffer[start_idx:]
                part2 = self.buffer[:self.write_index]
                return np.concatenate((part1, part2))

    def get_all(self) -> np.ndarray:
        with self._lock:
            if not self.is_full:
                return self.buffer[:self.write_index].copy()
            part1 = self.buffer[self.write_index:]
            part2 = self.buffer[:self.write_index]
            return np.concatenate((part1, part2))

    def get_audio_since(self, start_idx: int) -> np.ndarray:
        with self._lock:
            if self.write_index >= start_idx:
                return self.buffer[start_idx:self.write_index].copy()
            else:
                part1 = self.buffer[start_idx:]
                part2 = self.buffer[:self.write_index]
                return np.concatenate((part1, part2))

    def clear(self):
        with self._lock:
            self.buffer.fill(0)
            self.write_index = 0
            self.is_full = False
