import 'package:flutter/material.dart';
import '../utils/perigo_theme.dart';

class PerigoBadge extends StatelessWidget {
  final String nivel;

  const PerigoBadge({super.key, required this.nivel});

  @override
  Widget build(BuildContext context) {
    final cor = PerigoTheme.corNivel(nivel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PerigoTheme.iconeNivel(nivel), size: 14, color: cor),
          const SizedBox(width: 4),
          Text(
            nivel,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
