import 'package:flutter/material.dart';

Widget backupCard({
  required String titulo,
  required String descricao,
  required VoidCallback onExecutar,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.backup_rounded, size: 34),
        const SizedBox(height: 12),
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(descricao),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onExecutar,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Executar'),
        ),
      ],
    ),
  );
}
