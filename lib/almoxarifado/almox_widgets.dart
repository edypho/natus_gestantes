import 'package:flutter/material.dart';

Widget cardResumoAlmoxWidget({
  required String titulo,
  required String quantidade,
  required IconData icone,
  required Color cor,
}) {
  return Container(
    width: 240,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: cor.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: cor.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: cor, size: 30),
        const SizedBox(height: 16),
        Text(
          titulo,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          quantidade,
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ],
    ),
  );
}

Widget statusEstoqueWidget({required bool estoqueBaixo}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: estoqueBaixo
          ? Colors.red.withValues(alpha: 0.10)
          : Colors.green.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      estoqueBaixo ? 'Estoque baixo' : 'Estoque OK',
      style: TextStyle(
        color: estoqueBaixo ? Colors.red : Colors.green,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
