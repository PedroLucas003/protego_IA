import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/alerta.dart';
import '../models/camera_device.dart';
import '../models/deteccao.dart';
import '../models/evento_camera.dart';
import '../models/pessoa_identificada.dart';
import '../services/api_service.dart';
import '../utils/device_id_utils.dart';

class MonitorProvider extends ChangeNotifier {
  MonitorProvider({ApiService? api, AmbienteApi? ambienteInicial})
      : _ambiente = ambienteInicial ?? AmbienteApi.railway,
        _api = api ?? ApiService(baseUrl: AppConfig.urlFor(ambienteInicial ?? AmbienteApi.railway));

  static const _prefsKeyAmbiente = 'ambiente_api';

  ApiService _api;
  AmbienteApi _ambiente;

  List<Deteccao> deteccoes = [];
  List<Alerta> alertas = [];
  List<PessoaIdentificada> pessoas = [];
  List<CameraDevice> cameras = [];

  bool apiOnline = false;
  bool carregando = true;
  String? erro;
  DateTime? ultimaAtualizacao;

  Timer? _pollTimer;

  int get totalAlertasCriticos =>
      alertas.where((a) => _isCritico(a.nivelPerigo)).length;

  int get camerasOnline => cameras.where((c) => c.online).length;

  bool _isCritico(String nivel) => nivel == 'CRITICO' || nivel == 'ALTO';

  AmbienteApi get ambiente => _ambiente;

  String get apiBaseUrl => AppConfig.urlFor(_ambiente);

  String get ambienteLabel => AppConfig.labelFor(_ambiente);

  Future<void> iniciar() async {
    carregando = true;
    erro = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _ambiente = AppConfig.ambienteFromStorage(prefs.getString(_prefsKeyAmbiente));
    _api = ApiService(baseUrl: apiBaseUrl);

    await refresh();
    _iniciarPolling();
  }

  Future<void> trocarAmbiente(AmbienteApi novo) async {
    if (_ambiente == novo) return;

    _ambiente = novo;
    _api = ApiService(baseUrl: apiBaseUrl);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyAmbiente, AppConfig.storageKeyFor(novo));

    carregando = true;
    erro = null;
    notifyListeners();

