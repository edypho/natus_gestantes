import 'package:flutter/material.dart';

Widget cardResumoNatus({
  required String titulo,
  required String valor,
  required IconData icone,
  Color cor = const Color(0xFF7B3A44),
  double largura = 245,
}) {
  return Container(
    width: largura,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Icon(icone, color: cor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo),
              Text(
                valor,
                style: TextStyle(color: cor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
