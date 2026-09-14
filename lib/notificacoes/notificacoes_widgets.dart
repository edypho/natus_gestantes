import 'package:flutter/material.dart';

Widget notificacaoCard({
  required String titulo,
  required String mensagem,
  required IconData icone,
  Color? cor,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: (cor ?? Colors.blue).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: (cor ?? Colors.blue).withValues(alpha: 0.20)),
    ),
    child: Row(
      children: [
        Icon(icone, color: cor ?? Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(mensagem),
            ],
          ),
        ),
      ],
    ),
  );
}
