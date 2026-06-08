import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alerta.dart';
import '../models/camera_device.dart';
import '../models/deteccao.dart';
import '../models/pessoa_identificada.dart';
import '../providers/monitor_provider.dart';
import '../services/mqtt_service.dart';
import '../utils/face_image.dart';
import '../utils/perigo_theme.dart';
import '../widgets/perigo_badge.dart';
import 'detalhe_pessoa_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitorProvider>().iniciar();
    });
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
              _StatusIndicator(
                apiOnline: monitor.apiOnline,
                mqttState: monitor.mqttState,
                mqttErro: monitor.mqttErro,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => monitor.refresh(),
              ),
            ],
          ),
          body: Column(
            children: [
              _ResumoBar(monitor: monitor),
              if (monitor.erro != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    monitor.erro!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              _FeedAoVivo(monitor: monitor),
              Expanded(
                child: monitor.carregando && monitor.deteccoes.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : IndexedStack(
                        index: _tabIndex,
                        children: [
                          _ListaAlertas(alertas: monitor.alertas),
                          _ListaDeteccoes(deteccoes: monitor.deteccoes),
                          _ListaPessoas(pessoas: monitor.pessoas),
                          _ListaCameras(cameras: monitor.cameras),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  label: Text('${monitor.alertas.length}'),
                  isLabelVisible: monitor.alertas.isNotEmpty,
                  child: const Icon(Icons.notifications_active),
                ),
                label: 'Alertas',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('${monitor.deteccoes.length}'),
                  isLabelVisible: monitor.deteccoes.isNotEmpty,
                  child: const Icon(Icons.face_retouching_natural),
                ),
                label: 'Detecções',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('${monitor.pessoas.length}'),
                  isLabelVisible: monitor.pessoas.isNotEmpty,
                  child: const Icon(Icons.person_search),
                ),
                label: 'Identificados',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('${monitor.camerasOnline}'),
                  isLabelVisible: monitor.cameras.isNotEmpty,
                  child: const Icon(Icons.videocam),
                ),
                label: 'Câmeras',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedAoVivo extends StatelessWidget {
  final MonitorProvider monitor;

  const _FeedAoVivo({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final itens = <dynamic>[
      ...monitor.deteccoes.take(8),
      ...monitor.pessoas.take(8),
    ];
    if (itens.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 110,
      color: const Color(0xFF1E2A3A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.sensors, size: 14, color: Colors.lightGreenAccent),
                SizedBox(width: 6),
                Text(
                  'Feed das câmeras',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: itens.length.clamp(0, 12),
              itemBuilder: (context, i) {
                final item = itens[i];
                if (item is Deteccao) {
                  return _FeedCard(
                    nome: item.nome,
                    subtitulo: item.deviceId,
                    frameB64: item.frameB64,
                    fotoUrl: item.fotoUrl,
                    cor: PerigoTheme.corNivel(item.nivelPerigo),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalheDeteccaoScreen(deteccao: item),
                      ),
                    ),
                  );
                }
                final p = item as PessoaIdentificada;
                return _FeedCard(
                  nome: p.nome,
                  subtitulo: p.status,
                  frameB64: p.frameB64,
                  fotoUrl: p.fotoUrl,
                  cor: PerigoTheme.corNivel(p.nivelPerigo),
                  onTap: () => _abrirPessoa(context, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _abrirPessoa(BuildContext context, PessoaIdentificada p) async {
    final monitor = context.read<MonitorProvider>();
    final completa = await monitor.buscarPessoaCompleta(p);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalhePessoaScreen(pessoa: completa ?? p),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final String nome;
  final String subtitulo;
  final String? frameB64;
  final String? fotoUrl;
  final Color cor;
  final VoidCallback onTap;

  const _FeedCard({
    required this.nome,
    required this.subtitulo,
    this.frameB64,
    this.fotoUrl,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: cor, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: FaceImage.build(
                    frameB64: frameB64,
                    fotoUrl: fotoUrl,
                    height: 56,
                    width: 56,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey.shade800,
                      child: Icon(Icons.face, color: cor, size: 28),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
            Text(
              subtitulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool apiOnline;
  final ProtegoMqttState mqttState;
  final String? mqttErro;

  const _StatusIndicator({
    required this.apiOnline,
    required this.mqttState,
    this.mqttErro,
  });

  @override
  Widget build(BuildContext context) {
    final mqttOk = mqttState == ProtegoMqttState.connected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Tooltip(
            message: apiOnline ? 'API Railway online' : 'API offline',
            child: Icon(
              Icons.cloud,
              color: apiOnline ? Colors.lightGreenAccent : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: mqttOk
                ? 'MQTT mTLS conectado (kodama)'
                : mqttErro ?? 'MQTT: $mqttState',
            child: Icon(
              Icons.wifi_tethering,
              color: mqttOk ? Colors.lightGreenAccent : Colors.orangeAccent,
              size: 20,
            ),
          ),
        ],
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${monitor.totalAlertasCriticos} críticos • ${monitor.camerasOnline}/${monitor.cameras.length} câmeras',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            atualizado != null
                ? 'Atualizado ${_formatHora(atualizado)}'
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
        texto: 'Nenhum alerta no momento.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<MonitorProvider>().refresh(),
      child: ListView.builder(
        itemCount: alertas.length,
        itemBuilder: (context, i) {
          final a = context.read<MonitorProvider>().enriquecerAlerta(alertas[i]);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: FaceImage.thumbnail(
                frameB64: a.frameB64,
                fotoUrl: a.fotoUrl,
                fallbackIcon: Icons.warning_amber_rounded,
                fallbackColor: PerigoTheme.corNivel(a.nivelPerigo),
              ),
              title: Text(a.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${a.deviceId} • ${a.mensagem ?? a.timestamp}'),
              trailing: PerigoBadge(nivel: a.nivelPerigo),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalheAlertaScreen(alerta: a),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ListaDeteccoes extends StatelessWidget {
  final List<Deteccao> deteccoes;

  const _ListaDeteccoes({required this.deteccoes});

  @override
  Widget build(BuildContext context) {
    if (deteccoes.isEmpty) {
      return const _EmptyState(
        icon: Icons.videocam_off,
        texto: 'Nenhuma detecção registrada.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<MonitorProvider>().refresh(),
      child: ListView.builder(
        itemCount: deteccoes.length,
        itemBuilder: (context, i) {
          final d = deteccoes[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: d.imagemRosto != null
                  ? FaceImage.thumbnail(
                      frameB64: d.frameB64,
                      fotoUrl: d.fotoUrl,
                      fallbackColor: PerigoTheme.corNivel(d.nivelPerigo),
                    )
                  : CircleAvatar(
                      backgroundColor: PerigoTheme.corNivel(d.nivelPerigo),
                      child: Text(
                        '${d.similaridadePercent.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
              title: Text(d.nome),
              subtitle: Text('${d.deviceId} • ${d.timestamp}'),
              trailing: PerigoBadge(nivel: d.nivelPerigo),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalheDeteccaoScreen(deteccao: d),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ListaPessoas extends StatelessWidget {
  final List<PessoaIdentificada> pessoas;

  const _ListaPessoas({required this.pessoas});

  @override
  Widget build(BuildContext context) {
    if (pessoas.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_off,
        texto: 'Aguardando reconhecimento facial...',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<MonitorProvider>().refresh(),
      child: ListView.builder(
        itemCount: pessoas.length,
        itemBuilder: (context, i) {
          final p = pessoas[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: FaceImage.thumbnail(
                frameB64: p.frameB64,
                fotoUrl: p.fotoUrl,
                fallbackIcon: p.temMandado ? Icons.gavel : Icons.person,
                fallbackColor: p.temMandado ? Colors.red : Colors.blueGrey,
              ),
              title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${p.cpf} • ${p.status}'),
              trailing: PerigoBadge(nivel: p.nivelPerigo),
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
            ),
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
        itemCount: cameras.length,
        itemBuilder: (context, i) {
          final c = cameras[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: c.online ? Colors.green.shade800 : Colors.grey.shade700,
                child: Icon(
                  c.online ? Icons.videocam : Icons.videocam_off,
                  color: Colors.white,
                ),
              ),
              title: Text(c.deviceId, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                c.ultimoHeartbeat != null
                    ? 'Último sinal: ${_formatTs(c.ultimoHeartbeat!)}'
                    : 'Sem heartbeat',
              ),
              trailing: Chip(
                label: Text(
                  c.online ? 'ONLINE' : 'OFFLINE',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: c.online ? Colors.green : Colors.grey,
                padding: EdgeInsets.zero,
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _EmptyState({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(texto, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
