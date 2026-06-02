import time
import redis
from puller_app.infrastructure.config import RedisConfig

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

def enqueue_message(redis_client: redis.Redis, queue_name: str, message: str) -> None:
    redis_client.rpush(queue_name, message)
    print(f"Mensaje insertado en Redis en la cola {queue_name}")