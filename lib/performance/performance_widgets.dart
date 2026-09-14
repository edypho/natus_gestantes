import 'package:flutter/material.dart';

Widget performanceInfoCard({
  required String titulo,
  required String descricao,
  required IconData icone,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
    ),
    child: Row(
      children: [
        Icon(icone, size: 30),
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
              const SizedBox(height: 6),
              Text(descricao),
            ],
          ),
        ),
      ],
    ),
  );
}
