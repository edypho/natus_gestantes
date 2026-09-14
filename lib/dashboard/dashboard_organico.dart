import 'package:flutter/material.dart';

import '../decorativos/decorativos_natus.dart';

Widget blocoDashboardOrganico(
  String titulo,
  dynamic valorOuFilhos, [
  dynamic terceiro,
  dynamic quarto,
]) {
  IconData? icone;
  Color? cor;

  if (terceiro is IconData) {
    icone = terceiro;
  } else if (terceiro is Color) {
    cor = terceiro;
  }

  if (quarto is IconData) {
    icone = quarto;
  } else if (quarto is Color) {
    cor = quarto;
  }

  if (valorOuFilhos is List<Widget>) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF7B3A44).withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B3A44).withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: -14,
            right: -10,
            child: RaminhoNatus(tamanho: 78, opacity: 0.10),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B3A44),
                ),
              ),
              const SizedBox(height: 14),
              ...valorOuFilhos,
            ],
          ),
        ],
      ),
    );
  }

  return CardOrganicoNatus(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: (cor ?? const Color(0xFF7B3A44)).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icone ?? Icons.analytics_rounded,
            color: cor ?? const Color(0xFF7B3A44),
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                valorOuFilhos.toString(),
                style: const TextStyle(
                  color: Color(0xFF7B3A44),
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
