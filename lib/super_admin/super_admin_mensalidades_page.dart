import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';
import 'super_admin_lists.dart';
import 'super_admin_repository.dart';

class SuperAdminMensalidadesPage extends StatelessWidget {
  const SuperAdminMensalidadesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SuperAdminRepository();

    return SuperAdminPageScaffold(
      titulo: 'Mensalidades em atraso',
      subtitulo: 'Pendências financeiras que precisam de acompanhamento.',
      icone: Icons.warning_amber_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.streamMensalidadesAtrasadas(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SuperAdminStateMessage(
              mensagem: 'Não foi possível carregar as mensalidades.',
              icone: Icons.cloud_off_rounded,
              erro: true,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const SuperAdminStateMessage(
              mensagem: 'Nenhuma mensalidade está em atraso no momento.',
              icone: Icons.check_circle_outline_rounded,
            );
          }

          return Column(
            children: docs.map((doc) {
              final data = doc.data();

              return superAdminListTile(
                titulo: data['clinicaNome']?.toString() ?? 'Clínica',
                subtitulo:
                    'Plano: ${data['plano'] ?? '-'} • Valor: R\$ ${data['valor'] ?? '-'} • Status: ${data['status'] ?? '-'}',
                icone: Icons.warning_amber_rounded,
                trailing: ElevatedButton(
                  onPressed: () async {
                    await repo.alterarStatusAssinatura(
                      assinaturaId: doc.id,
                      status: 'ativa',
                    );
                  },
                  child: const Text('Regularizar'),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
