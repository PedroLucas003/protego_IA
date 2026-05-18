# Protego IA

Sistema de reconhecimento facial em tempo real para bodycam policial. Detecta e identifica alvos cadastrados, aplica anti-spoofing, análise de emoção e prova de vida, e publica alertas via MQTT e HTTP.

---

## Arquitetura

```
ESP32-CAM (stream MJPEG)
        ↓
reconhecimento_final.py
    ├── Thread Vídeo   → captura frames da câmera
    ├── Thread IA      → InsightFace ArcFace + DeepFace
    └── Thread Alerta  → MQTT + HTTP (api_client.py)
        ↓
PostgreSQL Railway      ← banco criminal (pessoas, mandados, detecções)
Backend API             ← recebe detecções em tempo real (em desenvolvimento)
```

---

## Funcionalidades

- Reconhecimento facial com InsightFace ArcFace (embeddings 512-dim)
- Tolerância de similaridade ajustada por nível de perigo (CRÍTICO → BAIXO)
- Anti-spoofing via variância Laplacian e saturação HSV
- Detecção de emoção em tempo real (DeepFace)
- Prova de vida por detecção de piscar (keypoints faciais)
- HUD em tempo real com ficha do alvo, barra de confiança e alertas sonoros
- Publicação de alertas via MQTT (QoS 1)
- Envio de detecções ao backend via HTTP (assíncrono, não bloqueia o vídeo)
- Recarregamento automático do banco a cada 5 minutos
- Captura automática de suspeitos desconhecidos

---

## Requisitos

- Python 3.10+
- ESP32-CAM com firmware de streaming MJPEG
- PostgreSQL acessível via `DB_URL`
- Broker MQTT acessível

Instale as dependências:

```bash
pip install -r requirements.txt
```

---

## Configuração

1. Copie o template de variáveis de ambiente:

```bash
cp .env.example .env
```

2. Preencha o `.env` com seus valores:

| Variável | Descrição |
|---|---|
| `ESP32_IP` | IP local do ESP32-CAM |
| `DB_URL` | Connection string do PostgreSQL |
| `MQTT_BROKER` | Endereço do broker MQTT |
| `MQTT_PORT` | Porta do broker (padrão: 1883) |
| `MQTT_TOPIC_ALERTA` | Tópico para publicar alertas |
| `API_URL` | URL do backend (quando disponível) |
| `DEVICE_ID` | Identificador da câmera (ex: `esp32cam-01`) |

---

## Executando

```bash
python reconhecimento_final.py
```

Pressione `Q` para encerrar.

---

## Cadastro de Alvos

Use o script de cadastro CLI para adicionar pessoas ao banco:

```bash
python cadastrar_alvo.py
```

---

## Estrutura do Projeto

```
protego-ia/
├── reconhecimento_final.py   # motor principal
├── api_client.py             # integração HTTP com o backend
├── cadastrar_alvo.py         # CLI de cadastro
├── requirements.txt          # dependências Python
├── .env.example              # template de variáveis de ambiente
├── .env                      # variáveis reais (NÃO commitar)
├── logs/                     # logs do sistema
├── capturas_alvos/           # fotos de alvos reconhecidos
├── suspeitos_detectados/     # fotos de desconhecidos
├── backend_nuvem/            # backend FastAPI (em desenvolvimento)
└── frontend_app/             # painel web (em desenvolvimento)
```

---

## Níveis de Perigo

| Nível | Tolerância de Similaridade | Comportamento |
|---|---|---|
| CRÍTICO | 0.30 | Alerta sonoro triplo + MQTT + API |
| ALTO | 0.35 | Alerta sonoro duplo + MQTT + API |
| MÉDIO | 0.40 | Alerta sonoro simples + MQTT + API |
| BAIXO | 0.45 | Registro silencioso + MQTT + API |

---

## Roadmap

- [x] Reconhecimento facial (InsightFace ArcFace)
- [x] Anti-spoofing
- [x] Detecção de emoção (DeepFace)
- [x] Prova de vida
- [x] Banco PostgreSQL + MQTT
- [x] Integração HTTP com backend
- [ ] Firmware ESP32 com TLS (Phase 2)
- [ ] Firmware ESP32 com ESP-IDF (Phase 3)
- [ ] mTLS no ESP32 (Phase 4)
- [ ] WebSocket seguro no firmware (Phase 5)
- [ ] Backend FastAPI
- [ ] Painel web de alertas