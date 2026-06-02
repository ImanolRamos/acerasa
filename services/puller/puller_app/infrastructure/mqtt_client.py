import paho.mqtt.client as mqtt
import redis

from puller_app.infrastructure.config import MqttConfig, RedisConfig
from puller_app.application.enqueue_mqtt_message import handle_message

class MessageHandler:
    def __init__(self, redis_client: redis.Redis, redis_config: RedisConfig):
        self.redis_client = redis_client
        self.redis_config = redis_config
        
    def on_message(self, client, userdata, msg):
        self.redis_client = handle_message(
            self.redis_client,
            self.redis_config,
            msg,
        )


def create_on_connect_callback(topic: str):
    def on_connect(client, userdata, flags, rc):
        if rc == 0:
            print(f"Conectado a MQTT con código {rc}")
            result, mid = client.subscribe(topic, qos=1)
            if result == mqtt.MQTT_ERR_SUCCESS:
                print(f"Suscrito a: {topic}")
            else:
                print(f"Error al suscribirse a {topic}. Código: {result}")
                client.disconnect()
        else:
            print(f"Error conectando a MQTT. Código: {rc}")

    return on_connect


def create_mqtt_client(redis_client: redis.Redis, redis_config: RedisConfig, mqtt_config: MqttConfig) -> mqtt.Client:
    message_handler = MessageHandler(redis_client, redis_config)
    mqtt_client = mqtt.Client(client_id=mqtt_config.client_id, clean_session=False)

    if mqtt_config.username:
        mqtt_client.username_pw_set(mqtt_config.username, mqtt_config.password)

    mqtt_client.on_connect = create_on_connect_callback(mqtt_config.topic)
    mqtt_client.on_message = message_handler.on_message

    return mqtt_client