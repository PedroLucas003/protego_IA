import 'alerta.dart';
import 'deteccao.dart';
import 'pessoa_identificada.dart';
import '../utils/timestamp_utils.dart';

enum TipoEventoCamera { alerta, deteccao, identificacao }

/// Entrada unificada do log de uma câmera (alertas + detecções + identificações).
class EventoCamera {
  final TipoEventoCamera tipo;
  final int id;
  final String timestamp;
  final String nome;
  final String nivelPerigo;
  final String resumo;
  final String? deviceId;
  final Alerta? alerta;
  final Deteccao? deteccao;
  final PessoaIdentificada? pessoa;

  EventoCamera({
    required this.tipo,
    required this.id,
    required this.timestamp,
    required this.nome,
    required this.nivelPerigo,
    required this.resumo,
    this.deviceId,
    this.alerta,
    this.deteccao,
    this.pessoa,
  });

  factory EventoCamera.fromAlerta(Alerta a) {
    return EventoCamera(
      tipo: TipoEventoCamera.alerta,
      id: a.id,
      timestamp: a.timestamp,
      nome: a.nome,
      nivelPerigo: a.nivelPerigo,
      resumo: a.mensagem ?? 'Alerta de reconhecimento',
      deviceId: a.deviceId,
      alerta: a,
    );
  }

  factory EventoCamera.fromDeteccao(Deteccao d) {
    return EventoCamera(
      tipo: TipoEventoCamera.deteccao,
      id: d.id,
      timestamp: d.timestamp,
      nome: d.nome,
      nivelPerigo: d.nivelPerigo,
      resumo:
          'Detecção · ${d.similaridadePercent.toStringAsFixed(0)}% similaridade',
      deviceId: d.deviceId,
      deteccao: d,
    );
  }

  factory EventoCamera.fromPessoa(PessoaIdentificada p) {
    return EventoCamera(
      tipo: TipoEventoCamera.identificacao,
      id: p.id,
      timestamp: p.timestamp,
      nome: p.nome,
      nivelPerigo: p.nivelPerigo,
      resumo: [
        if (p.status.isNotEmpty) p.status,
        if (p.confianca > 0) '${p.confianca.toStringAsFixed(0)}% confiança',
      ].join(' · '),
      pessoa: p,
    );
  }

  DateTime? get dateTime => parseApiTimestamp(timestamp);
}
