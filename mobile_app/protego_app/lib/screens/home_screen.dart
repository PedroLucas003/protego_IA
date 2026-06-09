import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alerta.dart';
import '../models/camera_device.dart';
import '../models/pessoa_identificada.dart';
import '../providers/monitor_provider.dart';
import '../utils/perigo_theme.dart';
import '../widgets/registro_card.dart';
import 'camera_monitor_screen.dart';
import 'detalhe_pessoa_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    _TabInfo(label: 'Suspeitos', icon: Icons.person_search),
    _TabInfo(label: 'Câmeras', icon: Icons.videocam),
    _TabInfo(label: 'Alertas', icon: Icons.notifications_active),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitorProvider>().iniciar();
    });
  }

  int _contagemTab(MonitorProvider m, int i) {
    switch (i) {
      case 0:
        return m.pessoas.length;
      case 1:
        return m.camerasOnline;
      case 2:
        return m.alertas.length;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, monitor, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Protego IA'),
            backgroundColor: const Color(0xFF1A237E),
            actions: [
              _StatusIndicator(apiOnline: monitor.apiOnline),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar',
                onPressed: () => monitor.refresh(),
              ),
            ],
          ),
          body: Column(
            children: [
              _ResumoBar(monitor: monitor),
              if (monitor.erro != null)
                Material(
                  color: Colors.red.shade900.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      monitor.erro!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              Expanded(
                child: monitor.carregando && monitor.pessoas.isEmpty && monitor.alertas.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : IndexedStack(
                        index: _tabIndex,
                        children: [
                          _ListaSuspeitos(pessoas: monitor.pessoas),
                          _ListaCameras(cameras: monitor.cameras),
                          _ListaAlertas(alertas: monitor.alertas),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            height: 64,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final count = _contagemTab(monitor, i);
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: Icon(tab.icon),
                ),
                label: tab.label,
              );
            }),
          ),
        );
      },
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;

  const _TabInfo({required this.label, required this.icon});
}

class _StatusIndicator extends StatelessWidget {
  final bool apiOnline;

  const _StatusIndicator({required this.apiOnline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: apiOnline ? 'API Railway online' : 'API offline',
        child: Icon(
          Icons.cloud,
          color: apiOnline ? Colors.lightGreenAccent : Colors.redAccent,
          size: 22,
        ),
      ),
    );
  }
}

class _ResumoBar extends StatelessWidget {
  final MonitorProvider monitor;

  const _ResumoBar({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final atualizado = monitor.ultimaAtualizacao;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF283593),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${monitor.totalAlertasCriticos} críticos • '
              '${monitor.camerasOnline}/${monitor.cameras.length} câmeras',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            atualizado != null
                ? _formatHora(atualizado)
                : 'Aguardando...',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

class _ListaAlertas extends StatelessWidget {
  final List<Alerta> alertas;

  const _ListaAlertas({required this.alertas});

  @override
  Widget build(BuildContext context) {
    if (alertas.isEmpty) {
      return const _EmptyState(
        icon: Icons.notifications_off,
        texto: 'Nenhum alerta no banco.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<MonitorProvider>().refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: alertas.length,
        itemBuilder: (context, i) {
          final a = context.read<MonitorProvider>().enriquecerAlerta(alertas[i]);
          return RegistroCard(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: PerigoTheme.corNivel(a.nivelPerigo),
              size: 32,
            ),
            titulo: a.nome,
            subtitulo: a.mensagem ?? 'Alerta de reconhecimento',
            detalhe: '${a.deviceId} • ${a.timestamp}',
            nivelPerigo: a.nivelPerigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetalheAlertaScreen(alerta: a)),
            ),
          );
        },
      ),
    );
  }
}

class _ListaSuspeitos extends StatelessWidget {
  final List<PessoaIdentificada> pessoas;

  const _ListaSuspeitos({required this.pessoas});

  @override
  Widget build(BuildContext context) {
    if (pessoas.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_off,
        texto: 'Nenhum suspeito cadastrado no banco.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<MonitorProvider>().refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: pessoas.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Alvos cadastrados no sistema (${pessoas.length})',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            );
          }
          final p = pessoas[i - 1];
          return RegistroCard(
            leading: Icon(
              p.temMandado ? Icons.gavel : Icons.person,
              color: p.temMandado ? Colors.redAccent : Colors.blueGrey.shade300,
              size: 32,
            ),
            titulo: p.nome,
            subtitulo: p.status.isNotEmpty ? p.status : 'Cadastrado',
            detalhe: [
              if (p.cpf.isNotEmpty) 'CPF ${p.cpf}',
              if (p.nivelPerigo.isNotEmpty) p.nivelPerigo,
            ].join(' • '),
            nivelPerigo: p.nivelPerigo,
            extra: p.temMandado
                ? _chipStatus('Mandado', Colors.redAccent)
                : null,
            onTap: () async {
              final monitor = context.read<MonitorProvider>();
              final completa = await monitor.buscarPessoaCompleta(p);
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalhePessoaScreen(pessoa: completa ?? p),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ListaCameras extends StatelessWidget {
  final List<CameraDevice> cameras;

  const _ListaCameras({required this.cameras});

  @override
  Widget build(BuildContext context) {
    if (cameras.isEmpty) {
      return const _EmptyState(
        icon: Icons.videocam_off,
        texto: 'Nenhuma câmera registrada no Railway.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<MonitorProvider>().refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: cameras.length,
        itemBuilder: (context, i) {
          final c = cameras[i];
          return RegistroCard(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: c.online ? Colors.green.shade800 : Colors.grey.shade700,
              child: Icon(
                c.online ? Icons.videocam : Icons.videocam_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            titulo: c.deviceId,
            subtitulo: c.online
                ? 'Toque para monitorar em tempo real'
                : 'Câmera offline',
            detalhe: c.ultimoHeartbeat != null
                ? 'Último sinal: ${_formatTs(c.ultimoHeartbeat!)}'
                : 'Sem heartbeat',
            extra: _chipStatus(
              c.online ? 'ONLINE' : 'OFFLINE',
              c.online ? Colors.green : Colors.grey,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CameraMonitorScreen(camera: c),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTs(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

Widget _chipStatus(String label, Color cor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: cor.withValues(alpha: 0.6)),
    ),
    child: Text(
      label,
      style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _EmptyState({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
