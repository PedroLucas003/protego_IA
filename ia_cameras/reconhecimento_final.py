# ==============================================================================
#  PROTEGO IA — Motor: InsightFace ArcFace + DeepFace + Anti-Spoofing
#
#  Dependências:
#    pip install insightface onnxruntime deepface opencv-python
#    pip install psycopg2-binary paho-mqtt python-dotenv requests pillow
#
#  Na primeira execução o InsightFace baixa o modelo buffalo_l (~200MB)
#  automaticamente. Precisa de internet uma única vez.
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

# InsightFace (ArcFace — motor principal de reconhecimento)
import insightface
from insightface.app import FaceAnalysis

# DeepFace (estimativa de emoção)
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
MQTT_BROKER           = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT             = int(os.getenv("MQTT_PORT", "1883"))
MQTT_TOPIC_ALERTA     = "bodycam/alerta"
MQTT_TOPIC_STATUS     = "bodycam/camera/status"

PASTA_SUSPEITOS       = "suspeitos_detectados"
PASTA_CAPTURAS        = "capturas_alvos"
TEMPO_ESPERA_ALERTA   = 15
TEMPO_PARA_FOTO       = 2.0
COOLDOWN_FOTO         = 15.0
INTERVALO_RELOAD_BD   = 300

# Limiar de similaridade coseno InsightFace (quanto maior = mais exigente)
# ArcFace usa distância coseno — threshold típico entre 0.3 e 0.5
TOLERANCIA = {
    "CRITICO": 0.30,   # mais permissivo — não deixa escapar
    "ALTO":    0.35,
    "MEDIO":   0.40,
    "BAIXO":   0.45,   # mais exigente
}
TOLERANCIA_PADRAO = 0.40

# Anti-spoofing
LIMIAR_LAPLACIAN      = 80    # variância mínima — abaixo = foto impressa
LIMIAR_SATURACAO      = 40    # saturação mínima — abaixo = foto P&B impressa

# Prova de vida — EAR
LIMITE_PISCAR         = 0.22
TEMPO_VALIDADE_PISCAR = 30.0

# ==============================================================================
#  MODELOS DE IA — carregados uma vez na inicialização
# ==============================================================================
insight_app = None

def inicializar_modelos():
    global insight_app
    log.info("Carregando InsightFace buffalo_l (primeira vez baixa ~200MB)...")
    insight_app = FaceAnalysis(
        name="buffalo_l",
        providers=["CPUExecutionProvider"]  # trocar por CUDAExecutionProvider se tiver GPU
    )
    insight_app.prepare(ctx_id=0, det_size=(640, 640))
    log.info("InsightFace pronto.")

# ==============================================================================
#  MEMÓRIA GLOBAL
# ==============================================================================
alvos_encodings  = []   # lista de np.array (512 floats — ArcFace)
alvos_dados      = []   # ficha completa
lock_alvos       = threading.Lock()
ultimo_alerta    = {}
pessoas_vivas    = {}
inicio_deteccao_suspeito = 0.0
ultimo_print_suspeito    = 0.0

