import 'package:flutter/material.dart';

import 'super_admin_access_widgets.dart';
import 'super_admin_crud_dialogs.dart';
import 'super_admin_layout.dart';
import 'super_admin_lists.dart';
import 'super_admin_repository.dart';

class SuperAdminClinicasPage extends StatelessWidget {
  const SuperAdminClinicasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SuperAdminRepository();

    return SuperAdminPageScaffold(
      titulo: 'Clínicas',
      subtitulo: 'Controle comercial e situação de acesso de cada clínica.',
      icone: Icons.apartment_rounded,
      actions: [
        FilledButton.icon(
          onPressed: () =>
              superAdminCriarClinicaComAdminDialog(context: context),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Nova clínica'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clínicas cadastradas',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 20),
          SuperAdminFirestoreList(
            collection: 'clinicasSaaS',
            emptyText: 'Nenhuma clínica SaaS cadastrada ainda.',
            itemBuilder: (context, doc) {
              final data = doc.data();
              final status = (data['status'] ?? 'teste')
                  .toString()
                  .trim()
                  .toLowerCase();
              final nome = data['nome']?.toString() ?? 'Clínica sem nome';

              return superAdminListTile(
                titulo: nome,
                subtitulo:
                    'Plano: ${data['plano'] ?? 'Não informado'} • Administrador: ${data['emailAdmin'] ?? 'Não informado'}',
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
