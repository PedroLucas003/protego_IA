# Tópicos MQTT - Projeto Protego IA

## Dispositivo padrão
- device_id: cam01

## Tópicos definidos

### 1. policia/cam01/status
Usado para informar status do dispositivo.

Exemplos:
- online
- offline
- wifi_conectado

### 2. policia/cam01/eventos
Usado para informar eventos do dispositivo.

Exemplos:
- captura_iniciada
- rosto_detectado
- imagem_enviada

### 3. policia/cam01/comandos
Usado para enviar comandos ao dispositivo.

Exemplos:
- capturar
- reiniciar
- ping

### 4. policia/cam01/respostas
Usado para respostas do dispositivo.

Exemplos:
- comando_recebido
- captura_concluida
- erro