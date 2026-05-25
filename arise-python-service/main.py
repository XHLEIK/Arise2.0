import asyncio
import os
import math
import structlog
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager

from services.system_monitor import SystemMonitor
from services.ollama_worker import OllamaRedisWorker

from voice_engine.event_bus import EventBus
from voice_engine.voice_manager import VoiceSessionManager

logger = structlog.get_logger()

# Configuration from environment with safe defaults
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", None)
API_KEY = os.environ.get("ARISE_API_KEY", "arise-local-dev-key")
HOST = os.environ.get("ARISE_PYTHON_HOST", "127.0.0.1")
PORT = int(os.environ.get("ARISE_PYTHON_PORT", "8002"))

# Global service instances
system_monitor = SystemMonitor()
ollama_worker = OllamaRedisWorker()

# Voice Engine instances
event_bus = EventBus(host=REDIS_HOST, port=REDIS_PORT, db=11, password=REDIS_PASSWORD)
voice_manager = VoiceSessionManager(event_bus)


def _handle_voice_commands(event):
    etype = event.get("type")
    if etype == "start":
        voice_manager.start()
    elif etype == "stop":
        voice_manager.stop()
    elif etype == "tts_play":
        data = event.get("data", {})
        text = data if isinstance(data, str) else data.get("text", "")
        if text and len(text) <= 5000:
            voice_manager.play_tts(text, is_final=True)
    elif etype == "mute_tts":
        data = event.get("data", "false")
        if isinstance(data, dict):
            val = data.get("text", data.get("mute", "false"))
            voice_manager.set_mute(str(val).lower() == "true")
        else:
            voice_manager.set_mute(str(data).lower() == "true")


event_bus.subscribe("voice_commands", _handle_voice_commands)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start background workers
    logger.info("Starting A.R.I.S.E Python Backend Services", host=HOST, port=PORT)

    # 1. Start system metrics publisher (psutil + NVML)
    monitor_task = asyncio.create_task(system_monitor.start_monitoring())

    # 2. Start Redis Pub/Sub worker for Ollama model management
    worker_task = asyncio.create_task(ollama_worker.start_worker())

    # 3. Start EventBus tracking background thread
    event_bus_task = asyncio.create_task(asyncio.to_thread(event_bus.listen_loop))

    yield

    # Shutdown: Clean up workers
    logger.info("Shutting down A.R.I.S.E Python Backend Services")
    system_monitor.stop()
    ollama_worker.stop()
    voice_manager.stop()
    event_bus.stop()
    await asyncio.gather(monitor_task, worker_task, event_bus_task, return_exceptions=True)


app = FastAPI(title="A.R.I.S.E Python Worker", lifespan=lifespan, docs_url=None, redoc_url=None)


@app.middleware("http")
async def api_key_middleware(request: Request, call_next):
    """Validate API key for all endpoints except /health."""
    if request.url.path == "/health":
        return await call_next(request)

    provided_key = request.headers.get("X-API-KEY", "")
    if provided_key != API_KEY:
        return JSONResponse(status_code=401, content={"error": "Unauthorized"})
    return await call_next(request)


@app.get("/health")
async def health_check():
    return {"status": "ok", "nvml_available": system_monitor.nvml_initialized}


def _safe_float(value, fallback=0.0):
    """Guard against NaN/Inf values in metrics."""
    if value is None or (isinstance(value, float) and (math.isnan(value) or math.isinf(value))):
        return fallback
    return float(value)


@app.get("/metrics")
async def get_metrics():
    """
    Exposes metrics directly via HTTP for Spring Boot to proxy.
    Alternatively, Spring Boot can read the 1s TTL keys from Redis.
    """
    import psutil
    from datetime import datetime
    from services.system_monitor import SystemMetrics

    # Rapid pull of current stats (since background task updates Redis)
    cpu_usage = psutil.cpu_percent(interval=None)
    cpu_temp = system_monitor._get_cpu_temp()
    gpu_usage, gpu_temp = system_monitor._get_gpu_metrics()
    ram = psutil.virtual_memory()
    disk = psutil.disk_usage('/')

    return SystemMetrics(
        cpuUsage=_safe_float(cpu_usage),
        cpuTemp=_safe_float(cpu_temp),
        gpuUsage=_safe_float(gpu_usage),
        gpuTemp=_safe_float(gpu_temp),
        ramUsage=_safe_float(ram.percent),
        storageUsage=_safe_float(disk.percent),
        timestamp=datetime.now().isoformat()
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=HOST, port=PORT)
