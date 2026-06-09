class PessoaIdentificada {
  final int id;
  final String timestamp;
  final String nome;
  final String cpf;
  final String rg;
  final String nivelPerigo;
  final String status;
  final String mandados;
  final String crimes;
  final String artigos;
  final String? observacoes;
  final double confianca;
  final bool provaDeVida;
  final bool temMandado;
  final String? emocao;

  PessoaIdentificada({
    required this.id,
    required this.timestamp,
    required this.nome,
    required this.cpf,
    required this.rg,
    required this.nivelPerigo,
    required this.status,
    required this.mandados,
    required this.crimes,
    required this.artigos,
    this.observacoes,
    required this.confianca,
    required this.provaDeVida,
    required this.temMandado,
    this.emocao,
  });

  factory PessoaIdentificada.fromJson(Map<String, dynamic> json) {
    return PessoaIdentificada(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      timestamp: json['timestamp'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      cpf: json['cpf'] as String? ?? '',
      rg: json['rg'] as String? ?? '',
      nivelPerigo: (json['nivel_perigo'] as String? ?? 'MEDIO').toUpperCase(),
      status: json['status'] as String? ?? '',
      mandados: _asString(json['mandados']),
      crimes: _asString(json['crimes']),
      artigos: _asString(json['artigos']),
      observacoes: json['observacoes'] as String?,
      confianca: (json['confianca'] as num?)?.toDouble() ?? 0,
      provaDeVida: json['prova_de_vida'] as bool? ?? false,
      temMandado: json['tem_mandado'] as bool? ?? false,
      emocao: json['emocao'] as String?,
    );
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.join(', ');
    return value.toString();
  }
}
