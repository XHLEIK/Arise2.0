import sys, os
import numpy as np
from faster_whisper import WhisperModel
model = WhisperModel("base.en", device="cpu", compute_type="int8")
audio = np.random.randn(32000, 1).astype(np.float32)
for seg in model.transcribe(audio)[0]:
    print(seg.text)
print("Finished")
