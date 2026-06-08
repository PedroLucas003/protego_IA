/// Configuração central do app — altere o IP apenas para API local.
class AppConfig {
  static const String apiBaseUrl =
      'https://protegoia-production.up.railway.app';

  /// Broker EMQX no Railway (mTLS — sem user/pass).
  static const String mqttBroker = 'kodama.proxy.rlwy.net';
  static const int mqttPort = 38909;
  static const String mqttTopicAlerta = 'reconhecimento/facial';

  /// mTLS: coloque ca.crt, client.crt e client.key em assets/certs/
  static const bool mqttUseTls = true;
  static const String mqttCaCertAsset = 'assets/certs/ca.crt';
  static const String mqttClientCertAsset = 'assets/certs/client.crt';
  static const String mqttClientKeyAsset = 'assets/certs/client.key';

  /// Intervalo de polling da API (segundos).
  static const int pollIntervalSeconds = 3;
}
