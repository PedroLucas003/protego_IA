import 'dart:io';
import 'package:flutter/services.dart';
import '../config/app_config.dart';

/// Carrega certificados mTLS do bundle para conexão com o broker EMQX.
class MqttTlsContext {
  static SecurityContext? _cached;

  static Future<SecurityContext?> load() async {
    if (_cached != null) return _cached;
    if (!AppConfig.mqttUseTls) return null;

    try {
      final context = SecurityContext(withTrustedRoots: false);

      final caBytes = await rootBundle.load(AppConfig.mqttCaCertAsset);
      context.setTrustedCertificatesBytes(caBytes.buffer.asUint8List());

      final certBytes = await rootBundle.load(AppConfig.mqttClientCertAsset);
      context.useCertificateChainBytes(certBytes.buffer.asUint8List());

      final keyBytes = await rootBundle.load(AppConfig.mqttClientKeyAsset);
      context.usePrivateKeyBytes(keyBytes.buffer.asUint8List());

      _cached = context;
      return context;
    } catch (_) {
      return null;
    }
  }
}
