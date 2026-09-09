import 'package:flutter/material.dart';

Widget relatorioCard({
  required String titulo,
  required String descricao,
  required VoidCallback onExportar,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(Icons.picture_as_pdf_rounded, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(descricao),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onExportar,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Exportar'),
        ),
      ],
    ),
  );
}
