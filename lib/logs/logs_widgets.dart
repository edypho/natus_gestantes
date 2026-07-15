import 'package:flutter/material.dart';

Widget logAdministrativoCard({
  required String acao,
  required String usuario,
  required String data,
  String? detalhe,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(acao, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Usuário: $usuario'),
              Text('Data: $data'),
              if (detalhe != null && detalhe.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(detalhe),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
