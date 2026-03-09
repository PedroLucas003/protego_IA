import paho.mqtt.client as mqtt

BROKER = "localhost"
PORT = 1883

TOPICS = [
    ("policia/cam01/status", 0),
    ("policia/cam01/eventos", 0),
    ("policia/cam01/respostas", 0),
]

def on_connect(client, userdata, flags, reason_code, properties=None):
    print("[INFO] Iniciando subscriber MQTT...")
    print(f"[INFO] Conectado ao broker MQTT com código: {reason_code}")

    client.subscribe(TOPICS)

    print("[INFO] Inscrito nos tópicos do projeto:")
    for topic, _ in TOPICS:
        print(f" - {topic}")

def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    print(f"[MSG] Tópico: {msg.topic} | Payload: {payload}")

def main():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect(BROKER, PORT, 60)
    client.loop_forever()

if __name__ == "__main__":
    main()