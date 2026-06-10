import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alerta.dart';
import '../models/deteccao.dart';
import '../models/pessoa_identificada.dart';
import '../providers/monitor_provider.dart';
import '../utils/timestamp_utils.dart';
import '../widgets/perigo_badge.dart';
import '../widgets/status_chip.dart';

class DetalhePessoaScreen extends StatelessWidget {
  final PessoaIdentificada pessoa;

  const DetalhePessoaScreen({super.key, required this.pessoa});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suspeito'),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pessoa.nome,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  PerigoBadge(nivel: pessoa.nivelPerigo),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _infoTile(Icons.badge, 'CPF', pessoa.cpf),
          _infoTile(Icons.credit_card, 'RG', pessoa.rg),
          _infoTile(Icons.flag, 'Status', pessoa.status),
          _infoTile(Icons.access_time, 'Horário', formatApiTimestamp(pessoa.timestamp)),
          _infoTile(
            Icons.percent,
            'Confiança',
            '${pessoa.confianca.toStringAsFixed(1)}%',
          ),
          if (pessoa.emocao != null && pessoa.emocao!.isNotEmpty)
            _infoTile(Icons.mood, 'Emoção', pessoa.emocao!),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: 'Prova de vida',
                icon: Icons.visibility,
                color: Colors.green,
                ativo: pessoa.provaDeVida,
              ),
              StatusChip(
                label: 'Mandado',
                icon: Icons.gavel,
                color: Colors.red,
                ativo: pessoa.temMandado,
              ),
            ],
          ),
          const Divider(height: 32),
          _secao('Mandados', pessoa.mandados, Icons.gavel),
          _secao('Crimes', pessoa.crimes, Icons.warning),
          _secao('Artigos', pessoa.artigos, Icons.menu_book),
          if (pessoa.observacoes != null && pessoa.observacoes!.isNotEmpty)
            _secao('Observações', pessoa.observacoes!, Icons.notes),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String titulo, String valor) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3949AB)),
      title: Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(valor, style: const TextStyle(fontSize: 15)),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _secao(String titulo, String conteudo, IconData icon) {
    if (conteudo.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3949AB)),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(conteudo),
        ],
      ),
    );
  }
}

class DetalheAlertaScreen extends StatelessWidget {
  final Alerta alerta;

  const DetalheAlertaScreen({super.key, required this.alerta});

  @override
  Widget build(BuildContext context) {
    final monitor = context.read<MonitorProvider>();
    final a = monitor.enriquecerAlerta(alerta);
    final pessoa = a.toPessoa();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerta'),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.nome,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  PerigoBadge(nivel: a.nivelPerigo),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _infoTile(Icons.message, 'Mensagem', a.mensagem ?? 'Alerta de reconhecimento'),
          _infoTile(Icons.videocam, 'Câmera', a.deviceId),
          _infoTile(Icons.access_time, 'Horário', formatApiTimestamp(a.timestamp)),
          if (a.status != null && a.status!.isNotEmpty)
            _infoTile(Icons.flag, 'Status', a.status!),
          if (a.confianca != null)
            _infoTile(Icons.percent, 'Confiança', '${a.confianca!.toStringAsFixed(1)}%'),
          if (a.emocao != null && a.emocao!.isNotEmpty)
            _infoTile(Icons.mood, 'Emoção', a.emocao!),
          if (a.temMandado == true) ...[
            const SizedBox(height: 8),
            const StatusChip(
              label: 'Mandado ativo',
              icon: Icons.gavel,
              color: Colors.red,
              ativo: true,
            ),
          ],
          if (a.mandados != null && a.mandados!.isNotEmpty)
            _secao('Mandados', a.mandados!, Icons.gavel),
          if (a.crimes != null && a.crimes!.isNotEmpty)
            _secao('Crimes', a.crimes!, Icons.warning),
          if (pessoa != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final completa = await monitor.buscarPessoaCompleta(pessoa);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalhePessoaScreen(pessoa: completa ?? pessoa),
                  ),
                );
              },
              icon: const Icon(Icons.person_search),
              label: const Text('Ver ficha completa'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String titulo, String valor) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3949AB)),
      title: Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(valor, style: const TextStyle(fontSize: 15)),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _secao(String titulo, String conteudo, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3949AB)),
              const SizedBox(width: 8),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(conteudo),
        ],
      ),
    );
  }
}

class DetalheDeteccaoScreen extends StatelessWidget {
  final Deteccao deteccao;

  const DetalheDeteccaoScreen({super.key, required this.deteccao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(deteccao.nome),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deteccao.nome,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  PerigoBadge(nivel: deteccao.nivelPerigo),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _infoTile(Icons.percent, 'Similaridade',
              '${deteccao.similaridadePercent.toStringAsFixed(1)}%'),
          _infoTile(Icons.videocam, 'Câmera', deteccao.deviceId),
          _infoTile(Icons.access_time, 'Horário', formatApiTimestamp(deteccao.timestamp)),
          if (deteccao.emocao != null && deteccao.emocao!.isNotEmpty)
            _infoTile(Icons.mood, 'Emoção', deteccao.emocao!),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              StatusChip(
                label: 'Anti-spoofing',
                icon: Icons.security,
                color: Colors.blue,
                ativo: deteccao.antiSpoofing,
              ),
              StatusChip(
                label: 'Prova de vida',
                icon: Icons.visibility,
                color: Colors.green,
                ativo: deteccao.provaDeVida,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String titulo, String valor) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3949AB)),
      title: Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(valor, style: const TextStyle(fontSize: 15)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
