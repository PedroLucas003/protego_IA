# Protego IA — App Mobile de Monitoramento

Aplicativo Flutter para monitoramento em tempo real do sistema **Protego IA** (reconhecimento facial em bodycam).

## Funcionalidades (conforme documento de status)

| Recurso | Implementação no app |
|--------|---------------------|
| Reconhecimento facial (InsightFace) | Aba **Identificados** — nome, CPF, RG, confiança |
| Anti-spoofing / prova de vida | Chips na tela de detalhe |
| Detecção de emoção | Exibida em detecções e identificações |
| Alertas MQTT (ALTO/CRÍTICO) | Aba **Alertas** + push via MQTT |
| Níveis de perigo | Badges coloridos (CRÍTICO → BAIXO) |
| Mandados / crimes / artigos | Tela de detalhe da pessoa |
| Backend FastAPI (Railway) | Polling a cada 4s em `/deteccoes`, `/alertas`, `/pessoas` |
| Tempo real MQTT | Tópico `reconhecimento/facial` |

## API de produção

```
https://protegoia-production.up.railway.app
```

Altere em `lib/config/app_config.dart` se usar outro ambiente.

## Como executar

```bash
cd mobile_app/protego_app
flutter pub get
flutter run
```

**Emulador Android:** a API HTTPS já funciona sem IP local.

**MQTT:** broker `crossover.proxy.rlwy.net:28372` (configurado no `.env` do projeto IA). O ícone de antena no AppBar indica conexão MQTT; se falhar, o app continua via API REST.

## Estrutura

```
lib/
  config/app_config.dart      # URLs e MQTT
  models/                     # Deteccao, Alerta, PessoaIdentificada
  services/                   # ApiService, MqttService
  providers/monitor_provider.dart
  screens/home_screen.dart    # 3 abas + status
  screens/detalhe_pessoa_screen.dart
```

## Próximos passos sugeridos

- Notificações push locais ao receber alerta CRÍTICO via MQTT
- Exibir `frame_b64` quando o backend enviar captura
- Autenticação mTLS para MQTT em produção (Phase 4/7 do projeto)
