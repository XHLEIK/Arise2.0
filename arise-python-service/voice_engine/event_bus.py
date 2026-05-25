import json
import redis
import structlog
import gzip
import base64
import threading
import time
from typing import Callable, Dict, List, Any

logger = structlog.get_logger()

class EventBus:
    """Thread-safe event bus using Redis for cross-service IPC."""
    def __init__(self, host='localhost', port=6379, db=11, password=None):
        self.redis_client = redis.Redis(host=host, port=port, db=db, password=password, decode_responses=True)
        self.pubsub = self.redis_client.pubsub(ignore_subscribe_messages=True)
        self._listeners: Dict[str, List[Callable]] = {}
        self._listeners_lock = threading.Lock()
        self._is_listening = False

    def subscribe(self, channel: str, callback: Callable):
        with self._listeners_lock:
            if channel not in self._listeners:
                self._listeners[channel] = []
                self.pubsub.subscribe(**{channel: self._on_message})
            if callback not in self._listeners[channel]:
                self._listeners[channel].append(callback)

    def unsubscribe(self, channel: str, callback: Callable):
        if channel in self._listeners:
            try:
                self._listeners[channel].remove(callback)
            except ValueError:
                pass
            if not self._listeners[channel]:
                self.pubsub.unsubscribe(channel)
                del self._listeners[channel]

    def publish(self, channel: str, event_type: str, data: Any = None, compress: bool = False):
        payload_dict = {"type": event_type, "data": data or {}}
        if compress:
            json_str = json.dumps(payload_dict)
            compressed = gzip.compress(json_str.encode('utf-8'))
            encoded = base64.b64encode(compressed).decode('utf-8')
            payload = json.dumps({"compressed": True, "payload": encoded})
        else:
            payload = json.dumps(payload_dict)
        self.redis_client.publish(channel, payload)

    def _on_message(self, message):
        channel = message['channel']
        data = message['data']
        logger.debug("EventBus on_message", channel=channel)
        try:
            # Spring Boot's Stringify escaping logic may wrap our JSON payload in double quotes 
            # if we use raw RedisTemplate.convertAndSend strings. Let's handle both.
            if isinstance(data, str):
                try:
                    parsed = json.loads(data)
                except json.JSONDecodeError:
                    parsed = data # Fallback to raw string if it's not valid JSON
            else:
                parsed = data
                
            # If parsed is still a string (because it was double-serialized), try again
            if isinstance(parsed, str):
                try:
                    parsed = json.loads(parsed)
                except json.JSONDecodeError:
                    pass

            if isinstance(parsed, dict) and parsed.get("compressed"):
                decoded = base64.b64decode(parsed["payload"])
                decompressed = gzip.decompress(decoded).decode('utf-8')
                parsed = json.loads(decompressed)
            
            if isinstance(parsed, dict):
                with self._listeners_lock:
                    listeners = list(self._listeners.get(channel, []))
                for callback in listeners:
                    try:
                        callback(parsed)
                    except Exception as cb_err:
                        logger.error("EventBus callback error", error=str(cb_err), channel=channel)
            else:
                logger.error("EventBus parsing error: final parsed object is not a dict", payload=data)

        except Exception as e:
            logger.error("EventBus parsing error", error=str(e), payload=data)

    def listen_loop(self):
        """Blocking loop to process incoming pubsub messages with reconnection."""
        logger.info("EventBus listen_loop started")
        self._is_listening = True
        retry_count = 0
        max_retries = 30
        while self._is_listening and retry_count < max_retries:
            try:
                for message in self.pubsub.listen():
                    if not self._is_listening:
                        break
                retry_count = 0  # Reset on successful listen
            except redis.ConnectionError as e:
                retry_count += 1
                wait_time = min(2 ** retry_count, 60)
                logger.warning("EventBus Redis connection lost, retrying", attempt=retry_count, wait=wait_time, error=str(e))
                time.sleep(wait_time)
            except Exception as e:
                logger.error("EventBus listening exception", error=str(e))
                break
        logger.info("EventBus listen_loop ended")

    def stop(self):
        self._is_listening = False
        self.pubsub.close()
        self.redis_client.close()
