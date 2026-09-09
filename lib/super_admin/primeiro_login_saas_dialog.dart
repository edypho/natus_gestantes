import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../seguranca/log_seguro.dart';

Future<bool> abrirTrocaSenhaPrimeiroLoginSaaS({
  required BuildContext context,
  required String uid,
}) async {
  final senhaController = TextEditingController();
  final confirmarController = TextEditingController();

  final resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var salvando = false;

      return PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Alterar senha obrigatória'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Por segurança, altere a senha temporária antes de continuar.',
                    ),
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
                  onPressed: salvando
                      ? null
                      : () async {
                          final senha = senhaController.text.trim();
                          final confirmar = confirmarController.text.trim();

                          if (senha.length < 12) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'A senha precisa ter pelo menos 12 caracteres.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (senha != confirmar) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('As senhas não conferem.'),
                              ),
                            );
                            return;
                          }

                          setStateDialog(() => salvando = true);
                          var concluiu = false;
                          try {
                            final usuario = FirebaseAuth.instance.currentUser;
                            if (usuario == null || usuario.uid != uid) {
                              throw StateError(
                                'A sessão autenticada não corresponde ao usuário.',
                              );
                            }

                            await usuario.updatePassword(senha);

                            final usuarioRef = FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(uid);
                            await usuarioRef.update({
                              'primeiroLogin': false,
                              'senhaAlteradaEm': FieldValue.serverTimestamp(),
                            });
                            final confirmacao = await usuarioRef.get(
                              const GetOptions(source: Source.server),
                            );
                            if (confirmacao.data()?['primeiroLogin'] != false) {
                              throw StateError(
                                'A troca de senha não foi confirmada pelo servidor.',
                              );
                            }

                            concluiu = true;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (e) {
                            logErroSeguro(
                              'Erro ao alterar a senha inicial.',
                              e,
                            );
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Não foi possível alterar a senha.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (!concluiu && dialogContext.mounted) {
                              setStateDialog(() => salvando = false);
                            }
                          }
                        },
                  child: Text(salvando ? 'Salvando...' : 'Salvar nova senha'),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  senhaController.dispose();
  confirmarController.dispose();
  return resultado == true;
}
