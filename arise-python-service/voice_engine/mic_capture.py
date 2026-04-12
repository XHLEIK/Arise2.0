import sounddevice as sd
import numpy as np
import structlog
import threading

logger = structlog.get_logger()

class AudioPreprocessor:
    """Handles Automatic Gain Control (AGC) and basic noise profiling."""
    def __init__(self, target_level=0.1, max_gain=10.0):
        self.target_level = target_level
        self.max_gain = max_gain
        self.current_gain = 1.0
        self.noise_profile = 0.001
        self.alpha = 0.05 # Smoothing factor for noise

    def process(self, chunk: np.ndarray, is_speech: bool = False) -> np.ndarray:
        rms = np.sqrt(np.mean(np.square(chunk)))
        if rms < 1e-6:
            return chunk

        if not is_speech:
            # Update noise profile during silence
            self.noise_profile = (1 - self.alpha) * self.noise_profile + self.alpha * rms

        # Simple AGC
        desired_gain = self.target_level / (rms + 1e-6)
        # Limit gain to avoid amplifying noise too much
        desired_gain = min(desired_gain, self.max_gain)
        
        # Smooth gain changes
        self.current_gain = 0.9 * self.current_gain + 0.1 * desired_gain
        
        processed = chunk * self.current_gain
        # Hard clip to [-1, 1]
        np.clip(processed, -1.0, 1.0, out=processed)
        return processed

class MicCaptureThread:
    """Continuous low-latency microphone capture depositing into a RingBuffer."""
    def __init__(self, ring_buffer, sample_rate=16000, channels=1):
        self.ring_buffer = ring_buffer
        self.sample_rate = sample_rate
        self.channels = channels
        self._is_running = False
        self._stream = None
        self.preprocessor = AudioPreprocessor()
        self.is_speech_flag = False

    def _audio_callback(self, indata, frames, time_info, status):
        """Hardware IRQ callback pushing strictly copied frames to the global RingBuffer."""
        if status:
            logger.warning("SoundDevice status anomaly", status=status)
        if self._is_running:
            processed_data = self.preprocessor.process(indata.copy(), is_speech=self.is_speech_flag)
            self.ring_buffer.append(processed_data)

    def set_speech_flag(self, is_speech: bool):
        """Allow VAD to feedback if speech is detected to pause noise profiling."""
        self.is_speech_flag = is_speech

    def start(self):
        self._is_running = True
        if self._stream is not None:
            return  # Already initialized
            
        self._stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=self.channels,
            dtype=np.float32,
            callback=self._audio_callback,
            blocksize=int(self.sample_rate * 0.05) # 50ms discrete sliding window chunks
        )
        try:
            self._stream.start()
            logger.info("Microphone streaming layer initialized", sample_rate=self.sample_rate)
        except Exception as e:
            logger.error("Failed to acquire hardware OS Microphone lock", error=str(e))
            self._is_running = False

    def stop(self):
        # We just pause processing instead of destroying the WASAPI stream,
        # which prevents C-level API segfaults on Windows during rapid start/stops.
        self._is_running = False
        logger.info("Microphone streaming layer paused (logical)")
