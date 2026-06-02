import time

from puller_app.infrastructure.config import MQTT_CONFIG, REDIS_CONFIG
from puller_app.infrastructure.redis_queue import get_redis_client
from puller_app.infrastructure.mqtt_client import create_mqtt_client


def run() -> None:
    redis_client = get_redis_client(REDIS_CONFIG)
    mqtt_client = create_mqtt_client(redis_client, REDIS_CONFIG, MQTT_CONFIG)

    while True:
        try:
            print(f"Conectando a {MQTT_CONFIG.host}:{MQTT_CONFIG.port}...")
            mqtt_client.connect(MQTT_CONFIG.host, MQTT_CONFIG.port, 60)
            mqtt_client.loop_forever()
        except Exception as e:
            print(f"Error MQTT: {e}")
            time.sleep(5)


if __name__ == "__main__":
    run()