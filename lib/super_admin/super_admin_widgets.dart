import 'package:flutter/material.dart';

Widget superAdminCard({
  required String titulo,
  required String valor,
  required IconData icone,
  double? width,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      width: width ?? 260,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: const Color(0xFF7B3A44), size: 17),
          const SizedBox(height: 6),
          Text(
            titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 9.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              color: Color(0xFF7B3A44),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    ),
  );
}
