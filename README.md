
# Protego IA 

Sistema de reconhecimento facial em tempo real para bodycam policial, desenvolvido como projeto integrador na Nova Roma.

## Visão Geral

O Protego IA é um sistema embarcado + IA que captura o stream de vídeo de uma câmera ESP32-CAM, identifica suspeitos cadastrados em banco de dados policial e dispara alertas em tempo real via MQTT com segurança mTLS.

---

## Arquitetura
ESP32-CAM (stream MJPEG)
↓
Python InsightFace ArcFace (reconhecimento facial)
↓
PostgreSQL Railway (banco de alvos)
↓
MQTT mTLS EMQX Railway (alertas)
↓
FastAPI Railway (API backend)

---

## Stack

| Componente | Tecnologia |
|---|---|
| Hardware | ESP32-CAM AI Thinker |
| Firmware | Arduino IDE + PlatformIO |
| IA | Python 3.12 + InsightFace ArcFace buffalo_l |
| Emoção | DeepFace + TensorFlow |
| Broker | EMQX Railway (mTLS) |
| Backend | FastAPI Railway |
| Banco | PostgreSQL Railway |
| Protocolo | MQTT + mTLS + WSS |

---

## Estrutura do Repositório
protego_IA/
├── firmware/
│   ├── bodycam-arduino/     ← Arduino mTLS + stream + OTA
│   ├── phase3-esp-idf/      ← ESP-IDF + TLS com CA validado
│   └── phase5-wss-mtls/     ← ESP-IDF + WebSocket Secure + mTLS
├── ia_cameras/
│   ├── reconhecimento_final.py   ← Motor principal de reconhecimento
│   ├── api_client.py             ← Cliente HTTP para o backend
│   ├── cadastrar_alvo.py         ← Script de cadastro de alvos
│   ├── testar_banco.py           ← Teste de conexão com banco
│   └── requirements.txt
├── index.html               ← GitHub Pages
└── README.md

---

## Phases MQTT/TLS Concluídas

| Phase | Descrição | Responsável |
|---|---|---|
| Phase 1 | EMQX + TLS no Docker | Guilherme |
| Phase 2 | ESP32 Arduino + TLS básico | Pedro |
| Phase 3 | ESP-IDF + TLS com CA validado | Pedro |
| Phase 4 | mTLS — autenticação mútua | Pedro |
| Phase 5 | MQTT over WebSocket Secure | Pedro |
| Phase 6 | JITP — provisionamento automático | Guilherme |
| Phase 7 | ACL no EMQX | Guilherme |

---

## Módulo de IA

### Reconhecimento Facial

- **Modelo:** InsightFace `buffalo_l` com ArcFace ResNet50
- **Embedding:** 512 dimensões por rosto
- **Similaridade:** produto escalar (cosseno) normalizado L2
- **Limiares por nível de perigo:**
  - CRÍTICO → 70% mínimo
  - ALTO → 65%
  - MÉDIO → 60%
  - BAIXO → 55%

### Diferenciais

- **Anti-spoofing** — detecta foto impressa via Laplacian + saturação HSV
- **Prova de vida** — detecta piscar de olhos via keypoints faciais
- **Threading** — display fluido a 30fps enquanto IA processa em background
- **Recarregamento automático** — banco atualizado a cada 5 minutos
- **Análise de emoção** — DeepFace com cache de 2 segundos

### MQTT ClientIDs

- ESP32: `esp32_cam_01`
- Python: `protego_ia_01`

---

## Como Rodar

### Pré-requisitos

- Python 3.12
- `.env` configurado (ver `.env.example`)

### Instalar dependências

```bash
cd ia_cameras
python -m venv .venv
.venv\Scripts\activate
pip install dlib
pip install tf-keras
pip install insightface opencv-python deepface tensorflow paho-mqtt psycopg2-binary requests numpy Pillow python-dotenv
```

### Rodar o sistema

```bash
cd ia_cameras
python reconhecimento_final.py
```

### Cadastrar novo alvo

```bash
python cadastrar_alvo.py
```

---

## Variáveis de Ambiente

Cria um arquivo `.env` na pasta `ia_cameras/` com:

```env
ESP32_IP=<ip_da_camera>
DB_URL=postgresql://user:password@host:port/database?sslmode=require
MQTT_BROKER=<broker_host>
MQTT_PORT=38909
MQTT_TOPIC_ALERTA=reconhecimento/facial
API_URL=https://protegoia-production.up.railway.app
DEVICE_ID=camera_01
```

---

## Banco de Dados

```sql
CREATE TABLE pessoas (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255),
    cpf VARCHAR(14),
    rg VARCHAR(20),
    nivel_perigo VARCHAR(20),
    status VARCHAR(20),
    observacoes TEXT,
    encoding JSONB,
    timestamp TIMESTAMP
);

CREATE TABLE mandados (
    id SERIAL PRIMARY KEY,
    pessoa_id INTEGER REFERENCES pessoas(id),
    tipo VARCHAR(100),
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE historico_criminal (
    id SERIAL PRIMARY KEY,
    pessoa_id INTEGER REFERENCES pessoas(id),
    tipo_crime VARCHAR(100),
    artigo_lei VARCHAR(50)
);

CREATE TABLE deteccoes (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50),
    timestamp TIMESTAMP,
    nome VARCHAR(255),
    similaridade FLOAT,
    nivel_perigo VARCHAR(20),
    emocao VARCHAR(50),
    anti_spoofing BOOLEAN,
    prova_de_vida BOOLEAN,
    frame_b64 TEXT
);
```

---

## Endpoints FastAPI

| Método | Endpoint | Descrição |
|---|---|---|
| POST | `/heartbeat` | Status da câmera online |
| POST | `/deteccoes` | Registra detecção facial |
| POST | `/alertas` | Dispara alerta de alvo |

Backend: `https://protegoia-production.up.railway.app`

---

## Equipe

- **Pedro Lucas** — IA + Firmware ESP32
- **Guilherme Viana** — Cloud + EMQX + FastAPI + PostgreSQL

---
