import time
import redis

from injector_app.infrastructure.config import RedisConfig

def get_redis_client(redis_config: RedisConfig) -> redis.Redis:
    while True:
        try:
            client = redis.Redis(
                host=redis_config.host,
                port=redis_config.port,
                decode_responses=True,
            )
            client.ping()
            print("Conectado a Redis")
            return client
        except Exception as e:
            print(f"Error conectando a Redis: {e}")
            time.sleep(5)

def read_queue_message(redis_client: redis.Redis, mqtt_queue: str, processing_queue: str) -> str:
    processing_item = redis_client.lindex(processing_queue, 0)
    if processing_item is not None:
        return processing_item.decode() if isinstance(processing_item, bytes) else processing_item
    
    moved_item = redis_client.blmove(mqtt_queue, processing_queue, 0,'LEFT', 'LEFT')
    return moved_item.decode() if isinstance(moved_item, bytes) else moved_item


def dequeue_message(redis_client: redis.Redis, processing_queue: str) -> None:
    redis_client.lpop(processing_queue)