import structlog
import threading
import time
import math
import numpy as np
import json
import re

from .ring_buffer import AudioRingBuffer
from .event_bus import EventBus
from .mic_capture import MicCaptureThread
from .vad_engine import SileroVAD, SpeechSegmentQueue
from .stt_engine import StreamingSTTEngine
from .tts_engine import PiperTTSEngine

logger = structlog.get_logger()

class VoiceSessionManager:
    def __init__(self, event_bus: EventBus):
        self.bus = event_bus
        self.bus.subscribe("voice_events", self._handle_voice_events)
        self._lock = threading.Lock()
        self.is_active = False
        self.is_muted = False

        self.ring_buffer = AudioRingBuffer(buffer_seconds=15)
        self.mic = MicCaptureThread(self.ring_buffer)
        self.vad = SileroVAD()
        self.stt = StreamingSTTEngine()
        self.tts = PiperTTSEngine()
        
        self.tts.on_playback_start = self._tts_start_callback
        self.tts.on_playback_end = self._tts_end_callback
        
        self.speech_queue = SpeechSegmentQueue()
        self._orchestrator_thread = None
        self._watchdog_thread = None
        self._tts_buffer = ""
        self._last_tts_end_time = 0
        self._fft_ema_bands = np.zeros(12)
        self.tts_playing = False
        self._barge_in_speech_start = None
        self._BARGE_IN_THRESHOLD = 0.4  # seconds of sustained speech to confirm interruption

    def _tts_start_callback(self):
        logger.info("TTS start triggered")
        self.tts_playing = True
        self.bus.publish("voice_events", "TTS_START")
        # Keep mic running for barge-in detection — do NOT call self.mic.stop()
            
    def _tts_end_callback(self):
        logger.info("TTS end triggered")
        self.tts_playing = False
        self._barge_in_speech_start = None
        self._last_tts_end_time = time.time()
        self.bus.publish("voice_events", "TTS_END")
        if self.is_active:
            self.bus.publish("voice_events", "LISTENING")
            # Ensure mic is running (it should already be, but safety check)
            if not self.mic._is_running:
                self.mic.start()
        else:
            self.bus.publish("voice_events", "VOICE_MODE_OFF")

    def set_mute(self, state: bool):
        self.is_muted = state
        logger.info("Voice Manager TTS Mute Toggled", is_muted=str(self.is_muted))
        if self.is_muted:
            self.tts.clear_queue()

    def select_device(self, dev_type: str, device_id: int):
        logger.info("Voice Manager device selected", type=dev_type, device_id=device_id)
        if dev_type == "input":
            self.mic.update_device(device_id)
        elif dev_type == "output":
            self.tts.update_device(device_id)

    def _speech_formatter(self, text: str) -> str:
        """Normalize text for natural TTS output without altering the chat UI."""
        if not text:
            return text

        out = text

        # 1. Normalize assistant name variations to "Arise"
        out = re.sub(r'A\.?\s*R\.?\s*I\.?\s*S\.?\s*E\.?', 'Arise', out, flags=re.IGNORECASE)

        # 2. Strip markdown code blocks (```...```)
        out = re.sub(r'```[\s\S]*?```', '', out)

        # 3. Strip inline code backticks
        out = re.sub(r'`([^`]*)`', r'\1', out)

        # 4. Strip markdown headers
        out = re.sub(r'^#{1,6}\s*', '', out, flags=re.MULTILINE)

        # 5. Strip bold/italic markers
        out = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', out)
        out = re.sub(r'_{1,3}([^_]+)_{1,3}', r'\1', out)

        # 6. Convert numbered lists to spoken ordering
        list_ordinals = ['First', 'Second', 'Third', 'Fourth', 'Fifth',
                         'Sixth', 'Seventh', 'Eighth', 'Ninth', 'Tenth']
        counter = [0]
        def _numbered_replacer(m):
            idx = counter[0]
            counter[0] += 1
            ordinal = list_ordinals[idx] if idx < len(list_ordinals) else f'Next'
            return f'{ordinal}, '
        out = re.sub(r'^\s*\d+[\.\)\-]\s*', _numbered_replacer, out, flags=re.MULTILINE)

        # 7. Convert bullet points to sentence flow
        out = re.sub(r'^\s*[\-\*•]\s*', '', out, flags=re.MULTILINE)

        # 8. Clean up excessive whitespace / newlines
        out = re.sub(r'\n{2,}', '. ', out)
        out = re.sub(r'\n', ' ', out)
        out = re.sub(r'\s{2,}', ' ', out)

        return out.strip()

    def play_tts(self, text: str, is_final: bool = False):
        if not text.strip() and not is_final:
            return
            
        # Strip out any remaining SSML or HTML-like tags just to be completely safe
        clean_text = re.sub(r'<[^>]+>', '', text)

        # Apply speech formatting for natural TTS output
        formatted_text = self._speech_formatter(clean_text)
        
        if formatted_text.strip() or is_final:
            logger.info("TTS_INPUT_TEXT", text=formatted_text)
            self.tts.synthesize_and_play(formatted_text, is_final=is_final, event_bus=self.bus)

    def _handle_voice_events(self, event):
        etype = event.get("type")
        data = event.get("data", "")
        
        if etype == "AI_STREAM":
            logger.debug("RAW AI_STREAM event", raw=str(data))
            text_chunk = ""
            is_done = False
            
            # Parse the AI_STREAM event data
            if isinstance(data, str):
                try:
                    parsed = json.loads(data)
                    if isinstance(parsed, dict):
                        text_chunk = parsed.get("response", "")
                        is_done = parsed.get("done", False)
                    else:
                        text_chunk = data
                except Exception:
                    text_chunk = data
            elif isinstance(data, dict):
                if "response" in data:
                    text_chunk = data.get("response", "")
                    is_done = data.get("done", False)
                elif "text" in data:
                    inner = data["text"]
                    if isinstance(inner, str) and inner.startswith("{"):
                        try:
                            parsed = json.loads(inner)
                            text_chunk = parsed.get("response", "")
                            is_done = parsed.get("done", False)
                        except Exception:
                            text_chunk = inner
                    else:
                        text_chunk = str(inner)

            # Safety rules: ignore empty or purely whitespace tokens if there's no text
            if not text_chunk and not is_done:
                return

            if text_chunk:
                if len(self._tts_buffer) == 0:
                    logger.info("LLM response start")
                logger.debug("AI_STREAM token extracted", token=text_chunk)
                self._tts_buffer += text_chunk
                
                while True:
                    match = re.search(r'([.!?\n]+)(?:\s|$)', self._tts_buffer)
                    if match:
                        split_idx = match.end()
                        sentence = self._tts_buffer[:split_idx].strip()
                        self._tts_buffer = self._tts_buffer[split_idx:]
                        if len(sentence) > 1:
                            logger.debug("TTS Phrase chunked (punctuation)", phrase=sentence)
                            if not self.is_muted: self.play_tts(sentence)
                    else:
                        if len(self._tts_buffer) > 60 and ',' in self._tts_buffer:
                            split_idx = self._tts_buffer.rfind(',') + 1
                            sentence = self._tts_buffer[:split_idx].strip()
                            self._tts_buffer = self._tts_buffer[split_idx:]
                            if len(sentence) > 1:
                                logger.debug("TTS Phrase chunked (comma)", phrase=sentence)
                                if not self.is_muted: self.play_tts(sentence)
                        elif len(self._tts_buffer) > 100 and ' ' in self._tts_buffer:
                            split_idx = self._tts_buffer.rfind(' ') + 1
                            sentence = self._tts_buffer[:split_idx].strip()
                            self._tts_buffer = self._tts_buffer[split_idx:]
                            if len(sentence) > 1:
                                logger.debug("TTS Phrase chunked (length)", phrase=sentence)
                                if not self.is_muted: self.play_tts(sentence)
                        else:
                            break

            if is_done:
                if not self.is_muted: self.play_tts("", is_final=True)
            
            if self.is_muted and is_done:
                self.bus.publish("voice_events", "TTS_START")
                self.bus.publish("voice_events", "TTS_END")
                if self.is_active:
                    self.bus.publish("voice_events", "LISTENING")

        elif etype == "AI_DISPATCH_COMPLETE":
            buffer_to_play = self._tts_buffer.strip()
            self._tts_buffer = ""
            if len(buffer_to_play) > 1:
                logger.debug("TTS Phrase chunked (final_dispatch_complete)", phrase=buffer_to_play)
                if not self.is_muted: self.play_tts(buffer_to_play, is_final=True)
            else:
                if not self.is_muted: self.play_tts("", is_final=True)

            if self.is_muted:
                self.bus.publish("voice_events", "TTS_START")
                self.bus.publish("voice_events", "TTS_END")
                if self.is_active:
                    self.bus.publish("voice_events", "LISTENING")

        elif etype == "USER_MESSAGE" or etype == "AI_STREAM_START":
            logger.info("LLM response start / AI_STREAM_START received")
            # Interrupt current speaking to prepare for new message
            self.tts.clear_queue()
            self._tts_buffer = ""

    def start(self):
        if self.is_active: return
        self.is_active = True
        self.mic.start()
        
        self.bus.publish("voice_events", "VOICE_MODE_ON")
        self.bus.publish("voice_events", "LISTENING")

        self._orchestrator_thread = threading.Thread(target=self._run_pipeline, daemon=True)
        self._orchestrator_thread.start()
        
        self._watchdog_thread = threading.Thread(target=self._run_watchdog, daemon=True)
        self._watchdog_thread.start()
        
        self.bus.publish("system_events", "READY")
        logger.info("VoiceSessionManager active.")

    def _run_watchdog(self):
        import psutil
        while self.is_active:
            cpu = psutil.cpu_percent(interval=1)
            mem = psutil.virtual_memory().percent
            if cpu > 90 or mem > 90:
                self.bus.publish("system_events", "RESOURCE_WARNING", {"cpu": cpu, "mem": mem})
            time.sleep(5)

    def stop(self):
        if not self.is_active: return
        self.is_active = False
        self.mic.stop()
        self.tts.clear_queue()
        self.bus.publish("voice_events", "VOICE_MODE_OFF")
        logger.info("VoiceSessionManager dismantled.")

    def _run_pipeline(self):
        sample_rate = 16000
        vad_frame_size = 512
        
        in_speech = False
        speech_start_time = 0
        silence_dur = 0
        current_speech_idx = 0
        
        MAX_SILENCE_MS = 800  
        MAX_SILENCE_FRAMES = int((MAX_SILENCE_MS / 1000.0) * sample_rate / vad_frame_size)
        
        partial_history = []
        stable_count = 0
        last_stable_text = ""
        
        last_read_idx = self.ring_buffer.write_index
        local_audio_buffer = np.zeros(0, dtype=np.float32)
        vad_state_is_speech = False
        silence_frame_count = 0

        while self.is_active:
            time.sleep(0.01)
            
            current_write_idx = self.ring_buffer.write_index
            if current_write_idx == last_read_idx:
                continue
                
            with self.ring_buffer._lock:
                if current_write_idx > last_read_idx:
                    new_samples = self.ring_buffer.buffer[last_read_idx:current_write_idx].copy()
                else:
                    new_samples = np.concatenate((
                        self.ring_buffer.buffer[last_read_idx:].copy(),
                        self.ring_buffer.buffer[:current_write_idx].copy()
                    ))
            
            if len(new_samples.shape) > 1:
                new_samples = new_samples.flatten()
                
            last_read_idx = current_write_idx
            local_audio_buffer = np.concatenate((local_audio_buffer, new_samples))

            if len(new_samples) > 0:
                rms = np.sqrt(np.mean(np.square(new_samples)))
                fft_vals = np.abs(np.fft.rfft(new_samples))
                bands = np.array_split(fft_vals, 12)
                cur_bands = np.array([np.log1p(np.mean(b)) if len(b) > 0 else 0 for b in bands])
                # NaN guard
                cur_bands = np.where(np.isfinite(cur_bands), cur_bands, 0.0)
                with self._lock:
                    self._fft_ema_bands = 0.7 * self._fft_ema_bands + 0.3 * cur_bands
                    fft_snapshot = self._fft_ema_bands.tolist()
                
                if not in_speech:
                    rms_val = float(rms) if math.isfinite(float(rms)) else 0.0
                    self.bus.publish("voice_events", "MIC_AMPLITUDE", {
                        "value": rms_val,
                        "fft_ema": fft_snapshot
                    })

            if time.time() - self._last_tts_end_time < 0.1:
                local_audio_buffer = np.zeros(0, dtype=np.float32)
                continue

            while len(local_audio_buffer) >= vad_frame_size:
                frame = local_audio_buffer[:vad_frame_size]
                local_audio_buffer = local_audio_buffer[vad_frame_size:]
                
                if len(frame) != vad_frame_size:
                    continue
                    
                is_speaking = self.vad.is_speech(frame)
                
                if is_speaking:
                    vad_state_is_speech = True
                    silence_frame_count = 0
                else:
                    silence_frame_count += 1
                    if silence_frame_count > 10:
                        vad_state_is_speech = False
            
            self.mic.set_speech_flag(vad_state_is_speech)

            # ── Barge-in detection during TTS playback ──
            if self.tts_playing:
                if vad_state_is_speech:
                    if self._barge_in_speech_start is None:
                        self._barge_in_speech_start = time.time()
                    elif (time.time() - self._barge_in_speech_start) >= self._BARGE_IN_THRESHOLD:
                        # Confirmed barge-in: user has been speaking long enough
                        logger.info("Barge-in confirmed, interrupting TTS")
                        self.tts.clear_queue()
                        self._tts_buffer = ""
                        self._barge_in_speech_start = None
                        # Transition to normal speech tracking
                        in_speech = True
                        current_speech_idx = current_write_idx
                        speech_start_time = time.time()
                        silence_dur = 0
                        self.bus.publish("voice_events", "USER_SPEAKING")
                else:
                    # Speech stopped before threshold — reset, it was just noise
                    self._barge_in_speech_start = None
                continue  # Skip normal speech logic while TTS is playing

            # ── Normal speech detection (TTS not playing) ──
            if vad_state_is_speech:
                if not in_speech:
                    in_speech = True
                    current_speech_idx = current_write_idx
                    speech_start_time = time.time()
                    self.bus.publish("voice_events", "USER_SPEAKING")
                    self.tts.clear_queue()
                    
                silence_dur = 0
            else:
                if in_speech:
                    silence_dur += 1
                    if silence_dur > MAX_SILENCE_FRAMES:
                        in_speech = False
                        self.bus.publish("voice_events", "USER_STOPPED_SPEAKING")
                        
                        # Process speech segment
                        try:
                            speech_audio = self.ring_buffer.get_audio_since(current_speech_idx)
                            if len(speech_audio.shape) > 1:
                                speech_audio = speech_audio.flatten()
                            if len(speech_audio) > sample_rate * 0.5:
                                self.speech_queue.put(speech_audio)
                                self._process_speech(speech_audio)
                        except Exception as e:
                            logger.error("Failed to extract speech audio", error=str(e))
                            
                        partial_history.clear()
                        stable_count = 0
                        last_stable_text = ""

    def _process_speech(self, audio_data):
        try:
            logger.info("Speech segment finalized")
            logger.info("Audio extracted length", samples=len(audio_data))
            logger.info("STT method being called", method="transcribe_chunk")
            text = self.stt.transcribe_chunk(audio_data, is_final=True)
            logger.info("STT transcript result", text=text)
            if text:
                logger.info("LLM dispatch start", text=text)
                self.bus.publish("voice_events", "USER_MESSAGE", {"text": text})
            else:
                self.bus.publish("voice_events", "LISTENING")
        except Exception as e:
            logger.error("STT processing failed", error=str(e))
            self.bus.publish("voice_events", "LISTENING")
