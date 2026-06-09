import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/alerta.dart';
import '../models/camera_device.dart';
import '../models/deteccao.dart';
import '../models/pessoa_identificada.dart';

class ApiService {
  ApiService({String? baseUrl})
      : _baseUrl = baseUrl ?? AppConfig.urlFor(AmbienteApi.railway);

  final String _baseUrl;

  Future<bool> healthCheck() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return false;
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return body['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<List<Deteccao>> listarDeteccoes() async {
    final r = await http
        .get(Uri.parse('$_baseUrl/deteccoes'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw Exception('Erro detecções: ${r.statusCode}');
    }
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map((e) => Deteccao.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<List<Alerta>> listarAlertas() async {
    final r = await http
        .get(Uri.parse('$_baseUrl/alertas'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw Exception('Erro alertas: ${r.statusCode}');
    }
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map((e) => Alerta.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<List<PessoaIdentificada>> listarPessoas() async {
    final r = await http
        .get(Uri.parse('$_baseUrl/pessoas'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw Exception('Erro pessoas: ${r.statusCode}');
    }
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map((e) => PessoaIdentificada.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<PessoaIdentificada?> buscarPessoa(int id) async {
    final r = await http
        .get(Uri.parse('$_baseUrl/pessoas/$id'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw Exception('Erro pessoa: ${r.statusCode}');
    }
    return PessoaIdentificada.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  }

  Future<List<CameraDevice>> listarCameras() async {
    final results = await Future.wait([
      http.get(Uri.parse('$_baseUrl/devices')).timeout(const Duration(seconds: 15)),
      http.get(Uri.parse('$_baseUrl/heartbeat')).timeout(const Duration(seconds: 15)),
    ]);

    if (results[0].statusCode != 200) {
      throw Exception('Erro devices: ${results[0].statusCode}');
    }

    final devices = (jsonDecode(results[0].body) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    final heartbeats = results[1].statusCode == 200
        ? (jsonDecode(results[1].body) as List<dynamic>)
            .map((e) => HeartbeatEntry.fromJson(e as Map<String, dynamic>))
            .toList()
        : <HeartbeatEntry>[];

    final ultimoPorDevice = <String, HeartbeatEntry>{};
    for (final hb in heartbeats) {
      final atual = ultimoPorDevice[hb.deviceId];
      if (atual == null || hb.id > atual.id) {
        ultimoPorDevice[hb.deviceId] = hb;
      }
    }

    final agora = DateTime.now();
    return devices.map((d) {
      final deviceId = d['device_id'] as String? ?? '';
      final hb = ultimoPorDevice[deviceId];
      final dt = hb?.dateTime;
      final heartbeatRecente = dt != null &&
          agora.difference(dt).inMinutes <= AppConfig.cameraOfflineMinutes;
      final statusOnline =
          hb?.status.toUpperCase() == 'ONLINE' && heartbeatRecente;
      return CameraDevice.fromJson(
        d,
        ultimoHeartbeat: dt,
        online: heartbeatRecente || statusOnline,
      );
    }).toList();
  }
}
