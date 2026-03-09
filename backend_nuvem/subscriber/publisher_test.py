import paho.mqtt.client as mqtt
import json
import time

BROKER = "localhost"
PORT = 1883

messages = [
    ("policia/cam01/status", {"device_id": "cam01", "status": "online"}),
    ("policia/cam01/eventos", {"evento": "captura_iniciada"}),
    ("policia/cam01/respostas", {"resultado": "comando_recebido"}),
]

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.connect(BROKER, PORT, 60)
client.loop_start()

for topic, payload in messages:
    payload_str = json.dumps(payload)
    client.publish(topic, payload_str)
    print(f"[PUB] {topic} -> {payload_str}")
    time.sleep(1)

client.loop_stop()
client.disconnect()