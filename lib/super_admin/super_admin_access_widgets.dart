import 'package:flutter/material.dart';

Color superAdminStatusColor(String status) {
  switch (status) {
    case 'ativa':
    case 'ativo':
      return Colors.green;
    case 'teste':
      return Colors.blueGrey;
    case 'pausada':
      return Colors.orange;
    case 'bloqueada':
    case 'bloqueado':
      return Colors.red;
    case 'excluida':
    case 'excluido':
      return Colors.black54;
    default:
      return const Color(0xFF7B3A44);
  }
}

Widget superAdminStatusBadge(String status) {
  final cor = superAdminStatusColor(status);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: cor.withValues(alpha: 0.25)),
    ),
    child: Text(
      status.isEmpty ? 'sem status' : status,
      style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
    ),
  );
}

Future<bool> confirmarAcaoSuperAdmin({
  required BuildContext context,
  required String titulo,
  required String mensagem,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      );
    },
  );

  return resposta == true;
}
