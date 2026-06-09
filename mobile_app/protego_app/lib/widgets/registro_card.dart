import 'package:flutter/material.dart';
import 'perigo_badge.dart';

/// Card de registro com layout que evita sobreposição de badge sobre o nome.
class RegistroCard extends StatelessWidget {
  final Widget leading;
  final String titulo;
  final String subtitulo;
  final String? detalhe;
  final String? nivelPerigo;
  final Widget? extra;
  final VoidCallback? onTap;

  const RegistroCard({
    super.key,
    required this.leading,
    required this.titulo,
    required this.subtitulo,
    this.detalhe,
    this.nivelPerigo,
    this.extra,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[
      if (nivelPerigo != null) PerigoBadge(nivel: nivelPerigo!, compacto: true),
      ?extra,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: leading,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    if (detalhe != null && detalhe!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detalhe!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: tags,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade600,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