# Cache de emoção (evita chamar DeepFace todo frame — pesado)
cache_emocao     = {}   # nome_key → {"emocao": str, "ts": float}
CACHE_EMOCAO_TTL = 2.0  # atualiza emoção a cada 2 segundos por rosto

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
            SELECT
                p.id, p.nome_completo, p.cpf, p.rg,
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

        novos_enc  = []
        novos_dados = []

        for row in rows:
            (pid, nome, cpf, rg, perigo, status, obs,
             encoding_json, mandados, crimes, artigos) = row

            # psycopg2 converte JSONB → lista Python automaticamente
            if isinstance(encoding_json, list):
                raw = encoding_json
            else:
                raw = json.loads(encoding_json)

            # Suporta múltiplos encodings (lista de listas) ou encoding único
            if raw and isinstance(raw[0], list):
                encs = [np.array(e, dtype=np.float32) for e in raw]
            else:
                encs = [np.array(raw, dtype=np.float32)]

            # Remove encodings zerados
            encs = [e for e in encs if not np.all(e == 0)]
            if not encs:
                log.warning(f"{nome} — encoding vazio, pulando.")
                continue

            # Normaliza para similaridade coseno
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

            mandado_txt = "MANDADO ATIVO" if mandados and any(mandados) else "sem mandado"
            log.info(f"  {nome} | {perigo} | {mandado_txt} | {len(encs)} encoding(s)")

        with lock_alvos:
            alvos_encodings = novos_enc
            alvos_dados     = novos_dados

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
            cam       = cur.fetchone()
            camera_id = cam[0] if cam else None
            cur.execute("""
                INSERT INTO deteccoes
                    (camera_id, pessoa_id, nome_detectado, confianca, prova_de_vida, foto_captura_url)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING id
            """, (camera_id, pessoa_id, nome, confianca, prova_de_vida, foto_url))
            did = cur.fetchone()[0]
            cur.execute("""
                INSERT INTO alertas (deteccao_id, canal, mensagem, sucesso)
                VALUES (%s,%s,%s,%s)
            """, (did, "sistema", f"Alvo detectado: {nome}", True))
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
#  INSIGHTFACE — identificação com ArcFace (512 dimensões)
# ==============================================================================
def similaridade_coseno(enc_a, enc_b):
    """Retorna similaridade coseno entre dois vetores normalizados."""
    return float(np.dot(enc_a, enc_b))

def identificar_rosto(embedding_norm):
    """
    Compara embedding (já normalizado) contra todos os alvos do banco.
    Retorna (dados_alvo, confianca) ou (None, 0.0).
    """
    melhor_dados     = None
    melhor_confianca = 0.0

    with lock_alvos:
        for i, encs_pessoa in enumerate(alvos_encodings):
            dados = alvos_dados[i]
            tol   = TOLERANCIA.get(dados["perigo"], TOLERANCIA_PADRAO)

            # Compara contra todos os encodings da pessoa (múltiplas fotos)
            sims      = [similaridade_coseno(embedding_norm, e) for e in encs_pessoa]
            max_sim   = max(sims)

            # ArcFace: similaridade > (1 - tolerância) → match
            if max_sim >= (1.0 - tol) and max_sim > melhor_confianca:
                melhor_confianca = max_sim
                melhor_dados     = dados

    return melhor_dados, melhor_confianca

# ==============================================================================
#  ANTI-SPOOFING — combinação Laplacian + saturação de cor
# ==============================================================================
def detectar_spoofing(frame, x1, y1, x2, y2):
    """
    Detecta foto impressa ou tela usando dois filtros:
    1. Variância do Laplacian — imagens planas têm var baixa
    2. Saturação média HSV  — fotos impressas perdem saturação
    Retorna True se parecer ataque de spoofing.
    """
    try:
        roi  = frame[y1:y2, x1:x2]
        if roi.size == 0:
            return False

        # Filtro 1 — nitidez / textura
        cinza    = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
        lap_var  = cv2.Laplacian(cinza, cv2.CV_64F).var()

        # Filtro 2 — saturação de cor
        hsv      = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        sat_mean = float(hsv[:, :, 1].mean())

        spoof = (lap_var < LIMIAR_LAPLACIAN) or (sat_mean < LIMIAR_SATURACAO)
        return spoof

    except Exception:
        return False

# ==============================================================================
#  DEEPFACE — estimativa de emoção (em thread separada, cache de 2s)
# ==============================================================================
EMOCOES_PT = {
    "happy":     "Feliz",
    "sad":       "Triste",
    "angry":     "Raiva",
    "fear":      "Medo",
    "surprise":  "Surpresa",
    "disgust":   "Nojo",
    "neutral":   "Neutro",
}

def analisar_emocao_async(roi_bgr, nome_key):
    """Roda DeepFace em thread separada e atualiza o cache."""
    try:
        resultado = DeepFace.analyze(
            roi_bgr,
            actions=["emotion"],
            enforce_detection=False,
            silent=True
        )
        emocao_en = resultado[0]["dominant_emotion"]
        emocao_pt = EMOCOES_PT.get(emocao_en, emocao_en.capitalize())
        cache_emocao[nome_key] = {"emocao": emocao_pt, "ts": time.time()}
    except Exception:
        cache_emocao[nome_key] = {"emocao": "?", "ts": time.time()}

