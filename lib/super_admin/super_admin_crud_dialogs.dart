import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/sessao_idempotencia.dart';
import '../seguranca/log_seguro.dart';
import 'super_admin_repository.dart';

Future<void> superAdminCriarClinicaComAdminDialog({
  required BuildContext context,
}) async {
  final repo = SuperAdminRepository();

  final nomeClinicaController = TextEditingController();
  final nomeAdminController = TextEditingController();
  final emailAdminController = TextEditingController();
  final valorController = TextEditingController(text: '597');
  final sessaoCriacaoClinica = SessaoIdempotencia();

  String planoSelecionado = 'Clínica Start';
  var salvando = false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Criar clínica SaaS + admin'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeClinicaController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da clínica',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomeAdminController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do admin responsável',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailAdminController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail do admin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: planoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Plano SaaS',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Clínica Start',
                          child: Text('Clínica Start'),
                        ),
                        DropdownMenuItem(
                          value: 'Clínica Premium',
                          child: Text('Clínica Premium'),
                        ),
                        DropdownMenuItem(
                          value: 'Natus Interno',
                          child: Text('Natus Interno'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setStateDialog(() {
                          planoSelecionado = value;

                          if (value == 'Clínica Premium') {
                            valorController.text = '997';
                          } else if (value == 'Natus Interno') {
                            valorController.text = '0';
                          } else {
                            valorController.text = '597';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Valor mensal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EEF1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'O admin definirá a própria senha por um link seguro '
                        'enviado ao e-mail informado.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: salvando
                    ? null
                    : () async {
                        final nomeClinica = nomeClinicaController.text.trim();
                        final nomeAdmin = nomeAdminController.text.trim();
                        final emailAdmin = emailAdminController.text.trim();
                        final valor =
                            double.tryParse(
                              valorController.text.replaceAll(',', '.'),
                            ) ??
                            0;

                        if (nomeClinica.isEmpty ||
                            nomeAdmin.isEmpty ||
                            emailAdmin.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preencha clínica, nome e e-mail.'),
                            ),
                          );
                          return;
                        }

                        setStateDialog(() => salvando = true);
                        late final bool conviteEnviado;
                        try {
                          final operacaoId = sessaoCriacaoClinica
                              .idParaAssinatura(
                                jsonEncode([
                                  nomeClinica,
                                  nomeAdmin,
                                  emailAdmin.toLowerCase(),
                                  planoSelecionado,
                                  valor,
                                ]),
                              );
                          conviteEnviado = await repo.criarClinicaComAdmin(
                            nomeClinica: nomeClinica,
                            nomeAdmin: nomeAdmin,
                            emailAdmin: emailAdmin,
                            plano: planoSelecionado,
                            valorAssinatura: valor,
                            operacaoId: operacaoId,
                          );
                        } catch (e) {
                          logErroSeguro('Erro ao criar clinica.', e);
                          if (context.mounted) {
                            setStateDialog(() => salvando = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Erro ao criar clínica.'),
                              ),
                            );
                          }
                          return;
                        }

                        if (context.mounted) {
                          Navigator.pop(context);

                          await showDialog<void>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Clínica e login criados'),
                                content: Text(
                                  'Clínica: $nomeClinica\n'
                                  'Admin: $nomeAdmin\n'
                                  'E-mail: $emailAdmin\n\n'
                                  '${conviteEnviado ? 'O link seguro para definir a senha foi enviado.' : 'A clínica foi criada, mas o envio do e-mail ficou pendente.'}',
                                ),
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
                      },
                child: const Text('Criar clínica + admin'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> superAdminCriarClinicaDialog({
  required BuildContext context,
}) async {
  await superAdminCriarClinicaComAdminDialog(context: context);
}
