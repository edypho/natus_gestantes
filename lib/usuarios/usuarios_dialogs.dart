import 'package:flutter/material.dart';

import '../shared/saas_constantes.dart';

typedef CampoUsuarioBuilder =
    Widget Function(TextEditingController controller, String label);

Future<void> abrirPopupCriarUsuarioDialog({
  required BuildContext context,
  required CampoUsuarioBuilder campoBuilder,
  required TextEditingController novoNomeController,
  required TextEditingController novoEmailController,
  required String novoTipoUsuarioInicial,
  required String? gestanteSelecionadaInicial,
  required String? enfermeiraSelecionadaInicial,
  required List<Map<String, String>>
  gestantes, // PATCH91B_DROPDOWN_GESTANTES_SEGURO
  required List<Map<String, String>> enfermeiras,
  required void Function(String value) onTipoUsuarioChanged,
  required void Function(String? value) onGestanteSelecionadaChanged,
  required void Function(String? value) onEnfermeiraSelecionadaChanged,
  required Future<void> Function() onCriarUsuario,
}) async {
  var novoTipoUsuarioLocal = novoTipoUsuarioInicial;
  var gestanteSelecionadaLocal = gestanteSelecionadaInicial;
  var enfermeiraSelecionadaLocal = enfermeiraSelecionadaInicial;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStatePopup) {
          return AlertDialog(
            title: const Text('Criar novo usuário'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  campoBuilder(novoNomeController, 'Nome'),

                  const SizedBox(height: 16),

                  campoBuilder(novoEmailController, 'E-mail'),

                  const SizedBox(height: 16),

                  TextField(
                    enabled: false,
                    controller: TextEditingController(
                      text: 'Link seguro enviado por e-mail',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Definição da senha',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: novoTipoUsuarioLocal,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de usuário',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const [
                          NatusPerfis.admin,
                          NatusPerfis.enfermeira,
                          NatusPerfis.gestante,
                        ].map((tipo) {
                          return DropdownMenuItem(
                            value: tipo,
                            child: Text(tipo),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setStatePopup(() {
                        novoTipoUsuarioLocal = value;
                        gestanteSelecionadaLocal = null;
                        enfermeiraSelecionadaLocal = null;
                      });

                      onTipoUsuarioChanged(value);
                    },
                  ),

                  if (novoTipoUsuarioLocal == NatusPerfis.gestante) ...[
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: gestanteSelecionadaLocal,
                      decoration: const InputDecoration(
                        labelText: 'Selecionar gestante',
                        border: OutlineInputBorder(),
                      ),
                      items: gestantes
                          .where(
                            (g) =>
                                g['uidGestante'] == null ||
                                g['uidGestante'] == '',
                          )
                          .map(
                            (g) => DropdownMenuItem(
                              value: g['id'],
                              child: Text(g['nomeGestante'] ?? 'Sem nome'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStatePopup(() {
                          gestanteSelecionadaLocal = value;
                        });

                        onGestanteSelecionadaChanged(value);
                      },
                    ),
                  ],

                  if (novoTipoUsuarioLocal == NatusPerfis.enfermeira) ...[
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: enfermeiraSelecionadaLocal,
                      decoration: const InputDecoration(
                        labelText: 'Selecionar enfermeira',
                        border: OutlineInputBorder(),
                      ),
                      items: enfermeiras
                          .where(
                            (e) =>
                                e['uidEnfermeira'] == null ||
                                e['uidEnfermeira'] == '',
                          )
                          .map(
                            (e) => DropdownMenuItem(
                              value: e['id'],
                              child: Text(e['nome'] ?? 'Sem nome'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStatePopup(() {
                          enfermeiraSelecionadaLocal = value;
                        });

                        onEnfermeiraSelecionadaChanged(value);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await onCriarUsuario();
                },
                child: const Text('Criar'),
              ),
            ],
          );
        },
      );
    },
  );
}
