import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> abrirTrocaSenhaPrimeiroLoginSaaS({
  required BuildContext context,
  required String uid,
}) async {
  final senhaController = TextEditingController();
  final confirmarController = TextEditingController();

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Alterar senha obrigatória'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Por segurança, altere a senha temporária antes de continuar.'),
              const SizedBox(height: 16),
              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova senha',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmarController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final senha = senhaController.text.trim();
              final confirmar = confirmarController.text.trim();

              if (senha.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A senha precisa ter pelo menos 6 caracteres.')),
                );
                return;
              }

              if (senha != confirmar) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('As senhas não conferem.')),
                );
                return;
              }

              await FirebaseAuth.instance.currentUser?.updatePassword(senha);

              await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
                'primeiroLogin': false,
                'senhaTemporaria': '',
                'senhaAlteradaEm': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              await FirebaseFirestore.instance.collection('usuariosSaaS').doc(uid).set({
                'primeiroLogin': false,
                'senhaTemporaria': '',
                'senhaAlteradaEm': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Salvar nova senha'),
          ),
        ],
      );
    },
  );
}
