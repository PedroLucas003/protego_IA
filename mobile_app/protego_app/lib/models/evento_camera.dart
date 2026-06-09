import 'alerta.dart';
import 'deteccao.dart';

enum TipoEventoCamera { alerta, deteccao }

/// Entrada unificada do log de uma câmera (alertas + detecções).
class EventoCamera {
  final TipoEventoCamera tipo;
  final int id;
  final String timestamp;
  final String nome;
  final String nivelPerigo;
  final String resumo;
  final Alerta? alerta;
  final Deteccao? deteccao;

  EventoCamera({
    required this.tipo,
    required this.id,
    required this.timestamp,
    required this.nome,
    required this.nivelPerigo,
    required this.resumo,
    this.alerta,
    this.deteccao,
  });

  factory EventoCamera.fromAlerta(Alerta a) {
    return EventoCamera(
      tipo: TipoEventoCamera.alerta,
      id: a.id,
      timestamp: a.timestamp,
      nome: a.nome,
      nivelPerigo: a.nivelPerigo,
      resumo: a.mensagem ?? 'Alerta de reconhecimento',
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
      deteccao: d,
    );
  }

  DateTime? get dateTime {
    try {
      var raw = timestamp.trim();
      if (!raw.endsWith('Z') && !raw.contains('+') && raw.contains('T')) {
        raw = '${raw}Z';
      }
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }
}
