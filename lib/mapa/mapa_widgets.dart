import 'package:flutter/material.dart';

Widget mapaTituloPremium({required String titulo, String? descricao}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      if (descricao != null) ...[
        const SizedBox(height: 6),
        Text(
          descricao,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
      ],
    ],
  );
}

Widget mapaLegendaItem({required Color cor, required String texto}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}
