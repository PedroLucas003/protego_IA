import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/alerta.dart';
import '../models/camera_device.dart';
import '../models/deteccao.dart';
import '../models/pessoa_identificada.dart';
import '../services/api_service.dart';

class MonitorProvider extends ChangeNotifier {
  MonitorProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

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

  Future<void> iniciar() async {
    carregando = true;
    erro = null;
    notifyListeners();

    await refresh();
    _iniciarPolling();
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
      cameras = results[3] as List<CameraDevice>;

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

  /// Última detecção da câmera informada.
  Deteccao? ultimaDeteccaoCamera(String deviceId) {
    for (final d in deteccoes) {
      if (d.deviceId == deviceId) return d;
    }
    return deteccoes.isNotEmpty ? deteccoes.first : null;
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
