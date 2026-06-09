import 'package:flutter/material.dart';
import '../models/pessoa_identificada.dart';
import 'perigo_badge.dart';
import 'status_chip.dart';

/// Ficha de suspeito cadastrado — somente dados textuais.
class FichaSuspeito extends StatelessWidget {
  final PessoaIdentificada pessoa;
  final String? horarioDeteccao;
  final String? cameraId;
  final double? similaridade;

  const FichaSuspeito({
    super.key,
    required this.pessoa,
    this.horarioDeteccao,
    this.cameraId,
    this.similaridade,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
            const SizedBox(height: 16),
            if (similaridade != null && similaridade! > 0)
              _linha(Icons.percent, 'Similaridade', '${similaridade!.toStringAsFixed(1)}%'),
            _linha(Icons.badge, 'CPF', pessoa.cpf),
            _linha(Icons.credit_card, 'RG', pessoa.rg),
            _linha(Icons.flag, 'Status', pessoa.status),
            if (horarioDeteccao != null && horarioDeteccao!.isNotEmpty)
              _linha(Icons.access_time, 'Detectado em', horarioDeteccao!),
            if (cameraId != null && cameraId!.isNotEmpty)
              _linha(Icons.videocam, 'Câmera', cameraId!),
            if (pessoa.confianca > 0)
              _linha(Icons.analytics, 'Confiança', '${pessoa.confianca.toStringAsFixed(1)}%'),
            if (pessoa.emocao != null && pessoa.emocao!.isNotEmpty)
              _linha(Icons.mood, 'Emoção', pessoa.emocao!),
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
            if (pessoa.mandados.isNotEmpty) ...[
              const Divider(height: 24),
              _secao('Mandados', pessoa.mandados, Icons.gavel),
            ],
            if (pessoa.crimes.isNotEmpty)
              _secao('Crimes', pessoa.crimes, Icons.warning),
            if (pessoa.artigos.isNotEmpty)
              _secao('Artigos', pessoa.artigos, Icons.menu_book),
            if (pessoa.observacoes != null && pessoa.observacoes!.isNotEmpty)
              _secao('Observações', pessoa.observacoes!, Icons.notes),
          ],
        ),
      ),
    );
  }

  Widget _linha(IconData icon, String titulo, String valor) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3949AB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(valor, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secao(String titulo, String conteudo, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF3949AB)),
              const SizedBox(width: 8),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(conteudo),
        ],
      ),
    );
  }
}
