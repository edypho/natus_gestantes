import 'package:flutter/material.dart';

import 'super_admin_auth_config.dart';
import 'super_admin_repository.dart';

Future<void> superAdminCriarClinicaComAdminDialog({
  required BuildContext context,
}) async {
  final repo = SuperAdminRepository();

  final nomeClinicaController = TextEditingController();
  final nomeAdminController = TextEditingController();
  final emailAdminController = TextEditingController();
  final senhaTemporariaController = TextEditingController(
    text: SuperAdminAuthConfig.senhaTemporariaPadrao,
  );
  final valorController = TextEditingController(text: '597');

  String planoSelecionado = 'Clínica Start';

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
                    TextField(
                      controller: senhaTemporariaController,
                      decoration: const InputDecoration(
                        labelText: 'Senha temporária do primeiro acesso',
                        helperText:
                            'Essa senha será criada no Firebase Auth e o admin troca no primeiro login.',
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
                        'O admin da clínica será criado no Firebase Auth '
                        'com a senha temporária informada acima.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
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
                onPressed: () async {
                  final nomeClinica = nomeClinicaController.text.trim();
                  final nomeAdmin = nomeAdminController.text.trim();
                  final emailAdmin = emailAdminController.text.trim();
                  final senhaTemporaria =
                      senhaTemporariaController.text.trim();
                  final valor = double.tryParse(
                        valorController.text.replaceAll(',', '.'),
                      ) ??
                      0;

                  if (nomeClinica.isEmpty ||
                      nomeAdmin.isEmpty ||
                      emailAdmin.isEmpty ||
                      senhaTemporaria.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Preencha clínica, nome, e-mail e senha temporária.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (senhaTemporaria.length <
                      SuperAdminAuthConfig.tamanhoMinimoSenha) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'A senha precisa ter pelo menos '
                          '${SuperAdminAuthConfig.tamanhoMinimoSenha} caracteres.',
                        ),
                      ),
                    );
                    return;
                  }

                  await repo.criarClinicaComAdmin(
                    nomeClinica: nomeClinica,
                    nomeAdmin: nomeAdmin,
                    emailAdmin: emailAdmin,
                    plano: planoSelecionado,
                    valorAssinatura: valor,
                    senhaTemporaria: senhaTemporaria,
                  );

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
                            'E-mail: $emailAdmin\n'
                            'Senha temporária: $senhaTemporaria\n\n'
                            'O cliente deve trocar a senha no primeiro acesso.',
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
