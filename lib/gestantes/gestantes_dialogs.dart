import 'package:flutter/material.dart';

Future<bool?> confirmarExclusaoGestanteDialog({
  required BuildContext context,
  required String nomeGestante,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Excluir paciente'),
        content: Text(
          'Tem certeza que deseja excluir ${nomeGestante.trim().isEmpty ? 'este paciente' : nomeGestante}? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      );
    },
  );
}

Future<void> avisoGestanteDialog({
  required BuildContext context,
  required String titulo,
  required String mensagem,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

Future<void> confirmarStatusGestanteDialog({
  required BuildContext context,
  required String titulo,
  required String mensagem,
  required VoidCallback onConfirmar,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirmar();
            },
            child: const Text('Confirmar'),
          ),
        ],
      );
    },
  );
}
