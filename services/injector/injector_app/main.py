import time
import json

import redis

from injector_app.infrastructure.config import DB_CONFIG, REDIS_CONFIG
from injector_app.infrastructure.redis_queue import get_redis_client
from injector_app.infrastructure.postgres_measurement_repository import get_db_connection
from injector_app.application.process_queue_message import process_next_message

def run() -> None:
    redis_client = get_redis_client(REDIS_CONFIG)
    db_connection = get_db_connection(DB_CONFIG)

    while True:
        try:
            measurements = process_next_message(redis_client, REDIS_CONFIG, db_connection)
            print(f"Insertadas {measurements} measurements")

        except redis.RedisError as e:
            print(f"Error de Redis: {e}")
            redis_client = get_redis_client(REDIS_CONFIG)
            time.sleep(5)

        except json.JSONDecodeError as e:
            print(f"Error parseando JSON del mensaje: {e}")
            time.sleep(1)

        except ValueError as e:
            print(f"Error de validación: {e}")
            time.sleep(1)

        except Exception as e:
            db_connection.rollback()
            print(f"Error procesando mensaje: {e}")
            time.sleep(1)

if __name__ == "__main__":
    run()