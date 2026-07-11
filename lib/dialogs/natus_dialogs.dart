import 'package:flutter/material.dart';

void mostrarSnackNatus(
  BuildContext context,
  String mensagem,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensagem),
    ),
  );
}

Future<bool> confirmarAcaoNatus({
  required BuildContext context,
  required String titulo,
  required String mensagem,
  String textoCancelar = 'Cancelar',
  String textoConfirmar = 'Confirmar',
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
            child: Text(textoCancelar),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(textoConfirmar),
          ),
        ],
      );
    },
  );

  return resposta == true;
}

Future<void> alertaNatus({
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
