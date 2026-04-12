from faster_whisper import WhisperModel
import numpy as np
model = WhisperModel("base.en", device="cpu", compute_type="int8")
audio_data = np.zeros(32000, dtype=np.float32)
segments, info = model.transcribe(audio_data, beam_size=1, without_timestamps=True, condition_on_previous_text=False, vad_filter=True)
list(segments)
print("No speech prob:", getattr(info, 'no_speech_prob', 'N/A'))
