import 'pessoa_identificada.dart';

class Alerta {
  final int id;
  final String deviceId;
  final String timestamp;
  final String nome;
  final String nivelPerigo;
  final String? mensagem;
  final String? fotoUrl;
  final String? frameB64;
  final String? cpf;
  final double? confianca;
  final String? emocao;
  final bool? temMandado;
  final String? status;
  final String? mandados;
  final String? crimes;
  final String? artigos;
  final String? observacoes;

  Alerta({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.nome,
    required this.nivelPerigo,
    this.mensagem,
    this.fotoUrl,
    this.frameB64,
    this.cpf,
    this.confianca,
    this.emocao,
    this.temMandado,
    this.status,
    this.mandados,
    this.crimes,
    this.artigos,
    this.observacoes,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      id: json['id'] as int,
      deviceId: json['device_id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      nivelPerigo: (json['nivel_perigo'] as String? ?? 'ALTO').toUpperCase(),
      mensagem: json['mensagem'] as String?,
      fotoUrl: json['foto_url'] as String?,
      frameB64: json['frame_b64'] as String?,
      cpf: json['cpf'] as String?,
      confianca: (json['confianca'] as num?)?.toDouble(),
      emocao: json['emocao'] as String?,
      temMandado: json['tem_mandado'] as bool?,
      status: json['status'] as String?,
      mandados: _asString(json['mandados']),
      crimes: _asString(json['crimes']),
      artigos: _asString(json['artigos']),
      observacoes: json['observacoes'] as String?,
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.join(', ');
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  PessoaIdentificada? toPessoa() {
    if (cpf == null && confianca == null) return null;
    return PessoaIdentificada.fromJson({
      'id': id,
      'timestamp': timestamp,
      'nome': nome,
      'cpf': cpf ?? '',
      'rg': '',
      'nivel_perigo': nivelPerigo,
      'status': status ?? '',
      'mandados': mandados ?? '',
      'crimes': crimes ?? '',
      'artigos': artigos ?? '',
      'observacoes': observacoes,
      'confianca': confianca ?? 0,
      'prova_de_vida': true,
      'tem_mandado': temMandado ?? false,
      'emocao': emocao,
      'foto_url': fotoUrl,
      'frame_b64': frameB64,
    });
  }
}
