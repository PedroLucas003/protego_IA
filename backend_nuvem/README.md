# Backend Nuvem - Protego IA

## Objetivo
Implementar a plataforma de comunicação em nuvem do sistema usando MQTT.

## Componentes
- Broker MQTT com Eclipse Mosquitto
- Container Docker
- Subscriber Python para monitoramento
- Publisher Python de teste
- Estrutura de tópicos MQTT do projeto

## Estrutura de tópicos
- `policia/cam01/status`
- `policia/cam01/eventos`
- `policia/cam01/comandos`
- `policia/cam01/respostas`

## Como subir o broker
```bash
cd backend_nuvem
docker compose up -d