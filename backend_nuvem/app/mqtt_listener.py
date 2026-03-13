import json
import os
import threading
from typing import Any

import paho.mqtt.client as mqtt

from app.database import SessionLocal
from app.models import Pessoa

MQTT_BROKER_HOST = os.getenv("MQTT_BROKER_HOST")
MQTT_BROKER_PORT = int(os.getenv("MQTT_BROKER_PORT", "1883"))
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "reconhecimento/facial")


def salvar_pessoa(payload: dict[str, Any]) -> None:
    db = SessionLocal()
    try:
        pessoa = Pessoa(
            timestamp=payload.get("timestamp", ""),
            nome=payload.get("nome", ""),
            cpf=payload.get("cpf", ""),
            rg=payload.get("rg", ""),
            nivel_perigo=payload.get("nivel_perigo", ""),
            status=payload.get("status", ""),
            mandados=",".join(payload.get("mandados", [])) if isinstance(payload.get("mandados"), list) else str(payload.get("mandados", "")),
            crimes=",".join(payload.get("crimes", [])) if isinstance(payload.get("crimes"), list) else str(payload.get("crimes", "")),
            artigos=",".join(payload.get("artigos", [])) if isinstance(payload.get("artigos"), list) else str(payload.get("artigos", "")),
            observacoes=payload.get("observacoes", ""),
            confianca=float(payload.get("confianca", 0)),
            prova_de_vida=bool(payload.get("prova_de_vida", False)),
            tem_mandado=bool(payload.get("tem_mandado", False)),
        )
        db.add(pessoa)
        db.commit()
        print(f"[MQTT] Pessoa salva no banco: {pessoa.nome}")
    except Exception as e:
        db.rollback()
        print(f"[MQTT] Erro ao salvar no banco: {e}")
    finally:
        db.close()


def on_connect(client: mqtt.Client, userdata, flags, reason_code, properties=None):
    print(f"[MQTT] Conectado ao broker com código: {reason_code}")
    client.subscribe(MQTT_TOPIC)
    print(f"[MQTT] Inscrito no tópico: {MQTT_TOPIC}")


def on_message(client: mqtt.Client, userdata, msg: mqtt.MQTTMessage):
    try:
        payload_str = msg.payload.decode()
        print(f"[MQTT] Mensagem recebida em {msg.topic}: {payload_str}")
        payload = json.loads(payload_str)
        salvar_pessoa(payload)
    except Exception as e:
        print(f"[MQTT] Erro ao processar mensagem: {e}")


def iniciar_mqtt_listener() -> None:
    if not MQTT_BROKER_HOST:
        print("[MQTT] MQTT_BROKER_HOST não definido. Listener não iniciado.")
        return

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT, 60)
    client.loop_forever()


def iniciar_mqtt_em_thread() -> None:
    thread = threading.Thread(target=iniciar_mqtt_listener, daemon=True)
    thread.start()