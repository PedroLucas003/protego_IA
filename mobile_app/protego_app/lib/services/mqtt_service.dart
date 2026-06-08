import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/app_config.dart';
import '../models/alerta.dart';
import '../models/pessoa_identificada.dart';
import 'mqtt_tls_context.dart';

enum ProtegoMqttState { disconnected, connecting, connected, error }

class MqttService {
  MqttServerClient? _client;
  final _eventController = StreamController<PessoaIdentificada>.broadcast();
  final _alertaController = StreamController<Alerta>.broadcast();
  final _stateController = StreamController<ProtegoMqttState>.broadcast();

  ProtegoMqttState _state = ProtegoMqttState.disconnected;
  String? _lastError;

  Stream<PessoaIdentificada> get eventos => _eventController.stream;
  Stream<Alerta> get alertas => _alertaController.stream;
  Stream<ProtegoMqttState> get connectionState => _stateController.stream;
  ProtegoMqttState get state => _state;
  String? get lastError => _lastError;

  Future<void> connect() async {
    if (_state == ProtegoMqttState.connecting ||
        _state == ProtegoMqttState.connected) {
      return;
    }
    _setState(ProtegoMqttState.connecting);
    _lastError = null;

    final clientId =
        'protego_mobile_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(
      AppConfig.mqttBroker,
      clientId,
      AppConfig.mqttPort,
    );
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = (_) {};

    if (AppConfig.mqttUseTls) {
      final context = await MqttTlsContext.load();
      if (context == null) {
        _lastError =
            'Certificados mTLS ausentes em assets/certs/ (ca.crt, client.crt, client.key)';
        _setState(ProtegoMqttState.error);
        throw Exception(_lastError);
      }
      _client!.secure = true;
      _client!.securityContext = context;
    }

    try {
      _client!.connect();
      for (var i = 0; i < 24; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_client!.connectionStatus?.state ==
            MqttConnectionState.connected) {
          return;
        }
        final status = _client!.connectionStatus;
        if (status?.state == MqttConnectionState.faulted) {
          _lastError = status?.returnCode?.toString() ?? 'Conexão recusada';
          break;
        }
      }
      throw Exception(_lastError ?? 'Timeout ao conectar MQTT');
    } catch (e) {
      _lastError ??= e.toString();
      _setState(ProtegoMqttState.error);
      rethrow;
    }
  }

  void _onConnected() {
    _setState(ProtegoMqttState.connected);
    _client?.subscribe(AppConfig.mqttTopicAlerta, MqttQos.atLeastOnce);
    _client?.updates?.listen(_handleMessages);
  }

  void _onDisconnected() {
    _setState(ProtegoMqttState.disconnected);
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    if (messages == null) return;
    for (final msg in messages) {
      final payload = msg.payload as MqttPublishMessage;
      final text =
          MqttPublishPayload.bytesToStringAsString(payload.payload.message);
      try {
        final json = jsonDecode(text) as Map<String, dynamic>;
        final id = DateTime.now().millisecondsSinceEpoch;
        final pessoa = PessoaIdentificada.fromJson({
          'id': id,
          'timestamp': json['timestamp'] ?? DateTime.now().toIso8601String(),
          'nome': json['nome'],
          'cpf': json['cpf'],
          'rg': json['rg'],
          'nivel_perigo': json['nivel_perigo'],
          'status': json['status'],
          'mandados': json['mandados'],
          'crimes': json['crimes'],
          'artigos': json['artigos'],
          'observacoes': json['observacoes'],
          'confianca': json['confianca'],
          'prova_de_vida': json['prova_de_vida'],
          'tem_mandado': json['tem_mandado'],
          'emocao': json['emocao'],
          'foto_url': json['foto_url'],
          'frame_b64': json['frame_b64'],
        });
        _eventController.add(pessoa);

        final alerta = Alerta.fromJson({
          'id': id,
          'device_id': json['camera_ip'] ?? json['device_id'] ?? '',
          'timestamp': json['timestamp'] ?? DateTime.now().toIso8601String(),
          'nome': json['nome'],
          'nivel_perigo': json['nivel_perigo'],
          'mensagem': json['status'] != null
              ? '${json['status']} identificado'
              : 'Reconhecimento facial',
          'frame_b64': json['frame_b64'],
          'foto_url': json['foto_url'],
          'cpf': json['cpf'],
          'confianca': json['confianca'],
          'emocao': json['emocao'],
          'tem_mandado': json['tem_mandado'],
          'status': json['status'],
          'mandados': json['mandados'],
          'crimes': json['crimes'],
          'artigos': json['artigos'],
          'observacoes': json['observacoes'],
        });
        _alertaController.add(alerta);
      } catch (_) {
        // payload inválido — ignorar
      }
    }
  }

  void _setState(ProtegoMqttState s) {
    _state = s;
    _stateController.add(s);
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _setState(ProtegoMqttState.disconnected);
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _alertaController.close();
    _stateController.close();
  }
}
