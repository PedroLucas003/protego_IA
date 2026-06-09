import 'package:flutter/material.dart';
import '../utils/perigo_theme.dart';

class PerigoBadge extends StatelessWidget {
  final String nivel;
  final bool compacto;

  const PerigoBadge({
    super.key,
    required this.nivel,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = PerigoTheme.corNivel(nivel);
    final label = _labelCurto(nivel);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 8 : 10,
        vertical: compacto ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(compacto ? 6 : 8),
        border: Border.all(color: cor.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PerigoTheme.iconeNivel(nivel),
            size: compacto ? 12 : 14,
            color: cor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: compacto ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  String _labelCurto(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'CRITICO':
        return 'CRÍTICO';
      case 'MEDIO':
        return 'MÉDIO';
      default:
        return nivel.toUpperCase();
    }
  }
}
