# ==============================================================================
#  PROTEGO IA — Motor: InsightFace ArcFace + DeepFace + Anti-Spoofing
#  IA roda em thread separada — display sempre fluido
# ==============================================================================

import cv2
import os
import numpy as np
import time
import math
import threading
import requests
import json
import psycopg2
import paho.mqtt.client as mqtt
import winsound
import logging
from datetime import datetime
from dotenv import load_dotenv
from insightface.app import FaceAnalysis
from deepface import DeepFace

load_dotenv()

# ==============================================================================
#  LOGGING
# ==============================================================================
os.makedirs("logs", exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("logs/protego.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("ProtegIA")

# ==============================================================================
#  CONFIGURAÇÕES
# ==============================================================================
IP_ESP32              = os.getenv("ESP32_IP", "192.168.1.91")
URL_VIDEO             = f"http://{IP_ESP32}:81/stream"
DB_URL                = os.getenv("DB_URL")
MQTT_BROKER           = os.getenv("MQTT_BROKER", "crossover.proxy.rlwy.net")
MQTT_PORT             = int(os.getenv("MQTT_PORT", "11670"))
MQTT_TOPIC_ALERTA     = os.getenv("MQTT_TOPIC_ALERTA", "reconhecimento/facial")
MQTT_TOPIC_STATUS     = "reconhecimento/status"

PASTA_SUSPEITOS       = "suspeitos_detectados"
PASTA_CAPTURAS        = "capturas_alvos"
TEMPO_ESPERA_ALERTA   = 15
TEMPO_PARA_FOTO       = 2.0
COOLDOWN_FOTO         = 15.0
INTERVALO_RELOAD_BD   = 300
TEMPO_VALIDADE_PISCAR = 30.0

TOLERANCIA = {
    "CRITICO": 0.30,
    "ALTO":    0.35,
    "MEDIO":   0.40,
    "BAIXO":   0.45,
}
TOLERANCIA_PADRAO     = 0.40
LIMIAR_LAPLACIAN      = 80
LIMIAR_SATURACAO      = 40
CACHE_EMOCAO_TTL      = 2.0

# ==============================================================================
#  MODELOS
# ==============================================================================
insight_app = None

def inicializar_modelos():
    global insight_app
    log.info("Carregando InsightFace buffalo_l...")
    insight_app = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
    insight_app.prepare(ctx_id=0, det_size=(320, 320))  # 320 = leve para CPU
    log.info("InsightFace pronto.")

# ==============================================================================
#  MEMÓRIA GLOBAL
# ==============================================================================
alvos_encodings          = []
alvos_dados              = []
lock_alvos               = threading.Lock()
ultimo_alerta            = {}
pessoas_vivas            = {}
cache_emocao             = {}
inicio_deteccao_suspeito = 0.0
ultimo_print_suspeito    = 0.0

# Resultado da IA (atualizado pela thread de IA, lido pelo display)
ultimo_resultado         = []
lock_resultado           = threading.Lock()

# ==============================================================================
#  BANCO DE DADOS
# ==============================================================================
def get_conn():
    return psycopg2.connect(DB_URL)

def carregar_alvos_do_banco():
    global alvos_encodings, alvos_dados
    log.info("Carregando alvos do banco...")
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("""
            SELECT p.id, p.nome, p.cpf, p.rg,
                   p.nivel_perigo, p.status, p.observacoes, p.encoding,
                   ARRAY_AGG(DISTINCT m.tipo)       FILTER (WHERE m.ativo = TRUE)           AS mandados,
                   ARRAY_AGG(DISTINCT h.tipo_crime) FILTER (WHERE h.tipo_crime IS NOT NULL) AS crimes,
                   ARRAY_AGG(DISTINCT h.artigo_lei) FILTER (WHERE h.artigo_lei IS NOT NULL) AS artigos
            FROM pessoas p
            LEFT JOIN mandados           m ON m.pessoa_id = p.id AND m.ativo = TRUE
            LEFT JOIN historico_criminal h ON h.pessoa_id = p.id
            GROUP BY p.id
        """)
        rows = cur.fetchall()
        cur.close()
        conn.close()

        novos_enc   = []
        novos_dados = []

        for row in rows:
            (pid, nome, cpf, rg, perigo, status, obs,
             encoding_json, mandados, crimes, artigos) = row

            if encoding_json is None:
                log.warning(f"{nome} — encoding NULL, pulando.")
                continue

            if isinstance(encoding_json, list):
                raw = encoding_json
            else:
                raw = json.loads(encoding_json)

            if not raw:
                log.warning(f"{nome} — encoding vazio, pulando.")
                continue

            if isinstance(raw[0], list):
                encs = [np.array(e, dtype=np.float32) for e in raw]
            else:
                encs = [np.array(raw, dtype=np.float32)]

            encs = [e for e in encs if not np.all(e == 0)]
            if not encs:
                log.warning(f"{nome} — encoding zerado, pulando.")
                continue

            encs = [e / (np.linalg.norm(e) + 1e-6) for e in encs]

            novos_enc.append(encs)
            novos_dados.append({
                "id":          str(pid),
                "nome":        nome,
                "cpf":         cpf  or "Nao informado",
                "rg":          rg   or "Nao informado",
                "perigo":      perigo or "INDEFINIDO",
                "status":      status or "ATIVO",
                "observacoes": obs  or "",
                "mandados":    [m for m in (mandados or []) if m],
                "crimes":      [c for c in (crimes   or []) if c],
                "artigos":     [a for a in (artigos  or []) if a],
            })
            if nome not in ultimo_alerta:
                ultimo_alerta[nome] = 0.0

            log.info(f"  {nome} | {perigo} | {len(encs)} encoding(s)")

        with lock_alvos:
            alvos_encodings[:] = novos_enc
            alvos_dados[:]     = novos_dados

        log.info(f"Total de alvos carregados: {len(alvos_dados)}")

    except Exception as e:
        log.error(f"Erro ao carregar alvos: {e}")

def recarregar_periodicamente():
    while True:
        time.sleep(INTERVALO_RELOAD_BD)
        log.info("Recarregando banco em background...")
        carregar_alvos_do_banco()

def registrar_deteccao(pessoa_id, nome, confianca, prova_de_vida, foto_url=""):
    def _inserir():
        try:
            conn = get_conn()
            cur  = conn.cursor()
            cur.execute("SELECT id FROM cameras LIMIT 1")
            cam = cur.fetchone()
            camera_id = cam[0] if cam else None
            cur.execute("""
                INSERT INTO deteccoes
                    (camera_id, pessoa_id, nome_detectado, confianca, prova_de_vida, foto_captura_url)
                VALUES (%s,%s,%s,%s,%s,%s)
            """, (camera_id, pessoa_id, nome, confianca, prova_de_vida, foto_url))
            conn.commit()
            cur.close()
            conn.close()
            log.info(f"Deteccao registrada: {nome}")
        except Exception as e:
            log.error(f"Erro registrar_deteccao: {e}")
    threading.Thread(target=_inserir, daemon=True).start()

# ==============================================================================
#  MQTT
# ==============================================================================
mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

def conectar_mqtt():
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        mqtt_client.loop_start()
        log.info(f"MQTT conectado em {MQTT_BROKER}:{MQTT_PORT}")
    except Exception as e:
        log.warning(f"MQTT indisponivel: {e}")

def publicar_alerta_mqtt(dados, confianca, prova_de_vida, emocao="", foto_url=""):
    payload = {
        "timestamp":     datetime.now().isoformat(),
        "camera_ip":     IP_ESP32,
        "nome":          dados["nome"],
        "cpf":           dados["cpf"],
        "rg":            dados["rg"],
        "nivel_perigo":  dados["perigo"],
        "status":        dados["status"],
        "mandados":      dados["mandados"],
        "crimes":        dados["crimes"],
        "artigos":       dados["artigos"],
        "observacoes":   dados["observacoes"],
        "confianca":     round(confianca * 100, 1),
        "prova_de_vida": prova_de_vida,
        "tem_mandado":   len(dados["mandados"]) > 0,
        "emocao":        emocao,
        "foto_url":      foto_url,
    }
    try:
        mqtt_client.publish(MQTT_TOPIC_ALERTA, json.dumps(payload), qos=1)
        log.info(f"MQTT publicado: {dados['nome']}")
    except Exception as e:
        log.error(f"Erro MQTT: {e}")

# ==============================================================================
#  IDENTIFICAÇÃO
# ==============================================================================
def identificar_rosto(emb_norm):
    melhor_dados     = None
    melhor_confianca = 0.0
    with lock_alvos:
        for i, encs in enumerate(alvos_encodings):
            dados = alvos_dados[i]
            tol   = TOLERANCIA.get(dados["perigo"], TOLERANCIA_PADRAO)
            sims  = [float(np.dot(emb_norm, e)) for e in encs]
            sim   = max(sims)
            if sim >= (1.0 - tol) and sim > melhor_confianca:
                melhor_confianca = sim
                melhor_dados     = dados
    return melhor_dados, melhor_confianca

# ==============================================================================
#  ANTI-SPOOFING
# ==============================================================================
def detectar_spoofing(frame, x1, y1, x2, y2):
    try:
        roi = frame[y1:y2, x1:x2]
        if roi.size == 0:
            return False
        cinza   = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
        lap_var = cv2.Laplacian(cinza, cv2.CV_64F).var()
        hsv     = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        sat     = float(hsv[:, :, 1].mean())
        return (lap_var < LIMIAR_LAPLACIAN) or (sat < LIMIAR_SATURACAO)
    except Exception:
        return False

# ==============================================================================
#  DEEPFACE — emoção
# ==============================================================================
EMOCOES_PT = {
    "happy": "Feliz", "sad": "Triste", "angry": "Raiva",
    "fear": "Medo", "surprise": "Surpresa",
    "disgust": "Nojo", "neutral": "Neutro",
}

def analisar_emocao_async(roi_bgr, nome_key):
    try:
        r  = DeepFace.analyze(roi_bgr, actions=["emotion"], enforce_detection=False, silent=True)
        em = EMOCOES_PT.get(r[0]["dominant_emotion"], r[0]["dominant_emotion"])
        cache_emocao[nome_key] = {"emocao": em, "ts": time.time()}
    except Exception:
        cache_emocao[nome_key] = {"emocao": "?", "ts": time.time()}

def obter_emocao(frame, x1, y1, x2, y2, nome_key):
    agora  = time.time()
    cached = cache_emocao.get(nome_key)
    if cached is None or (agora - cached["ts"]) > CACHE_EMOCAO_TTL:
        roi = frame[y1:y2, x1:x2]
        if roi.size > 0:
            threading.Thread(target=analisar_emocao_async, args=(roi.copy(), nome_key), daemon=True).start()
    return cached["emocao"] if cached else "..."

# ==============================================================================
#  ALERTAS
# ==============================================================================
def alerta_sonoro(nivel_perigo, tem_mandado):
    try:
        if tem_mandado:
            for _ in range(3):
                winsound.Beep(1200, 200)
                time.sleep(0.05)
        elif nivel_perigo in ("CRITICO", "ALTO"):
            winsound.Beep(1000, 400)
        else:
            winsound.Beep(800, 200)
    except Exception:
        pass

# ==============================================================================
#  CAPTURA
# ==============================================================================
def salvar_captura_alvo(frame, nome):
    os.makedirs(PASTA_CAPTURAS, exist_ok=True)
    ts    = datetime.now().strftime('%Y%m%d_%H%M%S')
    fname = os.path.join(PASTA_CAPTURAS, f"{nome.replace(' ','_')}_{ts}.jpg")
    cv2.imwrite(fname, frame)
    return fname

# ==============================================================================
#  HUD
# ==============================================================================
COR_PERIGO = {
    "CRITICO": (0,0,255), "ALTO": (0,60,255),
    "MEDIO": (0,200,255), "BAIXO": (0,210,0),
}
COR_EMOCAO = {
    "Raiva": (0,0,220), "Medo": (0,180,255), "Surpresa": (0,255,255),
    "Triste": (180,100,0), "Feliz": (0,220,0), "Neutro": (200,200,200),
}

def barra_confianca(frame, x1, y1, largura, conf):
    bw  = int(largura * min(conf, 1.0))
    cor = (0,255,0) if conf > 0.80 else (0,200,255) if conf > 0.65 else (0,0,255)
    cv2.rectangle(frame, (x1, y1-8), (x1+largura, y1-2), (50,50,50),  cv2.FILLED)
    cv2.rectangle(frame, (x1, y1-8), (x1+bw,      y1-2), cor,         cv2.FILLED)

def desenhar_ficha(frame, x1, y1, x2, y2, dados, is_vivo, confianca, spoofing, emocao):
    cor     = COR_PERIGO.get(dados.get("perigo","BAIXO"), (0,210,0))
    largura = x2 - x1
    cv2.rectangle(frame, (x1,y1), (x2,y2), cor, 2)
    barra_confianca(frame, x1, y1, largura, confianca)
    cv2.rectangle(frame, (x1,y2), (x2,y2+90), cor, cv2.FILLED)
    cv2.putText(frame, dados["nome"],                         (x1+5,y2+16), cv2.FONT_HERSHEY_DUPLEX, 0.50, (255,255,255), 1)
    cv2.putText(frame, f"{dados['perigo']}  {confianca:.0%}", (x1+5,y2+31), cv2.FONT_HERSHEY_DUPLEX, 0.38, (255,255,255), 1)
    cor_em = COR_EMOCAO.get(emocao, (200,200,200))
    cv2.putText(frame, f"Emocao: {emocao}",                   (x1+5,y2+46), cv2.FONT_HERSHEY_DUPLEX, 0.38, cor_em, 1)
    if dados.get("mandados"):
        cv2.rectangle(frame, (x1,y2+50), (x2,y2+66), (0,0,160), cv2.FILLED)
        cv2.putText(frame, "!! MANDADO ATIVO !!",             (x1+5,y2+63), cv2.FONT_HERSHEY_DUPLEX, 0.44, (255,255,0), 1)
    if spoofing:
        v_txt, v_cor = "FOTO IMPRESSA!", (0,0,255)
    elif is_vivo:
        v_txt, v_cor = "VIVO - OK", (0,255,0)
    else:
        v_txt, v_cor = "PISQUE!", (0,255,255)
    cv2.putText(frame, v_txt, (x1+5,y2+82), cv2.FONT_HERSHEY_DUPLEX, 0.38, v_cor, 1)

def desenhar_desconhecido(frame, x1, y1, x2, y2, emocao, spoofing):
    cv2.rectangle(frame, (x1,y1), (x2,y2), (0,0,200), 2)
    cv2.rectangle(frame, (x1,y2), (x2,y2+40), (0,0,200), cv2.FILLED)
    txt = "FOTO IMPRESSA" if spoofing else "DESCONHECIDO"
    cv2.putText(frame, txt,             (x1+5,y2+16), cv2.FONT_HERSHEY_DUPLEX, 0.50, (255,255,255), 1)
    if emocao not in ("...","?",""):
        cor_em = COR_EMOCAO.get(emocao, (200,200,200))
        cv2.putText(frame, f"Emocao: {emocao}", (x1+5,y2+33), cv2.FONT_HERSHEY_DUPLEX, 0.36, cor_em, 1)

def desenhar_hud(frame, n_rostos, fps):
    with lock_alvos:
        n_alvos = len(alvos_dados)
    cv2.putText(frame, datetime.now().strftime("%d/%m/%Y  %H:%M:%S"), (10,25),  cv2.FONT_HERSHEY_DUPLEX, 0.50, (255,255,255), 1)
    cv2.putText(frame, f"Rostos: {n_rostos}",                          (10,45),  cv2.FONT_HERSHEY_DUPLEX, 0.50, (255,255,255), 1)
    cv2.putText(frame, f"FPS: {fps:.1f}",                              (10,65),  cv2.FONT_HERSHEY_DUPLEX, 0.50, (255,255,255), 1)
    cv2.putText(frame, f"Alvos: {n_alvos}",                            (10,85),  cv2.FONT_HERSHEY_DUPLEX, 0.50, (0,255,255),   1)
    cv2.putText(frame, "InsightFace ArcFace",                          (10,105), cv2.FONT_HERSHEY_DUPLEX, 0.38, (80,200,80),   1)

# ==============================================================================
#  THREAD DE VÍDEO
# ==============================================================================
class VideoStream:
    def __init__(self, url):
        self.url     = url
        self.frame   = None
        self.stopped = False
        self.lock    = threading.Lock()
        log.info(f"Conectando: {url}...")

    def start(self):
        threading.Thread(target=self._update, daemon=True).start()
        for _ in range(80):
            time.sleep(0.1)
            if self.frame is not None:
                log.info("Stream recebido!")
                break
        return self

    def _update(self):
        cap = cv2.VideoCapture(self.url)
        if cap.isOpened():
            log.info("Usando VideoCapture.")
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            while not self.stopped:
                ret, f = cap.read()
                if not ret or f is None:
                    cap.release()
                    time.sleep(2)
                    cap = cv2.VideoCapture(self.url)
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    continue
                with self.lock:
                    self.frame = f
            cap.release()
        else:
            cap.release()
            log.info("VideoCapture falhou. Usando requests MJPEG...")
            self._update_requests()

    def _update_requests(self):
        while not self.stopped:
            try:
                with requests.get(self.url, stream=True, timeout=10) as r:
                    buf = bytes()
                    for chunk in r.iter_content(chunk_size=8192):
                        if self.stopped:
                            return
                        buf += chunk
                        while True:
                            ini = buf.find(b'\xff\xd8')
                            fim = buf.find(b'\xff\xd9')
                            if ini == -1 or fim == -1 or fim <= ini:
                                break
                            jpg = buf[ini:fim+2]
                            buf = buf[fim+2:]
                            arr = np.frombuffer(jpg, dtype=np.uint8)
                            f   = cv2.imdecode(arr, cv2.IMREAD_COLOR)
                            if f is not None:
                                with self.lock:
                                    self.frame = f
            except requests.exceptions.ConnectionError:
                log.warning("Camera desconectada. Reconectando em 3s...")
                time.sleep(3)
            except Exception as e:
                log.error(f"Erro stream: {e}")
                time.sleep(3)

    def read(self):
        with self.lock:
            return self.frame.copy() if self.frame is not None else None

    def stop(self):
        self.stopped = True

# ==============================================================================
#  THREAD DA IA — roda InsightFace em paralelo com o display
# ==============================================================================
def configurar_esp32():
    try:
        requests.get(f"http://{IP_ESP32}/control?var=framesize&val=8", timeout=2)
        requests.get(f"http://{IP_ESP32}/control?var=quality&val=12",  timeout=2)
        log.info("ESP32 configurado: VGA")
    except Exception:
        log.warning("Nao foi possivel configurar ESP32")

class ThreadIA:
    def __init__(self):
        self.frame_atual  = None
        self.processando  = False
        self.lock_frame   = threading.Lock()
        self.parar        = False

    def enviar_frame(self, frame):
        if not self.processando:
            with self.lock_frame:
                self.frame_atual = frame.copy()

    def start(self):
        threading.Thread(target=self._loop, daemon=True).start()

    def _loop(self):
        global inicio_deteccao_suspeito, ultimo_print_suspeito
        while not self.parar:
            with self.lock_frame:
                frame = self.frame_atual
                self.frame_atual = None

            if frame is None:
                time.sleep(0.01)
                continue

            self.processando = True
            try:
                img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                faces   = insight_app.get(img_rgb)
                agora   = time.time()
                tem_desc = False
                resultado = []

                for face in faces:
                    bbox = face.bbox.astype(int)
                    x1 = max(0, bbox[0]); y1 = max(0, bbox[1])
                    h_f, w_f = frame.shape[:2]
                    x2 = min(w_f-1, bbox[2]); y2 = min(h_f-1, bbox[3])

                    emb  = face.embedding.astype(np.float32)
                    emb  = emb / (np.linalg.norm(emb) + 1e-6)

                    dados_alvo, confianca = identificar_rosto(emb)
                    spoofing  = detectar_spoofing(frame, x1, y1, x2, y2)
                    nome_key  = dados_alvo["nome"] if dados_alvo else f"DESC_{x1}_{y1}"

                    kps = face.kps
                    if kps is not None and len(kps) >= 2:
                        dy = abs(float(kps[0][1]) - float(kps[1][1]))
                        if dy < 3.0:
                            pessoas_vivas[nome_key] = agora

                    is_vivo = (agora - pessoas_vivas.get(nome_key, 0)) < TEMPO_VALIDADE_PISCAR
                    emocao  = obter_emocao(frame, x1, y1, x2, y2, nome_key)

                    if dados_alvo and not spoofing:
                        nome = dados_alvo["nome"]
                        if (agora - ultimo_alerta.get(nome, 0)) > TEMPO_ESPERA_ALERTA:
                            ultimo_alerta[nome] = agora
                            log.info(f"ALVO: {nome} | {dados_alvo['perigo']} | {confianca:.0%} | {emocao}")
                            if dados_alvo["mandados"]:
                                log.info(f"  MANDADO: {', '.join(dados_alvo['mandados'])}")
                            foto = salvar_captura_alvo(frame, nome)
                            threading.Thread(target=alerta_sonoro, args=(dados_alvo["perigo"], len(dados_alvo["mandados"]) > 0), daemon=True).start()
                            publicar_alerta_mqtt(dados_alvo, confianca, is_vivo, emocao, foto)
                            registrar_deteccao(dados_alvo["id"], nome, confianca, is_vivo, foto)
                    elif not dados_alvo:
                        tem_desc = True

                    resultado.append({
                        "box": (x1,y1,x2,y2), "dados": dados_alvo,
                        "is_vivo": is_vivo, "confianca": confianca,
                        "spoofing": spoofing, "emocao": emocao,
                    })

                with lock_resultado:
                    ultimo_resultado.clear()
                    ultimo_resultado.extend(resultado)

                if tem_desc:
                    if inicio_deteccao_suspeito == 0:
                        inicio_deteccao_suspeito = agora
                    elif (agora - inicio_deteccao_suspeito) >= TEMPO_PARA_FOTO:
                        if (agora - ultimo_print_suspeito) > COOLDOWN_FOTO:
                            cinza = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                            if cv2.Laplacian(cinza, cv2.CV_64F).var() >= 50:
                                ts    = datetime.now().strftime('%Y%m%d_%H%M%S')
                                fname = os.path.join(PASTA_SUSPEITOS, f"SUSPEITO_{ts}.jpg")
                                cv2.imwrite(fname, frame)
                                log.info(f"Suspeito capturado: {fname}")
                            ultimo_print_suspeito = agora
                else:
                    inicio_deteccao_suspeito = 0

            except Exception as e:
                log.error(f"Erro thread IA: {e}")
            finally:
                self.processando = False

# ==============================================================================
#  MAIN
# ==============================================================================
def main():
    os.makedirs(PASTA_SUSPEITOS, exist_ok=True)
    os.makedirs(PASTA_CAPTURAS,  exist_ok=True)

    print("=" * 60)
    print("  PROTEGO IA — InsightFace ArcFace + DeepFace")
    print("=" * 60)

    inicializar_modelos()
    carregar_alvos_do_banco()
    conectar_mqtt()
    configurar_esp32()

    threading.Thread(target=recarregar_periodicamente, daemon=True).start()

    camera = VideoStream(URL_VIDEO).start()
    ia     = ThreadIA()
    ia.start()

    if camera.read() is None:
        log.error(f"Sem frames da camera: {URL_VIDEO}")
        return

    log.info("Sistema ativo! Pressione Q para sair.")

    frame_count = 0
    t_fps       = time.time()
    fps         = 0.0

    while True:
        frame = camera.read()

        if frame is None or frame.size == 0:
            tela = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(tela, "Aguardando camera...", (90,240), cv2.FONT_HERSHEY_DUPLEX, 1, (0,255,255), 2)
            cv2.imshow("Protego IA — Q para sair", tela)
            if cv2.waitKey(200) & 0xFF == ord('q'):
                break
            continue

        frame_count += 1

        # FPS
        if frame_count % 30 == 0:
            fps   = 30 / (time.time() - t_fps + 1e-6)
            t_fps = time.time()

        # Envia para thread IA a cada 3 frames
        if frame_count % 3 == 0:
            ia.enviar_frame(frame)

        # Desenha resultados do último processamento
        with lock_resultado:
            res_atual = list(ultimo_resultado)

        for res in res_atual:
            x1, y1, x2, y2 = res["box"]
            if res["dados"]:
                desenhar_ficha(frame, x1, y1, x2, y2, res["dados"],
                               res["is_vivo"], res["confianca"],
                               res["spoofing"], res["emocao"])
            else:
                desenhar_desconhecido(frame, x1, y1, x2, y2,
                                      res["emocao"], res["spoofing"])

        desenhar_hud(frame, len(res_atual), fps)
        cv2.imshow("Protego IA — Q para sair", frame)
        if cv2.waitKey(30) & 0xFF == ord('q'):
            break

    log.info("Encerrando...")
    try:
        mqtt_client.publish(MQTT_TOPIC_STATUS, json.dumps({"status": "offline"}))
        mqtt_client.loop_stop()
    except Exception:
        pass
    ia.parar = True
    camera.stop()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()