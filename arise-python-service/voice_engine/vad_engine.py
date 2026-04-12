import torch
import numpy as np
import structlog
import queue

logger = structlog.get_logger()

class SileroVAD:
    """Silero Voice Activity Detection engine optimized for CPU inference."""
    def __init__(self, threshold=0.5, sampling_rate=16000):
        self.threshold = threshold
        self.sampling_rate = sampling_rate
        logger.info("Downloading/Loading Silero VAD from PyTorch Hub...")
        try:
            self.model, utils = torch.hub.load(
                repo_or_dir='snakers4/silero-vad',
                model='silero_vad',
                force_reload=False,
                trust_repo=True
            )
            self.model.eval()
            self.get_speech_timestamps = utils[0]
            logger.info("Silero VAD successfully loaded into memory.")
        except Exception as e:
            logger.error("Failed to load Silero VAD", error=str(e))
            self.model = None

    def is_speech(self, audio_chunk: np.ndarray) -> bool:
        """Returns True if the chunk contains speech probability > threshold."""
        if self.model is None: return False
        
        try:
            # Convert float32 numpy array to torch tensor
            # Audio must be strictly 16kHz Mono float32 [-1.0, 1.0]
            tensor = torch.from_numpy(audio_chunk).float()
            if len(tensor.shape) > 1:
                tensor = tensor.mean(dim=1)  # mix down to mono if stereo
            
            # Model heavily optimizes 512-sample chunks automatically.
            prob = self.model(tensor, self.sampling_rate).item()
            return prob > self.threshold
        except Exception as e:
            logger.error("VAD prediction error", error=str(e))
            return False

class SpeechSegmentQueue:
    """Thread-safe queue passing detected speech frames to STT."""
    def __init__(self):
        self.q = queue.Queue()
        
    def put(self, segment: np.ndarray):
        self.q.put(segment)
        
    def get(self, timeout=None) -> np.ndarray:
        return self.q.get(timeout=timeout)
        
    def empty(self) -> bool:
        return self.q.empty()
