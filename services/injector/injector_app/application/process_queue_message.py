import json
import redis

from psycopg2.extensions import connection as PgConnection

from injector_app.domain.measurement import Measurement
from injector_app.infrastructure.config import RedisConfig
from injector_app.infrastructure.redis_queue import read_queue_message, dequeue_message
from injector_app.infrastructure.postgres_measurement_repository import insert_measurements

def parse_queue_message(message: str) -> dict:
    data = json.loads(message)

    if "topic" not in data:
        raise ValueError("Falta el campo 'topic'")
    if "payload" not in data:
        raise ValueError("Falta el campo 'payload'")
    
    return data

def build_measurements(queue_data: dict) -> list[Measurement]:
    payload = queue_data["payload"]
    payload_data = json.loads(payload)

    published_at = payload_data["Timestamp"]

    measurement_group_name = next(
        key for key in payload_data.keys()
        if key != "Timestamp"
    )

    measurement_group = payload_data[measurement_group_name]

    measurements = []

    for internal_name, measurement_data in measurement_group.items():
        measurement = Measurement(
            published_at=published_at,
            internal_name=internal_name,
            value=float(measurement_data["Value"])
        )

        measurements.append(measurement)

    return measurements

def process_next_message(redis_client: redis.Redis, redis_config: RedisConfig, db_connection: PgConnection) -> int:
    message = read_queue_message(redis_client, redis_config.mqtt_queue, redis_config.processing_queue)
    queue_data = parse_queue_message(message)
    measurements = build_measurements(queue_data)
    insert_measurements(db_connection, measurements)
    dequeue_message(redis_client, redis_config.processing_queue)
    #si falla porque el mensaje está mal entonces nunca sale del bucle
    return len(measurements)