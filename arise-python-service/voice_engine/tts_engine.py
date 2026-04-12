import structlog
import threading
import numpy as np
import sounddevice as sd
from pathlib import Path
import queue

# Use the native Python piper wrapper (pip install piper-tts)
try:
    from piper.voice import PiperVoice
except ImportError:
    PiperVoice = None

logger = structlog.get_logger()

class PiperTTSEngine:
    """True streaming ultra-low-latency CPU-based Piper TTS execution."""
    def __init__(self, model_path="models/en_US-lessac-medium.onnx"):
        self.model_path = model_path
        self.voice = None
        
        self.text_queue = queue.Queue()
        self.audio_queue = queue.Queue()
        
        self.on_playback_start = None
        self.on_playback_end = None
        
        self.synth_thread = threading.Thread(target=self._synth_worker, daemon=True)
        self.playback_thread = threading.Thread(target=self._playback_worker, daemon=True)
        
        self._ensure_model_exists()
        
        if self.voice:
            self.synth_thread.start()
            self.playback_thread.start()

    def _ensure_model_exists(self):
        model_file = Path(self.model_path)
        if not model_file.exists():
            logger.warning(f"Piper model missing at '{model_file}'. Please download the .onnx & .json.")
            model_file.parent.mkdir(parents=True, exist_ok=True)
            return

        if PiperVoice is not None:
            try:
                self.voice = PiperVoice.load(str(model_file))
                logger.info("Piper TTS model successfully loaded into memory.")
            except Exception as e:
                logger.error("Failed to load PiperVoice model", error=str(e))
        else:
            logger.error("PiperVoice module failed to import. TTS Engine disabled.")

    def _synth_worker(self):
        while True:
            item = self.text_queue.get()
            if item is None: continue
            
            msg_type, data, event_bus = item
            
            if msg_type == "CLEAR":
                while not self.audio_queue.empty():
                    try: self.audio_queue.get_nowait()
                    except: pass
                self.audio_queue.put(("CLEAR", None))
                self.text_queue.task_done()
                continue
                
            elif msg_type == "FINAL":
                self.audio_queue.put(("FINAL", None))
                self.text_queue.task_done()
                
            elif msg_type == "TEXT":
                text = data
                logger.info("PLAYBACK_QUEUE_POP", phrase=text)
                
                try:
                    frames_list = []
                    for chunk in self.voice.synthesize(text):
                        frames = chunk.audio_int16_array
                        if frames is not None and len(frames) > 0:
                            frames_list.append(frames)
                    
                    if frames_list:
                        all_frames = np.concatenate(frames_list)
                        self.audio_queue.put(("PLAY_PHRASE", (text, all_frames, event_bus)))
                except Exception as e:
                    logger.error("Synthesis error", error=str(e))
                self.text_queue.task_done()

    def _playback_worker(self):
        is_playing = False
        
        while True:
            item = self.audio_queue.get()
            if item is None: continue
            
            action, data = item
            
            if action == "CLEAR":
                if is_playing:
                    is_playing = False
                    if self.on_playback_end: self.on_playback_end()
                self.audio_queue.task_done()
                continue
                    
            elif action == "PLAY_PHRASE":
                phrase_text, frames, event_bus = data
                
                if not is_playing:
                    is_playing = True
                    if self.on_playback_start: self.on_playback_start()
                    
                # wait for audio chunk in queue, play audio once
                try:
                    # Open stream safely, play precisely once, then strictly close it.
                    # This completely prevents hardware circular buffer loops on underflow.
                    stream = sd.OutputStream(samplerate=self.voice.config.sample_rate, channels=1, dtype=np.int16)
                    stream.start()
                    
                    chunk_size = self.voice.config.sample_rate // 10 # 100ms chunks for amplitude events
                    for i in range(0, len(frames), chunk_size):
                        sub_frames = frames[i:i+chunk_size]
                        stream.write(sub_frames)
                        if event_bus:
                            rms = np.sqrt(np.mean(np.square(sub_frames.astype(np.float32) / 32768.0)))
                            event_bus.publish("voice_events", "TTS_AMPLITUDE", {"value": float(rms)})
                            
                    stream.stop()
                    stream.close()
                except Exception as e:
                    logger.error("Stream write error", error=str(e))
                
                logger.info("PLAYBACK_FINISHED", phrase=phrase_text)
                self.audio_queue.task_done()
                        
            elif action == "FINAL":
                if is_playing:
                    is_playing = False
                    if self.on_playback_end: self.on_playback_end()
                else:
                    if self.on_playback_start: self.on_playback_start()
                    if self.on_playback_end: self.on_playback_end()
                self.audio_queue.task_done()

    def synthesize_and_play(self, text: str, is_final=False, event_bus=None):
        if not self.voice: return
        if text.strip():
            logger.info("PLAYBACK_QUEUE_PUSH", phrase=text.strip())
            self.text_queue.put(("TEXT", text.strip(), event_bus))
        if is_final:
            self.text_queue.put(("FINAL", None, None))
            
    def clear_queue(self):
        while not self.text_queue.empty():
            try: self.text_queue.get_nowait()
            except: pass
        self.text_queue.put(("CLEAR", None, None))
