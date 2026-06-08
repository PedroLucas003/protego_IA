import 'package:flutter/material.dart';

class PerigoTheme {
  static Color corNivel(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'CRITICO':
        return const Color(0xFFD32F2F);
      case 'ALTO':
        return const Color(0xFFE65100);
      case 'MEDIO':
        return const Color(0xFFF9A825);
      case 'BAIXO':
        return const Color(0xFF388E3C);
      default:
        return const Color(0xFF607D8B);
    }
  }

  static IconData iconeNivel(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'CRITICO':
        return Icons.error;
      case 'ALTO':
        return Icons.warning_amber;
      case 'MEDIO':
        return Icons.info_outline;
      default:
        return Icons.shield_outlined;
    }
  }
}
