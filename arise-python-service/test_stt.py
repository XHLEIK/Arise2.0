import sys
import os
import numpy as np
from voice_engine.stt_engine import StreamingSTTEngine

stt = StreamingSTTEngine()
audio = np.random.randn(32000).astype(np.float32)
print("transcription:", stt.transcribe_chunk(audio))
