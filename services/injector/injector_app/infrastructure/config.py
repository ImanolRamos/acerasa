import os
from dataclasses import dataclass

@dataclass
class DbConfig:
    host: str
    port: int
    dbname: str
    user: str
    password: str


@dataclass
class RedisConfig:
    host: str
    port: int
    mqtt_queue: str
    processing_queue: str

DB_CONFIG = DbConfig(
    host=os.getenv("POSTGRES_HOST", "timescaledb"),
    port=int(os.getenv("POSTGRES_PORT", "5432")),
    dbname=os.getenv("POSTGRES_DB"),
    user=os.getenv("POSTGRES_USER"),
    password=os.getenv("POSTGRES_PASSWORD"),
)

REDIS_CONFIG = RedisConfig(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    mqtt_queue=os.getenv("REDIS_QUEUE", "mqtt_queue"),
    processing_queue=os.getenv("REDIS_PROCESSING_QUEUE", "processing_queue")
)