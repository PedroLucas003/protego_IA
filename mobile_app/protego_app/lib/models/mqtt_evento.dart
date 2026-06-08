import 'dart:convert';
import 'pessoa_identificada.dart';
import 'alerta.dart';
import 'deteccao.dart';

class MqttEvento {
  final int id;
  final String topic;
  final Map<String, dynamic> payload;
  final DateTime recebidoEm;

  MqttEvento({
    required this.id,
    required this.topic,
    required this.payload,
    required this.recebidoEm,
  });

  factory MqttEvento.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> payload;
    final raw = json['payload'];
    if (raw is String) {
      try {
        payload = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        payload = {'raw': raw};
      }
    } else if (raw is Map<String, dynamic>) {
      payload = raw;
    } else {
      payload = {};
    }

    return MqttEvento(
      id: json['id'] as int,
      topic: json['topic'] as String? ?? '',
      payload: payload,
      recebidoEm: DateTime.tryParse(json['recebido_em'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get nome => payload['nome'] as String? ?? '';
  String? get frameB64 => payload['frame_b64'] as String?;
  String? get fotoUrl => payload['foto_url'] as String?;
  String get timestamp =>
      payload['timestamp'] as String? ?? recebidoEm.toIso8601String();
  String get nivelPerigo =>
      (payload['nivel_perigo'] as String? ?? 'MEDIO').toUpperCase();

  PessoaIdentificada toPessoa() {
    return PessoaIdentificada.fromJson({
      'id': id,
      ...payload,
      'foto_url': fotoUrl,
      'frame_b64': frameB64,
    });
  }

  Alerta toAlerta() {
    return Alerta.fromJson({
      'id': id,
      'device_id': payload['camera_ip'] ?? payload['device_id'] ?? '',
      'timestamp': timestamp,
      'nome': nome,
      'nivel_perigo': nivelPerigo,
      'mensagem': _mensagemAlerta(),
      'frame_b64': frameB64,
      'foto_url': fotoUrl,
      'cpf': payload['cpf'],
      'confianca': payload['confianca'],
      'emocao': payload['emocao'],
      'tem_mandado': payload['tem_mandado'],
      'status': payload['status'],
      'mandados': payload['mandados'],
      'crimes': payload['crimes'],
      'artigos': payload['artigos'],
      'observacoes': payload['observacoes'],
    });
  }

  Deteccao toDeteccao() {
    final conf = (payload['confianca'] as num?)?.toDouble() ?? 0;
    return Deteccao.fromJson({
      'id': id,
      'device_id': payload['camera_ip'] ?? payload['device_id'] ?? '',
      'timestamp': timestamp,
      'nome': nome,
      'similaridade': conf > 1 ? conf / 100 : conf,
      'nivel_perigo': nivelPerigo,
      'emocao': payload['emocao'],
      'anti_spoofing': payload['anti_spoofing'] ?? true,
      'prova_de_vida': payload['prova_de_vida'] ?? false,
      'frame_b64': frameB64,
      'foto_url': fotoUrl,
    });
  }

  String _mensagemAlerta() {
    final status = payload['status'] as String?;
    if (status != null && status.isNotEmpty) {
      return '$status identificado';
    }
    return 'Reconhecimento facial';
  }
}