def obter_emocao(frame, x1, y1, x2, y2, nome_key):
    """
    Retorna emoção do cache. Se expirou, dispara nova análise em background.
    """
    agora   = time.time()
    cached  = cache_emocao.get(nome_key)

    if cached is None or (agora - cached["ts"]) > CACHE_EMOCAO_TTL:
        roi = frame[y1:y2, x1:x2]
        if roi.size > 0:
            threading.Thread(
                target=analisar_emocao_async,
                args=(roi.copy(), nome_key),
                daemon=True
            ).start()

    return cached["emocao"] if cached else "..."

# ==============================================================================
#  EAR — prova de vida (piscar de olhos)
# ==============================================================================
def distancia_pts(p1, p2):
    return math.sqrt((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2)

def calcular_ear(olho):
    A = distancia_pts(olho[1], olho[5])
    B = distancia_pts(olho[2], olho[4])
    C = distancia_pts(olho[0], olho[3])
    return (A + B) / (2.0 * C) if C != 0 else 0.0

# ==============================================================================
#  ALERTAS — sonoro
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
#  HUD — overlay visual
# ==============================================================================
COR_PERIGO = {
    "CRITICO": (0,   0,   255),
    "ALTO":    (0,   60,  255),
    "MEDIO":   (0,   200, 255),
    "BAIXO":   (0,   210, 0  ),
}
COR_EMOCAO = {
    "Raiva":    (0,   0,   220),
    "Medo":     (0,   180, 255),
    "Surpresa": (0,   255, 255),
    "Triste":   (180, 100, 0  ),
    "Feliz":    (0,   220, 0  ),
    "Neutro":   (200, 200, 200),
}

def barra_confianca(frame, x1, y1, largura, confianca):
    h    = 6
    bw   = int(largura * min(confianca, 1.0))
    cor  = (0,255,0) if confianca > 0.80 else (0,200,255) if confianca > 0.65 else (0,0,255)
    cv2.rectangle(frame, (x1, y1-h-2), (x1+largura, y1-2), (50,50,50),   cv2.FILLED)
    cv2.rectangle(frame, (x1, y1-h-2), (x1+bw,      y1-2), cor,          cv2.FILLED)

def barra_suspeito_prog(frame, inicio, agora, x1, y2, largura):
    if inicio == 0:
        return
    prog  = min((agora - inicio) / TEMPO_PARA_FOTO, 1.0)
    bw    = int(largura * prog)
    cv2.rectangle(frame, (x1, y2+3), (x1+largura, y2+9), (40,40,40),  cv2.FILLED)
    cv2.rectangle(frame, (x1, y2+3), (x1+bw,      y2+9), (0,0,255),   cv2.FILLED)
    rest  = max(0, TEMPO_PARA_FOTO - (agora - inicio))
    cv2.putText(frame, f"Foto em {rest:.1f}s", (x1+4, y2+22),
                cv2.FONT_HERSHEY_DUPLEX, 0.38, (0,0,255), 1)

def desenhar_ficha(frame, x1, y1, x2, y2, dados, is_vivo, confianca, spoofing, emocao):
    perigo   = dados.get("perigo", "BAIXO")
    cor      = COR_PERIGO.get(perigo, (0,200,0))
    largura  = x2 - x1
    altura_p = 90  # altura do painel inferior

    cv2.rectangle(frame, (x1, y1), (x2, y2), cor, 2)
    barra_confianca(frame, x1, y1, largura, confianca)

    # Painel inferior
    cv2.rectangle(frame, (x1, y2), (x2, y2+altura_p), cor, cv2.FILLED)

    # Linha 1 — nome
    cv2.putText(frame, dados["nome"],
                (x1+5, y2+16), cv2.FONT_HERSHEY_DUPLEX, 0.52, (255,255,255), 1)

    # Linha 2 — perigo + confiança
    cv2.putText(frame, f"{perigo}  |  {confianca:.0%}",
                (x1+5, y2+31), cv2.FONT_HERSHEY_DUPLEX, 0.40, (255,255,255), 1)

    # Linha 3 — emoção
    cor_em = COR_EMOCAO.get(emocao, (200,200,200))
    cv2.putText(frame, f"Emocao: {emocao}",
                (x1+5, y2+48), cv2.FONT_HERSHEY_DUPLEX, 0.40, cor_em, 1)

    # Linha 4 — mandado
    if dados.get("mandados"):
        cv2.rectangle(frame, (x1, y2+53), (x2, y2+68), (0,0,160), cv2.FILLED)
        cv2.putText(frame, "!! MANDADO ATIVO !!",
                    (x1+5, y2+65), cv2.FONT_HERSHEY_DUPLEX, 0.46, (255,255,0), 1)

    # Linha 5 — prova de vida / spoofing
    if spoofing:
        v_txt, v_cor = "FOTO IMPRESSA!", (0,0,255)
    elif is_vivo:
        v_txt, v_cor = "VIVO - OK", (0,255,0)
    else:
        v_txt, v_cor = "PISQUE!", (0,255,255)
    cv2.putText(frame, v_txt,
                (x1+5, y2+84), cv2.FONT_HERSHEY_DUPLEX, 0.40, v_cor, 1)

def desenhar_desconhecido(frame, x1, y1, x2, y2, emocao, spoofing, inicio_sus, agora):
    largura = x2 - x1
    cor     = (0, 0, 200)
    cv2.rectangle(frame, (x1, y1), (x2, y2), cor, 2)
    cv2.rectangle(frame, (x1, y2), (x2, y2+42), cor, cv2.FILLED)
    txt = "FOTO IMPRESSA" if spoofing else "DESCONHECIDO"
    cv2.putText(frame, txt,
                (x1+5, y2+16), cv2.FONT_HERSHEY_DUPLEX, 0.52, (255,255,255), 1)
    if emocao and emocao not in ("...", "?"):
        cor_em = COR_EMOCAO.get(emocao, (200,200,200))
        cv2.putText(frame, f"Emocao: {emocao}",
                    (x1+5, y2+34), cv2.FONT_HERSHEY_DUPLEX, 0.38, cor_em, 1)
    barra_suspeito_prog(frame, inicio_sus, agora, x1, y2+42, largura)

def desenhar_hud(frame, n_rostos, fps, ultimo_reload):
    with lock_alvos:
        n_alvos = len(alvos_dados)
    agora_txt = datetime.now().strftime("%d/%m/%Y  %H:%M:%S")
    cv2.putText(frame, agora_txt,             (10,25),  cv2.FONT_HERSHEY_DUPLEX,0.50,(255,255,255),1)
    cv2.putText(frame, f"Rostos: {n_rostos}", (10,45),  cv2.FONT_HERSHEY_DUPLEX,0.50,(255,255,255),1)
    cv2.putText(frame, f"FPS: {fps:.1f}",     (10,65),  cv2.FONT_HERSHEY_DUPLEX,0.50,(255,255,255),1)
    cv2.putText(frame, f"Alvos: {n_alvos}",   (10,85),  cv2.FONT_HERSHEY_DUPLEX,0.50,(0,255,255),  1)
    cv2.putText(frame, f"BD: {ultimo_reload}", (10,105), cv2.FONT_HERSHEY_DUPLEX,0.38,(150,150,150),1)
    cv2.putText(frame, "InsightFace ArcFace", (10,125), cv2.FONT_HERSHEY_DUPLEX,0.38,(80,200,80),  1)

# ==============================================================================
#  CAPTURA DE FOTO
# ==============================================================================
def salvar_captura_alvo(frame, nome):
    os.makedirs(PASTA_CAPTURAS, exist_ok=True)
    ts    = datetime.now().strftime('%Y%m%d_%H%M%S')
    fname = os.path.join(PASTA_CAPTURAS, f"{nome.replace(' ','_')}_{ts}.jpg")
    cv2.imwrite(fname, frame)
    return fname

# ==============================================================================
#  CONFIGURAÇÃO ESP32
# ==============================================================================
def configurar_esp32():
    try:
        requests.get(f"http://{IP_ESP32}/control?var=framesize&val=8", timeout=2)
        requests.get(f"http://{IP_ESP32}/control?var=quality&val=12",  timeout=2)
        log.info("ESP32 configurado: VGA, qualidade alta")
    except Exception:
        log.warning("Nao foi possivel configurar ESP32 via HTTP")

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
        for _ in range(50):
            time.sleep(0.1)
            if self.frame is not None:
                log.info("Stream recebido!")
                break
        return self

    def _update(self):
        while not self.stopped:
            try:
                with requests.get(self.url, stream=True, timeout=10) as r:
                    buf = bytes()
                    for chunk in r.iter_content(chunk_size=4096):
                        if self.stopped:
                            return
                        buf += chunk
                        ini = buf.find(b'\xff\xd8')
                        fim = buf.find(b'\xff\xd9')
                        if ini != -1 and fim != -1 and fim > ini:
                            jpg   = buf[ini:fim+2]
                            buf   = buf[fim+2:]
                            arr   = np.frombuffer(jpg, dtype=np.uint8)
                            f     = cv2.imdecode(arr, cv2.IMREAD_COLOR)
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
#  LOOP PRINCIPAL
# ==============================================================================
def main():
    global inicio_deteccao_suspeito, ultimo_print_suspeito

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

    if camera.read() is None:
        log.error(f"Sem frames da camera: {URL_VIDEO}")
        return

    log.info("Sistema ativo! Pressione Q para sair.")

    frame_count      = 0
    t_fps            = time.time()
    fps              = 0.0
    ultimo_resultado = []
    ultimo_reload    = datetime.now().strftime("%H:%M:%S")

    while True:
        frame_original = camera.read()

        if frame_original is None or frame_original.size == 0:
            tela = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(tela, "Aguardando camera...", (90, 240),
                        cv2.FONT_HERSHEY_DUPLEX, 1, (0,255,255), 2)
            cv2.imshow("Protego IA", tela)
            if cv2.waitKey(200) & 0xFF == ord('q'):
                break
            continue

        frame_count += 1

        if frame_count % 30 == 0:
            fps   = 30 / (time.time() - t_fps + 1e-6)
            t_fps = time.time()

        # Intervalo adaptativo: com rosto → cada 2 frames, sem rosto → cada 5
        intervalo = 2 if len(ultimo_resultado) > 0 else 5

        if frame_count % intervalo == 0:
            try:
                # ── InsightFace — detecção + embedding num único passo ──
                img_rgb = cv2.cvtColor(frame_original, cv2.COLOR_BGR2RGB)
                faces   = insight_app.get(img_rgb)

                agora            = time.time()
                tem_desconhecido = False
                resultado        = []

                for face in faces:
                    bbox = face.bbox.astype(int)
                    x1, y1, x2, y2 = bbox[0], bbox[1], bbox[2], bbox[3]

                    # Garante bbox dentro dos limites do frame
                    h_f, w_f = frame_original.shape[:2]
                    x1 = max(0, x1); y1 = max(0, y1)
                    x2 = min(w_f-1, x2); y2 = min(h_f-1, y2)

                    # Embedding ArcFace (512 dims) normalizado
                    emb  = face.embedding.astype(np.float32)
                    emb  = emb / (np.linalg.norm(emb) + 1e-6)

                    # Identificação
                    dados_alvo, confianca = identificar_rosto(emb)

                    # Anti-spoofing
                    spoofing = detectar_spoofing(frame_original, x1, y1, x2, y2)

                    # Prova de vida — EAR via landmarks InsightFace (5 pontos)
                    nome_key = dados_alvo["nome"] if dados_alvo else f"DESC_{x1}_{y1}"
                    kps      = face.kps  # 5 landmarks: olho_esq, olho_dir, nariz, boca_esq, boca_dir
                    if kps is not None and len(kps) >= 2:
                        # Distância entre os olhos como proxy — piscar reduz essa distância
                        dy = abs(float(kps[0][1]) - float(kps[1][1]))
                        if dy < 3.0:
                            pessoas_vivas[nome_key] = agora

                    is_vivo = (agora - pessoas_vivas.get(nome_key, 0)) < TEMPO_VALIDADE_PISCAR

                    # Emoção (cache — não bloqueia o loop)
                    emocao = obter_emocao(frame_original, x1, y1, x2, y2, nome_key)

                    # Alerta — só se não for spoofing
                    if dados_alvo and not spoofing:
                        nome = dados_alvo["nome"]
                        if (agora - ultimo_alerta.get(nome, 0)) > TEMPO_ESPERA_ALERTA:
                            ultimo_alerta[nome] = agora
                            log.info(f"ALVO: {nome} | {dados_alvo['perigo']} | {confianca:.0%} | Emocao: {emocao}")
                            if dados_alvo["mandados"]:
                                log.info(f"  MANDADO: {', '.join(dados_alvo['mandados'])}")
                            foto_path = salvar_captura_alvo(frame_original, nome)
                            threading.Thread(
                                target=alerta_sonoro,
                                args=(dados_alvo["perigo"], len(dados_alvo["mandados"]) > 0),
                                daemon=True
                            ).start()
                            publicar_alerta_mqtt(dados_alvo, confianca, is_vivo, emocao, foto_path)
                            registrar_deteccao(dados_alvo["id"], nome, confianca, is_vivo, foto_path)
                    elif not dados_alvo:
                        tem_desconhecido = True

                    resultado.append({
                        "box":       (x1, y1, x2, y2),
                        "dados":     dados_alvo,
                        "is_vivo":   is_vivo,
                        "confianca": confianca,
                        "spoofing":  spoofing,
                        "emocao":    emocao,
                    })

                ultimo_resultado = resultado

                # Captura suspeito
                if tem_desconhecido:
                    if inicio_deteccao_suspeito == 0:
                        inicio_deteccao_suspeito = agora
                    elif (agora - inicio_deteccao_suspeito) >= TEMPO_PARA_FOTO:
                        if (agora - ultimo_print_suspeito) > COOLDOWN_FOTO:
                            cinza = cv2.cvtColor(frame_original, cv2.COLOR_BGR2GRAY)
                            if cv2.Laplacian(cinza, cv2.CV_64F).var() >= 50:
                                ts    = datetime.now().strftime('%Y%m%d_%H%M%S')
                                fname = os.path.join(PASTA_SUSPEITOS, f"SUSPEITO_{ts}.jpg")
                                cv2.imwrite(fname, frame_original)
                                log.info(f"Suspeito capturado: {fname}")
                            ultimo_print_suspeito = agora
                else:
                    inicio_deteccao_suspeito = 0

            except Exception as e:
                log.error(f"Erro IA: {e}")

        # ── Desenha resultados ───────────────────────────────
        agora_draw = time.time()
        for res in ultimo_resultado:
            x1, y1, x2, y2 = res["box"]
            if res["dados"]:
                desenhar_ficha(frame_original, x1, y1, x2, y2,
                               res["dados"], res["is_vivo"],
                               res["confianca"], res["spoofing"], res["emocao"])
            else:
                desenhar_desconhecido(frame_original, x1, y1, x2, y2,
                                      res["emocao"], res["spoofing"],
                                      inicio_deteccao_suspeito, agora_draw)

        desenhar_hud(frame_original, len(ultimo_resultado), fps, ultimo_reload)
        cv2.imshow("Protego IA — Q para sair", frame_original)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # ── Encerramento ──────────────────────────────────────
    log.info("Encerrando sistema...")
    try:
        mqtt_client.publish(MQTT_TOPIC_STATUS, json.dumps({"status": "offline"}))
        mqtt_client.loop_stop()
    except Exception:
        pass
    camera.stop()
    cv2.destroyAllWindows()

# ==============================================================================
if __name__ == "__main__":
    main()