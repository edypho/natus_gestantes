import '../decorativos/decorativos_natus.dart';
import 'package:flutter/material.dart';

Widget gestantesSecaoTitulo({
  required String titulo,
  String? subtitulo,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitulo != null && subtitulo.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget gestantesInfoChip({
  required IconData icone,
  required String texto,
  Color? cor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: (cor ?? Colors.grey).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: (cor ?? Colors.grey).withValues(alpha: 0.25),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icone,
          size: 16,
          color: cor ?? Colors.grey.shade700,
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cor ?? Colors.grey.shade800,
          ),
        ),
      ],
    ),
  );
}

Widget gestantesCardBase({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
}) {
  return Container(
    width: double.infinity,
    padding: padding,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}


Widget gestantesCardOrganicoNatus({
  required Widget child,
}) {
  return CardOrganicoNatus(
    child: child,
  );
}


String gestanteTextoSeguro(
  Map<String, String> gestante,
  String chave,
) {
  final valor = gestante[chave];
  if (valor == null || valor.trim().isEmpty) {
    return '-';
  }
  return valor;
}

bool gestanteEstaAtiva(Map<String, String> gestante) {
  final status = (gestante['statusGestante'] ?? '').trim().toLowerCase();
  return status != 'histórico' &&
      status != 'historico' &&
      status != 'encerrada' &&
      status != 'encerrado';
}

String gestanteStatusSeguro(Map<String, String> gestante) {
  final status = (gestante['statusGestante'] ?? '').trim();
  if (status.isEmpty) {
    return 'Gestante';
  }
  return status;
}
