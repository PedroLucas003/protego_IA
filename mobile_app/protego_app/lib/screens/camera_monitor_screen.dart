import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/evento_camera.dart';
import '../providers/monitor_provider.dart';
import '../utils/perigo_theme.dart';
import '../widgets/registro_card.dart';
import 'detalhe_pessoa_screen.dart';

/// Log de notificações da câmera (alertas + detecções), sem stream de vídeo.
class CameraMonitorScreen extends StatefulWidget {
  final CameraDevice camera;

  const CameraMonitorScreen({super.key, required this.camera});

  @override
  State<CameraMonitorScreen> createState() => _CameraMonitorScreenState();
}

class _CameraMonitorScreenState extends State<CameraMonitorScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => context.read<MonitorProvider>().refresh(silencioso: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, monitor, _) {
        final camera = monitor.cameraPorId(widget.camera.deviceId) ?? widget.camera;
        final eventos = monitor.logCamera(camera.deviceId);

        return Scaffold(
          appBar: AppBar(
            title: Text(camera.deviceId),
            backgroundColor: const Color(0xFF1A237E),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => monitor.refresh(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => monitor.refresh(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _CabecalhoCamera(camera: camera, totalEventos: eventos.length),
                if (!camera.online) ...[
                  const SizedBox(height: 8),
                  _AvisoOffline(),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, size: 18, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text(
                        'Log de notificações',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (camera.online)
                        _chipAoVivo(),
                    ],
                  ),
                ),
                if (eventos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none,
                            size: 56, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text(
                          camera.online
                              ? 'Nenhuma notificação ainda.\nAguardando detecções da IA…'
                              : 'Nenhum registro para esta câmera.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                else
                  ...eventos.map((e) => _LogTile(evento: e, monitor: monitor)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CabecalhoCamera extends StatelessWidget {
  final CameraDevice camera;
  final int totalEventos;

  const _CabecalhoCamera({required this.camera, required this.totalEventos});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E2A3A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  camera.online ? Colors.green.shade800 : Colors.grey.shade700,
              child: Icon(
                camera.online ? Icons.videocam : Icons.videocam_off,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.online ? 'Câmera online' : 'Câmera offline',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    camera.ultimoHeartbeat != null
                        ? 'Último sinal: ${_formatTs(camera.ultimoHeartbeat!)}'
                        : 'Sem heartbeat registrado',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  Text(
                    '$totalEventos evento(s) no log',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (camera.online ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: camera.online ? Colors.green : Colors.grey,
                ),
              ),
              child: Text(
                camera.online ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: camera.online ? Colors.lightGreenAccent : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTs(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

class _AvisoOffline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.orange.shade900.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade200, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sem sinal recente. O log abaixo mostra o histórico salvo no Railway.',
                  style: TextStyle(color: Colors.orange.shade100, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _chipAoVivo() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'AO VIVO',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _LogTile extends StatelessWidget {
  final EventoCamera evento;
  final MonitorProvider monitor;

  const _LogTile({required this.evento, required this.monitor});

  @override
  Widget build(BuildContext context) {
    final isAlerta = evento.tipo == TipoEventoCamera.alerta;
    final icone = isAlerta ? Icons.notifications_active : Icons.face_retouching_natural;
    final cor = PerigoTheme.corNivel(evento.nivelPerigo);
    final hora = evento.dateTime != null ? _formatTs(evento.dateTime!) : evento.timestamp;

    return RegistroCard(
      leading: Icon(icone, color: cor, size: 28),
      titulo: evento.nome,
      subtitulo: evento.resumo,
      detalhe: hora,
      nivelPerigo: evento.nivelPerigo,
      extra: _chipTipo(isAlerta),
      onTap: () => _abrirDetalhe(context),
    );
  }

  Widget _chipTipo(bool alerta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.5)),
      ),
      child: Text(
        alerta ? 'ALERTA' : 'DETECÇÃO',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _abrirDetalhe(BuildContext context) {
    if (evento.alerta != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalheAlertaScreen(alerta: evento.alerta!),
        ),
      );
      return;
    }
    if (evento.deteccao != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalheDeteccaoScreen(deteccao: evento.deteccao!),
        ),
      );
    }
  }

  String _formatTs(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
