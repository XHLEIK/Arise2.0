import json
import httpx
import asyncio
import structlog
import redis.asyncio as aioredis

logger = structlog.get_logger()

# Ollama API Constants
OLLAMA_URL = "http://localhost:11434/api"

class OllamaRedisWorker:
    def __init__(self):
        self.running = False
        self.redis = aioredis.from_url("redis://localhost:6379", decode_responses=True)
        
    async def _unload_model(self, model_name: str):
        """
        Force Ollama to unload a model from VRAM by setting its keep_alive to 0.
        This prevents OOM crashes when switching between large models.
        """
        logger.info("Exec unloading model from VRAM", model=model_name)
        async with httpx.AsyncClient() as client:
            try:
                # To unload a model in Ollama, we send an empty generate request with keep_alive = 0
                payload = {
                    "model": model_name,
                    "prompt": "",
                    "keep_alive": 0
                }
                response = await client.post(f"{OLLAMA_URL}/generate", json=payload, timeout=10.0)
                if response.status_code == 200:
                    logger.info("Successfully unloaded model", model=model_name)
                else:
                    logger.error("Failed to unload model", model=model_name, status=response.status_code)
            except Exception as e:
                logger.error("Error communicating with Ollama during unload", model=model_name, error=str(e))

    async def _preload_model(self, model_name: str):
        """
        Preload a model into VRAM immediately after the old one is unloaded.
        """
        logger.info("Exec pre-loading model to VRAM", model=model_name)
        async with httpx.AsyncClient() as client:
            try:
                payload = {
                    "model": model_name,
                    "prompt": "",
                    "keep_alive": -1 # Keep alive indefinitely until manually evicted
                }
                # Empty prompt just to force it to load into memory
                response = await client.post(f"{OLLAMA_URL}/generate", json=payload, timeout=30.0)
                
                if response.status_code == 200:
                    logger.info("Successfully loaded model", model=model_name)
                else:
                    logger.error("Failed to load model", model=model_name, status=response.status_code)
            except Exception as e:
                logger.error("Error communicating with Ollama during load", model=model_name, error=str(e))

    async def start_worker(self):
        self.running = True
        pubsub = self.redis.pubsub()
        await pubsub.subscribe("model-unload-request", "model-switch-request")
        
        logger.info("Ollama Redis worker listening for pub/sub events...")
        
        while self.running:
            try:
                message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if message:
                    channel = message["channel"]
                    # Java RedisTemplate serializes strings as JSON (e.g. '"qwen3.5:4b"'), so strip quotes
                    model_name = message["data"].strip('"')
                    
                    if channel == "model-unload-request":
                        await self._unload_model(model_name)
                        
                    elif channel == "model-switch-request":
                        # We just let the next request natively load it, or we could warm it up.
                        # Since memory constraints are the real issue, we focus on unload.
                        # But preloading ensures a seamless UX when the user types a prompt.
                        await self._preload_model(model_name)
                        
            except Exception as e:
                logger.error("Error in Redis pub/sub loop", error=str(e))
                await asyncio.sleep(1)

    def stop(self):
        self.running = False
        logger.info("Ollama Redis worker stopping...")
