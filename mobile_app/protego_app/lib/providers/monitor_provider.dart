import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/alerta.dart';
import '../models/camera_device.dart';
import '../models/deteccao.dart';
import '../models/mqtt_evento.dart';
import '../models/pessoa_identificada.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';

class MonitorProvider extends ChangeNotifier {
  MonitorProvider({ApiService? api, MqttService? mqtt})
      : _api = api ?? ApiService(),
        _mqtt = mqtt ?? MqttService();

  final ApiService _api;
  final MqttService _mqtt;

  List<Deteccao> deteccoes = [];
  List<Alerta> alertas = [];
  List<PessoaIdentificada> pessoas = [];
  List<CameraDevice> cameras = [];
  List<MqttEvento> eventosAoVivo = [];

  bool apiOnline = false;
  ProtegoMqttState mqttState = ProtegoMqttState.disconnected;
  String? mqttErro;
  bool carregando = true;
  String? erro;
  DateTime? ultimaAtualizacao;

  Timer? _pollTimer;
  StreamSubscription<PessoaIdentificada>? _mqttSub;
  StreamSubscription<Alerta>? _mqttAlertaSub;
  StreamSubscription<ProtegoMqttState>? _mqttStateSub;

  int get totalAlertasCriticos =>
      alertas.where((a) => _isCritico(a.nivelPerigo)).length;

  int get camerasOnline => cameras.where((c) => c.online).length;

  bool _isCritico(String nivel) => nivel == 'CRITICO' || nivel == 'ALTO';

