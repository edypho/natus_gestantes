import 'package:flutter/material.dart';

import 'super_admin_access_widgets.dart';
import 'super_admin_layout.dart';
import 'super_admin_lists.dart';
import 'super_admin_repository.dart';

class SuperAdminClinicasPage extends StatelessWidget {
  const SuperAdminClinicasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SuperAdminRepository();

    return SuperAdminPageScaffold(
      titulo: 'Clínicas cadastradas SaaS',
      subtitulo: 'Controle de clínicas/clientes que usam a plataforma Natus.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Listagem e acompanhamento das clínicas SaaS cadastradas.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SuperAdminFirestoreList(
            collection: 'clinicasSaaS',
            emptyText: 'Nenhuma clínica SaaS cadastrada ainda.',
            itemBuilder: (context, doc) {
              final data = doc.data();
              final status = data['status']?.toString() ?? 'teste';
              final nome = data['nome']?.toString() ?? 'Clínica sem nome';

              return superAdminListTile(
                titulo: nome,
                subtitulo:
                    'Plano: ${data['plano'] ?? '-'} • Admin: ${data['emailAdmin'] ?? '-'} • ID: ${doc.id}',
                icone: Icons.apartment,
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    superAdminStatusBadge(status),
                    OutlinedButton(
                      onPressed: status == 'pausada'
                          ? null
                          : () async {
                              final ok = await confirmarAcaoSuperAdmin(
                                context: context,
                                titulo: 'Pausar clínica',
                                mensagem:
                                    'Deseja pausar o acesso da clínica $nome?',
                              );

                              if (!ok) return;

                              await repo.alterarStatusClinica(
                                clinicaId: doc.id,
                                status: 'pausada',
                              );
                            },
                      child: const Text('Pausar'),
                    ),
                    OutlinedButton(
                      onPressed: status == 'bloqueada'
                          ? null
                          : () async {
                              final ok = await confirmarAcaoSuperAdmin(
                                context: context,
                                titulo: 'Bloquear clínica',
                                mensagem:
                                    'Deseja bloquear o acesso da clínica $nome?',
                              );

                              if (!ok) return;

                              await repo.alterarStatusClinica(
                                clinicaId: doc.id,
                                status: 'bloqueada',
                              );
                            },
                      child: const Text('Bloquear'),
                    ),
                    ElevatedButton(
                      onPressed: status == 'ativa'
                          ? null
                          : () async {
                              await repo.alterarStatusClinica(
                                clinicaId: doc.id,
                                status: 'ativa',
                              );
                            },
                      child: const Text('Reativar'),
                    ),
                    TextButton(
                      onPressed: status == 'excluida'
                          ? null
                          : () async {
                              final ok = await confirmarAcaoSuperAdmin(
                                context: context,
                                titulo: 'Desativar clínica',
                                mensagem:
                                    'A clínica $nome será marcada como excluída e perderá o acesso. Os dados serão preservados para auditoria e possível reativação.',
                              );

                              if (!ok) return;

                              await repo.excluirClinicaLogicamente(
                                clinicaId: doc.id,
                              );
                            },
                      child: const Text('Desativar'),
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
