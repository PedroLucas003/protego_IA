import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool ativo;

  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.ativo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: ativo ? color : Colors.grey),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: ativo
          ? color.withValues(alpha: 0.15)
          : Colors.grey.withValues(alpha: 0.1),
      side: BorderSide(color: ativo ? color : Colors.grey),
      visualDensity: VisualDensity.compact,
    );
  }
}
