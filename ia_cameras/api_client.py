import requests
import threading
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

API_URL = "https://protegoia-production.up.railway.app"
DEVICE_ID = "camera_01"

class ApiClient:
    def __init__(self, api_url=API_URL, device_id=DEVICE_ID):
        self.api_url = api_url
        self.device_id = device_id
        self.session = requests.Session()

    def _post_async(self, endpoint, data):
        def _send():
            try:
                response = self.session.post(
                    f"{self.api_url}{endpoint}",
                    json=data,
                    timeout=5
                )
                logger.debug(f"API {endpoint}: {response.status_code}")
            except Exception as e:
                logger.warning(f"API error {endpoint}: {e}")
        threading.Thread(target=_send, daemon=True).start()

    def enviar_deteccao(self, nome, nivel, confianca, emocao=None):
        data = {
            "device_id": self.device_id,
            "nome": nome,
            "nivel_perigo": nivel,
            "confianca": confianca,
            "emocao": emocao,
            "timestamp": datetime.now().isoformat()
        }
        self._post_async("/deteccoes", data)

    def enviar_alerta(self, nome, nivel, confianca):
        data = {
            "device_id": self.device_id,
            "nome": nome,
            "nivel_perigo": nivel,
            "confianca": confianca,
            "timestamp": datetime.now().isoformat()
        }
        self._post_async("/alertas", data)

    def enviar_heartbeat(self):
        data = {
            "device_id": self.device_id,
            "status": "ONLINE",
            "timestamp": datetime.now().isoformat()
        }
        self._post_async("/heartbeat", data)