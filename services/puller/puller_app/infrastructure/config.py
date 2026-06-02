import os
from dataclasses import dataclass

@dataclass
class MqttConfig:
    host: str
    port: int
    username: str | None
    password: str | None
    client_id: str
    topic: str

@dataclass
class RedisConfig:
    host: str
    port: int
    queue_name: str

MQTT_CONFIG = MqttConfig(
    host=os.getenv("MQTT_HOST", "acerasa.koiote.es"),
    port=int(os.getenv("MQTT_PORT", "1883")),
    username=os.getenv("MQTT_USERNAME"),
    password=os.getenv("MQTT_PASSWORD"),
    client_id=os.getenv("MQTT_CLIENT_ID", "puller_siemens"),
    topic=os.getenv("MQTT_TOPIC", "#"),
)

REDIS_CONFIG = RedisConfig(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    queue_name=os.getenv("REDIS_QUEUE", "mqtt_queue"),
)