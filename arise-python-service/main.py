import asyncio
import structlog
from fastapi import FastAPI
from contextlib import asynccontextmanager

from services.system_monitor import SystemMonitor
from services.ollama_worker import OllamaRedisWorker

from voice_engine.event_bus import EventBus
from voice_engine.voice_manager import VoiceSessionManager

logger = structlog.get_logger()

# Global service instances
system_monitor = SystemMonitor()
ollama_worker = OllamaRedisWorker()

# Voice Engine instances
event_bus = EventBus(host='localhost', port=6379, db=11)
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
        if text:
            voice_manager.play_tts(text, is_final=True)
    elif etype == "mute_tts":
        data = event.get("data", "false")
        if isinstance(data, dict):
            # Fallback if deserialized
            val = data.get("text", data.get("mute", "false"))
            voice_manager.set_mute(str(val).lower() == "true")
        else:
            voice_manager.set_mute(str(data).lower() == "true")


event_bus.subscribe("voice_commands", _handle_voice_commands)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start background workers
    logger.info("Starting A.R.I.S.E Python Backend Services")
    
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

app = FastAPI(title="A.R.I.S.E Python Worker", lifespan=lifespan)

@app.get("/health")
async def health_check():
    return {"status": "ok", "nvml_available": system_monitor.nvml_initialized}

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
        cpuUsage=cpu_usage,
        cpuTemp=cpu_temp,
        gpuUsage=gpu_usage,
        gpuTemp=gpu_temp,
        ramUsage=ram.percent,
        storageUsage=disk.percent,
        timestamp=datetime.now().isoformat()
    )
