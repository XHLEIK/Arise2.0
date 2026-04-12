from faster_whisper import WhisperModel
import numpy as np
model = WhisperModel("base.en", device="cpu", compute_type="int8")
audio_data = np.random.randn(32000).astype(np.float32) * 0.01

segments, info = model.transcribe(audio_data, beam_size=1, without_timestamps=True, condition_on_previous_text=False)
for s in segments:
    print(s.text, s.no_speech_prob)

print("WITH VAD")
segments2, info2 = model.transcribe(audio_data, beam_size=1, without_timestamps=True, condition_on_previous_text=False, vad_filter=True)
for s in segments2:
    print(s.text, s.no_speech_prob)
