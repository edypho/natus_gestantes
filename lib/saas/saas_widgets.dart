import 'package:flutter/material.dart';

Widget saasClinicaCard({
  required String nomeClinica,
  required String status,
  required int totalGestantes,
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
        Text(
          nomeClinica,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text('Status: $status'),
        const SizedBox(height: 6),
        Text('Pacientes: $totalGestantes'),
      ],
    ),
  );
}

Widget saasPlanoBadge({required String plano, Color? cor}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: (cor ?? Colors.purple).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      plano,
      style: TextStyle(
        color: cor ?? Colors.purple,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
