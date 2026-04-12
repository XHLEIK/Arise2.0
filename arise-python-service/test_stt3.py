import sys, os
import numpy as np
from faster_whisper import WhisperModel
model = WhisperModel("base.en", device="cpu", compute_type="int8")
audio = np.random.randn(32000).astype(np.float32)
res = list(model.transcribe(audio, condition_on_previous_text=False)[0])
print(f"Results for 1D: {len(res)}")
if len(res) > 0:
    print(res[0].text)

audio2 = np.random.randn(32000, 1).astype(np.float32)
res2 = list(model.transcribe(audio2, condition_on_previous_text=False)[0])
print(f"Results for 2D: {len(res2)}")
