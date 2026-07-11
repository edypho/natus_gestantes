import 'package:flutter/material.dart';

Widget superAdminCard({
  required String titulo,
  required String valor,
  required IconData icone,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
    width: 260,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icone,
          color: const Color(0xFF7B3A44),
          size: 30,
        ),
        const SizedBox(height: 18),
        Text(
          titulo,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          valor,
          style: const TextStyle(
            color: Color(0xFF7B3A44),
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ],
    ),
  ));
}
