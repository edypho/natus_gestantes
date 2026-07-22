import 'package:flutter/material.dart';

import 'super_admin_access_widgets.dart';
import 'super_admin_layout.dart';
import 'super_admin_lists.dart';
import 'super_admin_repository.dart';

class SuperAdminUsuariosPage extends StatelessWidget {
  const SuperAdminUsuariosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SuperAdminRepository();

    return SuperAdminPageScaffold(
      titulo: 'Usuários/clientes SaaS',
      subtitulo: 'Gestão de usuários SaaS, admins e contas vinculadas.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Listagem e acompanhamento dos usuários SaaS cadastrados.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SuperAdminFirestoreList(
            collection: 'usuariosSaaS',
            emptyText: 'Nenhum usuário SaaS cadastrado ainda.',
            itemBuilder: (context, doc) {
              final data = doc.data();
              final status = data['status']?.toString() ?? 'ativo';
              final nome = data['nome']?.toString() ?? 'Usuário sem nome';
              final excluidoLogicamente = data['excluidoLogicamente'] == true;

              return superAdminListTile(
                titulo: nome,
                subtitulo:
                    '${data['email'] ?? '-'} • Tipo: ${data['tipo'] ?? '-'} • Clínica: ${data['clinicaId'] ?? '-'}',
                icone: Icons.people,
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    superAdminStatusBadge(status),
                    OutlinedButton(
                      onPressed: status == 'bloqueado'
                          ? null
                          : () async {
                              final ok = await confirmarAcaoSuperAdmin(
                                context: context,
                                titulo: 'Bloquear usuário',
                                mensagem: 'Deseja bloquear o acesso de $nome?',
                              );

                              if (!ok) return;

                              await repo.alterarStatusUsuarioSaaS(
                                usuarioId: doc.id,
                                status: 'bloqueado',
                              );
                            },
                      child: const Text('Bloquear'),
                    ),
                    ElevatedButton(
                      onPressed: status == 'ativo'
                          ? null
                          : () async {
                              await repo.alterarStatusUsuarioSaaS(
                                usuarioId: doc.id,
                                status: 'ativo',
                              );
                            },
                      child: const Text('Reativar'),
                    ),
                    TextButton(
                      onPressed: excluidoLogicamente
                          ? null
                          : () async {
                              final ok = await confirmarAcaoSuperAdmin(
                                context: context,
                                titulo: 'Arquivar usuário',
                                mensagem:
                                    'O acesso de $nome será bloqueado e o cadastro ficará preservado para auditoria ou reativação.',
                              );

                              if (!ok) return;

                              await repo.excluirUsuarioSaaSLogicamente(
                                usuarioId: doc.id,
                              );
                            },
                      child: const Text('Arquivar'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
