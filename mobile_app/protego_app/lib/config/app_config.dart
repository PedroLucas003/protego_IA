import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Ambiente da API consumida pelo app.
enum AmbienteApi { railway, local }

/// Configuração central do app.
class AppConfig {
  static const String railwayApiUrl =
      'https://protegoia-production.up.railway.app';

  /// Porta padrão do FastAPI local (docker compose / uvicorn).
  static const int localApiPort = 8000;

  /// Intervalo de polling da API (segundos).
  static const int pollIntervalSeconds = 4;

  /// Sem heartbeat neste intervalo → offline (salvo atividade recente).
  static const int cameraOfflineMinutes = 5;

  /// Detecção/alerta recente também marca câmera como online.
  static const int cameraAtividadeMinutes = 15;

  /// URL da API local conforme a plataforma.
  /// Android emulador: 10.0.2.2 · demais: localhost.
  /// Em celular físico, altere para o IP da máquina na rede (ex: 192.168.0.10).
  static String get localApiUrl {
    if (kIsWeb) return 'http://localhost:$localApiPort';
    if (Platform.isAndroid) return 'http://10.0.2.2:$localApiPort';
    return 'http://localhost:$localApiPort';
  }

  static String urlFor(AmbienteApi ambiente) {
    return ambiente == AmbienteApi.railway ? railwayApiUrl : localApiUrl;
  }

  static String labelFor(AmbienteApi ambiente) {
    return ambiente == AmbienteApi.railway ? 'Railway' : 'Local';
  }

  static AmbienteApi ambienteFromStorage(String? value) {
    return value == 'local' ? AmbienteApi.local : AmbienteApi.railway;
  }

  static String storageKeyFor(AmbienteApi ambiente) {
    return ambiente == AmbienteApi.local ? 'local' : 'railway';
  }
}
