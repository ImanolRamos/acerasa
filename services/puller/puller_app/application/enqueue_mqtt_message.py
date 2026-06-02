import json

import paho.mqtt.client as mqtt
import redis

from puller_app.infrastructure.config import RedisConfig
from puller_app.infrastructure.redis_queue import enqueue_message, get_redis_client

def build_queue_message(topic: str, payload: str) -> str:
    message = {
        "topic": topic,
        "payload": payload,
    }
    return json.dumps(message)

def handle_message(redis_client: redis.Redis, redis_config: RedisConfig, msg: mqtt.MQTTMessage) -> redis.Redis:
    payload = msg.payload.decode("utf-8", errors="replace")

    print("----- MENSAJE RECIBIDO -----")
    print(f"Topic: {msg.topic}")
    print(f"Payload: {payload}")

    queue_message = build_queue_message(msg.topic, payload)

    try:
        enqueue_message(redis_client, redis_config.queue_name, queue_message)
    except Exception as e:
        print(f"Error insertando en Redis: {e}")
        redis_client = get_redis_client(redis_config)
        enqueue_message(redis_client, redis_config.queue_name, queue_message)

    print("----------------------------")
    return redis_client