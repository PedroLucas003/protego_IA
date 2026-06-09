class Deteccao {
  final int id;
  final String deviceId;
  final String timestamp;
  final String nome;
  final double similaridade;
  final String nivelPerigo;
  final String? emocao;
  final bool antiSpoofing;
  final bool provaDeVida;

  Deteccao({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.nome,
    required this.similaridade,
    required this.nivelPerigo,
    this.emocao,
    required this.antiSpoofing,
    required this.provaDeVida,
  });

  factory Deteccao.fromJson(Map<String, dynamic> json) {
    return Deteccao(
      id: json['id'] as int,
      deviceId: json['device_id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      similaridade: (json['similaridade'] as num?)?.toDouble() ?? 0,
      nivelPerigo: (json['nivel_perigo'] as String? ?? 'MEDIO').toUpperCase(),
      emocao: json['emocao'] as String?,
      antiSpoofing: json['anti_spoofing'] as bool? ?? false,
      provaDeVida: json['prova_de_vida'] as bool? ?? false,
    );
  }

  double get similaridadePercent {
    if (similaridade <= 1) return similaridade * 100;
    return similaridade;
  }
}
