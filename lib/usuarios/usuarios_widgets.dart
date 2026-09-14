import '../decorativos/decorativos_natus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../shared/natus_app.dart';

Widget usuariosTela({
  required Stream<QuerySnapshot> usuariosStream,
  required VoidCallback onCriarUsuario,
  required VoidCallback onImportar2025,
  required VoidCallback onImportar2026,
  required Future<void> Function(String uid, String tipo) onAlterarTipo,
  required Future<void> Function(String docId, String nome) onExcluirUsuario,
}) {
  return StreamBuilder<QuerySnapshot>(
    stream: usuariosStream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(
          child: Text('Nenhum usuário cadastrado no sistema.'),
        );
      }

      final usuarios = snapshot.data!.docs.where((doc) {
        final dados = doc.data() as Map<String, dynamic>;
        final tipo =
            dados['tipo']?.toString() ?? dados['tipoUsuario']?.toString() ?? '';
        return tipo != 'superAdmin';
      }).toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controle de Usuários',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: NatusApp.vinho,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gerencie os perfis de acesso do sistema Natus.',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: onCriarUsuario,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Criar usuário'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NatusApp.vinho,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onImportar2025,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar XLS 2025'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NatusApp.rose,
                    foregroundColor: NatusApp.vinho,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onImportar2026,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar XLS 2026'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NatusApp.vinho,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...usuarios.map((doc) {
              final dados = doc.data() as Map<String, dynamic>;
              final tipo = dados['tipo'] ?? 'sem tipo';
              final nome = dados['nome'] ?? 'Usuário sem nome';
              final email = dados['email'] ?? 'E-mail não informado';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => onAlterarTipo(doc.id, tipo),
                  leading: CircleAvatar(
                    backgroundColor: NatusApp.rose,
                    child: Icon(Icons.person, color: NatusApp.vinho),
                  ),
                  title: Text(
                    nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$email • Tipo de acesso: $tipo'),
                  trailing: IconButton(
                    tooltip: 'Excluir usuário',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Excluir usuário'),
                            content: Text(
                              'Deseja realmente excluir o usuário $nome?',
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

                      if (confirmar == true) {
                        await onExcluirUsuario(doc.id, nome);
                      }
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

Widget usuariosCardOrganicoNatus({required Widget child}) {
  return CardOrganicoNatus(child: child);
}