    await refresh();
  }

  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConfig.pollIntervalSeconds),
      (_) => refresh(silencioso: true),
    );
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
      ]);

      deteccoes = results[0] as List<Deteccao>;
      alertas = results[1] as List<Alerta>;
      pessoas = results[2] as List<PessoaIdentificada>;
      cameras = _aplicarStatusOnline(
        results[3] as List<CameraDevice>,
        deteccoes,
        alertas,
      );

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

  Future<PessoaIdentificada?> buscarPessoaCompleta(PessoaIdentificada pessoa) async {
    try {
      return await _api.buscarPessoa(pessoa.id);
    } catch (_) {
      return pessoa;
    }
  }

  List<CameraDevice> _aplicarStatusOnline(
    List<CameraDevice> lista,
    List<Deteccao> dets,
    List<Alerta> alts,
  ) {
    final agora = DateTime.now();
    return lista.map((c) {
      if (c.online) return c;
      if (_temAtividadeRecente(c.deviceId, dets, alts, agora)) {
        return CameraDevice(
          id: c.id,
          deviceId: c.deviceId,
          status: c.status,
          ultimoHeartbeat: c.ultimoHeartbeat,
          online: true,
        );
      }
      return c;
    }).toList();
  }

  bool _temAtividadeRecente(
    String deviceId,
    List<Deteccao> dets,
    List<Alerta> alts,
    DateTime agora,
  ) {
    for (final d in dets) {
      if (!DeviceIdUtils.mesmoDispositivo(d.deviceId, deviceId)) continue;
      final dt = _parseTs(d.timestamp);
      if (dt != null &&
          agora.difference(dt).inMinutes <= AppConfig.cameraAtividadeMinutes) {
        return true;
      }
    }
    for (final a in alts) {
      if (!DeviceIdUtils.mesmoDispositivo(a.deviceId, deviceId)) continue;
      final dt = _parseTs(a.timestamp);
      if (dt != null &&
          agora.difference(dt).inMinutes <= AppConfig.cameraAtividadeMinutes) {
        return true;
      }
    }
    return false;
  }

  DateTime? _parseTs(String raw) {
    try {
      var s = raw.trim();
      if (!s.endsWith('Z') && !s.contains('+') && s.contains('T')) {
        s = '${s}Z';
      }
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  CameraDevice? cameraPorId(String deviceId) {
    for (final c in cameras) {
      if (DeviceIdUtils.mesmoDispositivo(c.deviceId, deviceId)) return c;
    }
    return null;
  }

  /// Log unificado de alertas e detecções da câmera, mais recentes primeiro.
  List<EventoCamera> logCamera(String deviceId) {
    final eventos = <EventoCamera>[];

    for (final a in alertas) {
      if (DeviceIdUtils.mesmoDispositivo(a.deviceId, deviceId)) {
        eventos.add(EventoCamera.fromAlerta(enriquecerAlerta(a)));
      }
    }
    for (final d in deteccoes) {
      if (DeviceIdUtils.mesmoDispositivo(d.deviceId, deviceId)) {
        eventos.add(EventoCamera.fromDeteccao(d));
      }
    }

    eventos.sort((a, b) {
      final da = a.dateTime;
      final db = b.dateTime;
      if (da == null && db == null) return b.id.compareTo(a.id);
      if (da == null) return 1;
      if (db == null) return -1;
      final cmp = db.compareTo(da);
      return cmp != 0 ? cmp : b.id.compareTo(a.id);
    });

    return eventos;
  }

  /// Última detecção da câmera informada.
  Deteccao? ultimaDeteccaoCamera(String deviceId) {
    for (final d in deteccoes) {
      if (DeviceIdUtils.mesmoDispositivo(d.deviceId, deviceId)) return d;
    }
    return null;
  }

  /// Busca suspeito cadastrado pelo nome da detecção.
  Future<PessoaIdentificada?> resolverSuspeito(Deteccao deteccao) async {
    final nome = deteccao.nome.trim().toLowerCase();
    if (nome.isEmpty) return null;

    for (final p in pessoas) {
      if (p.nome.trim().toLowerCase() == nome) {
        final completa = await buscarPessoaCompleta(p);
        return PessoaIdentificada(
          id: completa?.id ?? p.id,
          timestamp: deteccao.timestamp,
          nome: completa?.nome ?? p.nome,
          cpf: completa?.cpf ?? p.cpf,
          rg: completa?.rg ?? p.rg,
          nivelPerigo: completa?.nivelPerigo ?? p.nivelPerigo,
          status: completa?.status ?? p.status,
          mandados: completa?.mandados ?? p.mandados,
          crimes: completa?.crimes ?? p.crimes,
          artigos: completa?.artigos ?? p.artigos,
          observacoes: completa?.observacoes ?? p.observacoes,
          confianca: deteccao.similaridadePercent > 0
              ? deteccao.similaridadePercent
              : (completa?.confianca ?? p.confianca),
          provaDeVida: deteccao.provaDeVida,
          temMandado: completa?.temMandado ?? p.temMandado,
          emocao: deteccao.emocao ?? completa?.emocao ?? p.emocao,
        );
      }
    }
    return null;
  }

  PessoaIdentificada? buscarSuspeitoPorNome(String nome) {
    final alvo = nome.trim().toLowerCase();
    for (final p in pessoas) {
      if (p.nome.trim().toLowerCase() == alvo) return p;
    }
    return null;
  }

  /// Completa dados do alerta com registro de pessoa/detecção do mesmo nome.
  Alerta enriquecerAlerta(Alerta alerta) {
    if (alerta.cpf != null) return alerta;

    for (final p in pessoas) {
      if (p.nome == alerta.nome) {
        return Alerta(
          id: alerta.id,
          deviceId: alerta.deviceId,
          timestamp: alerta.timestamp,
          nome: alerta.nome,
          nivelPerigo: alerta.nivelPerigo,
          mensagem: alerta.mensagem,
          cpf: p.cpf,
          confianca: p.confianca,
          emocao: p.emocao,
          temMandado: p.temMandado,
          status: p.status,
          mandados: p.mandados,
          crimes: p.crimes,
          artigos: p.artigos,
          observacoes: p.observacoes,
        );
      }
    }
    return alerta;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