  Future<void> iniciar() async {
    carregando = true;
    erro = null;
    notifyListeners();

    await refresh();
    _iniciarPolling();
    await _iniciarMqtt();
  }

  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConfig.pollIntervalSeconds),
      (_) => refresh(silencioso: true),
    );
  }

  Future<void> _iniciarMqtt() async {
    _mqttStateSub?.cancel();
    _mqttStateSub = _mqtt.connectionState.listen((s) {
      mqttState = s;
      notifyListeners();
    });

    _mqttSub?.cancel();
    _mqttSub = _mqtt.eventos.listen(_onPessoaMqtt);

    _mqttAlertaSub?.cancel();
    _mqttAlertaSub = _mqtt.alertas.listen(_onAlertaMqtt);

    try {
      await _mqtt.connect();
      mqttErro = null;
    } catch (e) {
      mqttState = ProtegoMqttState.error;
      mqttErro = _mqtt.lastError ?? e.toString();
      notifyListeners();
    }
  }

  void _onPessoaMqtt(PessoaIdentificada pessoa) {
    pessoas = [pessoa, ...pessoas];
    if (pessoas.length > 50) pessoas = pessoas.take(50).toList();
    ultimaAtualizacao = DateTime.now();
    notifyListeners();
  }

  void _onAlertaMqtt(Alerta alerta) {
    alertas = [alerta, ...alertas];
    if (alertas.length > 50) alertas = alertas.take(50).toList();
    if (alerta.toPessoa() != null) {
      pessoas = [alerta.toPessoa()!, ...pessoas];
      if (pessoas.length > 50) pessoas = pessoas.take(50).toList();
    }
    ultimaAtualizacao = DateTime.now();
    notifyListeners();
  }

  Future<void> refresh({bool silencioso = false}) async {
    if (!silencioso) {
      carregando = true;
      notifyListeners();
    }

    try {
      apiOnline = await _api.healthCheck();
      final results = await Future.wait([
        _api.listarDeteccoes(),
        _api.listarAlertas(),
        _api.listarPessoas(),
        _api.listarCameras(),
        _api.listarMqttEventos(),
      ]);

      final apiDeteccoes = results[0] as List<Deteccao>;
      final apiAlertas = results[1] as List<Alerta>;
      final apiPessoas = results[2] as List<PessoaIdentificada>;
      cameras = results[3] as List<CameraDevice>;
      eventosAoVivo = results[4] as List<MqttEvento>;

      deteccoes = _mesclarDeteccoes(apiDeteccoes, eventosAoVivo);
      alertas = _mesclarAlertas(apiAlertas, eventosAoVivo);
      _mesclarPessoas([...apiPessoas, ...eventosAoVivo.map((e) => e.toPessoa())]);

      erro = null;
      ultimaAtualizacao = DateTime.now();
    } catch (e) {
      erro = e.toString();
      apiOnline = false;
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  List<Deteccao> _mesclarDeteccoes(
    List<Deteccao> daApi,
    List<MqttEvento> eventos,
  ) {
    final map = <int, Deteccao>{};
    for (final d in daApi) {
      map[d.id] = d;
    }
    for (final e in eventos) {
      if (e.nome.isEmpty) continue;
      final det = e.toDeteccao();
      final existente = map[det.id];
      if (existente == null || det.imagemRosto != null) {
        map[det.id] = Deteccao(
          id: det.id,
          deviceId: det.deviceId.isNotEmpty ? det.deviceId : existente?.deviceId ?? '',
          timestamp: det.timestamp,
          nome: det.nome,
          similaridade: det.similaridade > 0 ? det.similaridade : (existente?.similaridade ?? 0),
          nivelPerigo: det.nivelPerigo,
          emocao: det.emocao ?? existente?.emocao,
          antiSpoofing: det.antiSpoofing,
          provaDeVida: det.provaDeVida,
          frameB64: det.frameB64 ?? existente?.frameB64,
          fotoUrl: det.fotoUrl ?? existente?.fotoUrl,
        );
      }
    }
    return map.values.toList()..sort((a, b) => b.id.compareTo(a.id));
  }

  List<Alerta> _mesclarAlertas(List<Alerta> daApi, List<MqttEvento> eventos) {
    final map = <int, Alerta>{};
    for (final a in daApi) {
      map[a.id] = a;
    }
    for (final e in eventos) {
      if (e.nome.isEmpty) continue;
      final alerta = e.toAlerta();
      final existente = map[alerta.id];
      map[alerta.id] = Alerta(
        id: alerta.id,
        deviceId: alerta.deviceId.isNotEmpty ? alerta.deviceId : existente?.deviceId ?? '',
        timestamp: alerta.timestamp,
        nome: alerta.nome,
        nivelPerigo: alerta.nivelPerigo,
        mensagem: alerta.mensagem ?? existente?.mensagem,
        fotoUrl: alerta.fotoUrl ?? existente?.fotoUrl,
        frameB64: alerta.frameB64 ?? existente?.frameB64,
        cpf: alerta.cpf ?? existente?.cpf,
        confianca: alerta.confianca ?? existente?.confianca,
        emocao: alerta.emocao ?? existente?.emocao,
        temMandado: alerta.temMandado ?? existente?.temMandado,
        status: alerta.status ?? existente?.status,
        mandados: alerta.mandados ?? existente?.mandados,
        crimes: alerta.crimes ?? existente?.crimes,
        artigos: alerta.artigos ?? existente?.artigos,
        observacoes: alerta.observacoes ?? existente?.observacoes,
      );
    }
    return map.values.toList()..sort((a, b) => b.id.compareTo(a.id));
  }

  void _mesclarPessoas(List<PessoaIdentificada> novas) {
    final porChave = <String, PessoaIdentificada>{};
    for (final p in [...pessoas, ...novas]) {
      final chave = '${p.nome}_${p.timestamp}';
      final existente = porChave[chave];
      if (existente == null || p.imagemRosto != null) {
        porChave[chave] = PessoaIdentificada(
          id: p.id,
          timestamp: p.timestamp,
          nome: p.nome,
          cpf: p.cpf.isNotEmpty ? p.cpf : (existente?.cpf ?? ''),
          rg: p.rg.isNotEmpty ? p.rg : (existente?.rg ?? ''),
          nivelPerigo: p.nivelPerigo,
          status: p.status.isNotEmpty ? p.status : (existente?.status ?? ''),
          mandados: p.mandados.isNotEmpty ? p.mandados : (existente?.mandados ?? ''),
          crimes: p.crimes.isNotEmpty ? p.crimes : (existente?.crimes ?? ''),
          artigos: p.artigos.isNotEmpty ? p.artigos : (existente?.artigos ?? ''),
          observacoes: p.observacoes ?? existente?.observacoes,
          confianca: p.confianca > 0 ? p.confianca : (existente?.confianca ?? 0),
          provaDeVida: p.provaDeVida,
          temMandado: p.temMandado,
          emocao: p.emocao ?? existente?.emocao,
          fotoUrl: p.fotoUrl ?? existente?.fotoUrl,
          frameB64: p.frameB64 ?? existente?.frameB64,
        );
      }
    }
    pessoas = porChave.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Enriquece alerta com imagem de detecção/pessoa correspondente.
  Alerta enriquecerAlerta(Alerta alerta) {
    if (alerta.frameB64 != null || FaceImageHelper.hasImage(alerta.fotoUrl)) {
      return alerta;
    }
    final det = _findDeteccao(alerta.nome);
    if (det?.imagemRosto != null) {
      return Alerta(
        id: alerta.id,
        deviceId: alerta.deviceId,
        timestamp: alerta.timestamp,
        nome: alerta.nome,
        nivelPerigo: alerta.nivelPerigo,
        mensagem: alerta.mensagem,
        fotoUrl: det!.fotoUrl,
        frameB64: det.frameB64,
        cpf: alerta.cpf,
        confianca: alerta.confianca,
        emocao: alerta.emocao ?? det.emocao,
        temMandado: alerta.temMandado,
        status: alerta.status,
        mandados: alerta.mandados,
        crimes: alerta.crimes,
        artigos: alerta.artigos,
        observacoes: alerta.observacoes,
      );
    }
    final pessoa = _findPessoa(alerta.nome);
    if (pessoa?.imagemRosto != null) {
      return Alerta(
        id: alerta.id,
        deviceId: alerta.deviceId,
        timestamp: alerta.timestamp,
        nome: alerta.nome,
        nivelPerigo: alerta.nivelPerigo,
        mensagem: alerta.mensagem,
        fotoUrl: pessoa!.fotoUrl,
        frameB64: pessoa.frameB64,
        cpf: alerta.cpf ?? pessoa.cpf,
        confianca: alerta.confianca ?? pessoa.confianca,
        emocao: alerta.emocao ?? pessoa.emocao,
        temMandado: alerta.temMandado ?? pessoa.temMandado,
        status: alerta.status ?? pessoa.status,
        mandados: alerta.mandados ?? pessoa.mandados,
        crimes: alerta.crimes ?? pessoa.crimes,
        artigos: alerta.artigos ?? pessoa.artigos,
        observacoes: alerta.observacoes ?? pessoa.observacoes,
      );
    }
    return alerta;
  }

  Deteccao? _findDeteccao(String nome) {
    for (final d in deteccoes) {
      if (d.nome == nome) return d;
    }
    return null;
  }

  PessoaIdentificada? _findPessoa(String nome) {
    for (final p in pessoas) {
      if (p.nome == nome) return p;
    }
    return null;
  }

  Future<PessoaIdentificada?> buscarPessoaCompleta(PessoaIdentificada pessoa) async {
    try {
      final remota = await _api.buscarPessoa(pessoa.id);
      if (remota != null) {
        return PessoaIdentificada(
          id: remota.id,
          timestamp: remota.timestamp.isNotEmpty ? remota.timestamp : pessoa.timestamp,
          nome: remota.nome,
          cpf: remota.cpf,
          rg: remota.rg,
          nivelPerigo: remota.nivelPerigo,
          status: remota.status,
          mandados: remota.mandados,
          crimes: remota.crimes,
          artigos: remota.artigos,
          observacoes: remota.observacoes,
          confianca: remota.confianca,
          provaDeVida: remota.provaDeVida,
          temMandado: remota.temMandado,
          emocao: remota.emocao ?? pessoa.emocao,
          fotoUrl: remota.fotoUrl ?? pessoa.fotoUrl,
          frameB64: remota.frameB64 ?? pessoa.frameB64,
        );
      }
    } catch (_) {}
    return pessoa;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mqttSub?.cancel();
    _mqttAlertaSub?.cancel();
    _mqttStateSub?.cancel();
    _mqtt.dispose();
    super.dispose();
  }
}

/// Evita import circular com face_image.dart no provider.
class FaceImageHelper {
  static bool hasImage(String? url) =>
      url != null &&
      url.isNotEmpty &&
      (url.startsWith('http://') || url.startsWith('https://'));
}
