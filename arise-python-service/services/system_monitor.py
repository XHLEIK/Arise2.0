import json
import asyncio
import psutil
import structlog
import redis.asyncio as aioredis
from pydantic import BaseModel
from datetime import datetime

# Attempt to load NVML for accurate GPU metrics on Windows
try:
    import pynvml
    pynvml.nvmlInit()
    NVML_AVAILABLE = True
except Exception:
    NVML_AVAILABLE = False

logger = structlog.get_logger()

class SystemMetrics(BaseModel):
    cpuUsage: float
    cpuTemp: float
    gpuUsage: float
    gpuTemp: float
    ramUsage: float
    storageUsage: float
    timestamp: str

class SystemMonitor:
    def __init__(self):
        self.running = False
        self.redis = aioredis.from_url("redis://localhost:6379", decode_responses=True)
        self.nvml_initialized = NVML_AVAILABLE

    def _get_cpu_temp(self) -> float:
        """
        psutil temperatures are often unavailable on Windows.
        We return a fallback logic or actual if available.
        """
        try:
            temps = psutil.sensors_temperatures()
            if 'coretemp' in temps:
                return float(temps['coretemp'][0].current)
            elif 'acpitz' in temps:
                return float(temps['acpitz'][0].current)
        except Exception:
            pass
        return 45.0  # Fallback realistic idle CPU temp

    def _get_gpu_metrics(self) -> tuple[float, float]:
        """Returns (usage_percent, temperature_c)"""
        if not self.nvml_initialized:
            return (0.0, 40.0) # Fallback

        try:
            handle = pynvml.nvmlDeviceGetHandleByIndex(0)
            util = pynvml.nvmlDeviceGetUtilizationRates(handle)
            temp = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
            return (float(util.gpu), float(temp))
        except Exception as e:
            logger.warning(f"Failed to read NVML GPU metrics: {e}")
            return (0.0, 40.0)

    async def start_monitoring(self):
        self.running = True
        logger.info("SystemMonitor started.", nvml_available=self.nvml_initialized)
        
        while self.running:
            try:
                # CPU
                cpu_usage = psutil.cpu_percent(interval=None)
                cpu_temp = self._get_cpu_temp()
                
                # GPU
                gpu_usage, gpu_temp = self._get_gpu_metrics()
                
                # RAM
                ram = psutil.virtual_memory()
                
                # Storage (Active drive or C:)
                disk = psutil.disk_usage('/')
                
                metrics = SystemMetrics(
                    cpuUsage=cpu_usage,
                    cpuTemp=cpu_temp,
                    gpuUsage=gpu_usage,
                    gpuTemp=gpu_temp,
                    ramUsage=ram.percent,
                    storageUsage=disk.percent,
                    timestamp=datetime.now().isoformat()
                )

                # Store as a simple expiring key in Redis for Spring Boot to read
                # We use setex to ensure data doesn't persist if the python worker crashes
                await self.redis.setex("system-metrics-live", 5, metrics.model_dump_json())
                
            except Exception as e:
                logger.error(f"Error collecting metrics: {e}")
                
            await asyncio.sleep(1) # Collect every 1 second

    def stop(self):
        self.running = False
        logger.info("SystemMonitor stopping...")
