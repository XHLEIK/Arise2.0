from faster_whisper import WhisperModel
import structlog
import numpy as np

logger = structlog.get_logger()

class StreamingSTTEngine:
    """High-performance Faster-Whisper wrapper optimized for streaming partial decodes."""
    def __init__(self, model_size="base.en", device="cpu", compute_type="int8"):
        logger.info(f"Loading faster-whisper model '{model_size}' on {device}/{compute_type}...")
        try:
            self.model = WhisperModel(model_size, device=device, compute_type=compute_type)
            logger.info("Streaming STT Engine successfully initialized.")
        except Exception as e:
            logger.error("Failed to boot faster-whisper native backend", error=str(e))
            self.model = None

    def transcribe_chunk(self, audio_data: np.ndarray, is_final: bool = False) -> str:
        """
        Process a growing PCM buffer to extract partial or final text.
        By setting beam_size=1, VRAM and CPU cycles are strictly conserved ensuring <300ms latency.
        """
        if self.model is None or len(audio_data) < 16000 * 0.5: # Don't decode chunks under 500ms
            return ""
            
        try:
            # beam_size=1 avoids heavy tree-search latency enabling real-time feeling.
            segments, info = self.model.transcribe(
                audio_data,
                beam_size=1,
                without_timestamps=True,
                language="en",
                condition_on_previous_text=False,
                vad_filter=True,
                vad_parameters=dict(min_silence_duration_ms=500)
            )
            text = "".join([segment.text for segment in segments if segment.no_speech_prob < 0.6])
            
            # Additional safety: Reject if language confidence is low or it's a known hallucination
            if info.language_probability < 0.5 or text.strip().lower() in ["shh.", "you", "shh", "thank you.", "thank you", "bye.", "bye", "you."]:
                return ""
                
            return text.strip()
        except Exception as e:
            logger.error("STT transcription exception", error=str(e))
            return ""
