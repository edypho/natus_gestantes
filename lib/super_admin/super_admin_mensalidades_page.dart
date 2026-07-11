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
      titulo: 'Mensalidades atrasadas SaaS',
      subtitulo: 'Acompanhamento de assinaturas vencidas e risco de bloqueio.',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.streamMensalidadesAtrasadas(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Text('Nenhuma mensalidade atrasada no momento.');
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
