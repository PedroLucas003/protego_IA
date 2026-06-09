import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/deteccao.dart';
import '../models/pessoa_identificada.dart';
import '../providers/monitor_provider.dart';
import '../widgets/ficha_suspeito.dart';

enum _EstadoMonitor { offline, procurando, encontrado }

/// Monitor passivo da câmera — exibe "Procurando suspeito..." até a IA
/// identificar alguém cadastrado no banco.
class CameraMonitorScreen extends StatefulWidget {
  final CameraDevice camera;

  const CameraMonitorScreen({super.key, required this.camera});

  @override
  State<CameraMonitorScreen> createState() => _CameraMonitorScreenState();
}

class _CameraMonitorScreenState extends State<CameraMonitorScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  late final AnimationController _pulseCtrl;
  PessoaIdentificada? _suspeitoEncontrado;
  Deteccao? _deteccaoAtual;
  _EstadoMonitor _estado = _EstadoMonitor.procurando;
  int _ultimaDeteccaoId = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _atualizarEstado();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _atualizarEstado());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _atualizarEstado() async {
    final monitor = context.read<MonitorProvider>();
    await monitor.refresh(silencioso: true);

    if (!mounted) return;

    final cameraAtual = monitor.cameras.firstWhere(
      (c) => c.deviceId == widget.camera.deviceId,
      orElse: () => widget.camera,
    );

    if (!cameraAtual.online) {
      setState(() {
        _estado = _EstadoMonitor.offline;
        _suspeitoEncontrado = null;
        _deteccaoAtual = null;
      });
      return;
    }

    final deteccao = monitor.ultimaDeteccaoCamera(cameraAtual.deviceId);
    if (deteccao != null && _ehDeteccaoRecente(deteccao)) {
      final suspeito = await monitor.resolverSuspeito(deteccao);
      if (!mounted) return;

      if (suspeito != null && deteccao.id != _ultimaDeteccaoId) {
        _ultimaDeteccaoId = deteccao.id;
        setState(() {
          _estado = _EstadoMonitor.encontrado;
          _suspeitoEncontrado = suspeito;
          _deteccaoAtual = deteccao;
        });
        return;
      }
    }

    if (_estado != _EstadoMonitor.encontrado) {
      setState(() => _estado = _EstadoMonitor.procurando);
    }
  }

  bool _ehDeteccaoRecente(Deteccao d) {
    final dt = DateTime.tryParse(d.timestamp);
    if (dt == null) return true;
    return DateTime.now().difference(dt).inMinutes < 3;
  }

  void _continuarBusca() {
    setState(() {
      _estado = _EstadoMonitor.procurando;
      _suspeitoEncontrado = null;
      _deteccaoAtual = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.camera.deviceId),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: RefreshIndicator(
        onRefresh: _atualizarEstado,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCamera(camera: widget.camera, estado: _estado),
            const SizedBox(height: 20),
            if (_estado == _EstadoMonitor.offline)
              _PainelOffline()
            else if (_estado == _EstadoMonitor.procurando)
              _PainelProcurando(pulse: _pulseCtrl)
            else if (_suspeitoEncontrado != null)
              Column(
                children: [
                  _PainelEncontrado(),
                  const SizedBox(height: 16),
                  FichaSuspeito(
                    pessoa: _suspeitoEncontrado!,
                    horarioDeteccao: _deteccaoAtual?.timestamp,
                    cameraId: widget.camera.deviceId,
                    similaridade: _deteccaoAtual?.similaridadePercent,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _continuarBusca,
                    icon: const Icon(Icons.search),
                    label: const Text('Continuar busca'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCamera extends StatelessWidget {
  final CameraDevice camera;
  final _EstadoMonitor estado;

  const _StatusCamera({required this.camera, required this.estado});

  @override
  Widget build(BuildContext context) {
    final online = camera.online;
    return Card(
      color: const Color(0xFF1E2A3A),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              online ? Icons.videocam : Icons.videocam_off,
              color: online ? Colors.lightGreenAccent : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online ? 'Câmera ativa — IA em execução' : 'Câmera desligada',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (camera.ultimoHeartbeat != null)
                    Text(
                      'Último sinal: ${_formatTs(camera.ultimoHeartbeat!)}',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                ],
              ),
            ),
            _chipEstado(estado),
          ],
        ),
      ),
    );
  }

  Widget _chipEstado(_EstadoMonitor e) {
    final (label, cor) = switch (e) {
      _EstadoMonitor.offline => ('OFFLINE', Colors.grey),
      _EstadoMonitor.procurando => ('BUSCANDO', Colors.orange),
      _EstadoMonitor.encontrado => ('MATCH', Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor),
      ),
      child: Text(label, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatTs(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PainelOffline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PainelCentral(
      icon: Icons.videocam_off,
      cor: Colors.grey,
      titulo: 'Câmera desligada',
      subtitulo:
          'Ligue a bodycam e inicie o reconhecimento facial no computador para começar a busca.',
    );
  }
}

class _PainelProcurando extends StatelessWidget {
  final AnimationController pulse;

  const _PainelProcurando({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final opacidade = 0.4 + pulse.value * 0.6;
        return _PainelCentral(
          icon: Icons.radar,
          cor: Colors.orange.withValues(alpha: opacidade),
          titulo: 'Procurando suspeito...',
          subtitulo:
              'A IA está analisando o vídeo em busca de rostos cadastrados no banco.',
          animado: true,
        );
      },
    );
  }
}

class _PainelEncontrado extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PainelCentral(
      icon: Icons.person_search,
      cor: Colors.redAccent,
      titulo: 'Suspeito identificado!',
      subtitulo: 'Alvo cadastrado encontrado na câmera.',
    );
  }
}

class _PainelCentral extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String titulo;
  final String subtitulo;
  final bool animado;

  const _PainelCentral({
    required this.icon,
    required this.cor,
    required this.titulo,
    required this.subtitulo,
    this.animado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            if (animado)
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: cor,
                ),
              )
            else
              Icon(icon, size: 72, color: cor),
            const SizedBox(height: 20),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
