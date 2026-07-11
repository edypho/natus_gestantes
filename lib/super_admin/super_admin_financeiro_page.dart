import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';
import 'super_admin_lists.dart';

class SuperAdminFinanceiroPage extends StatelessWidget {
  const SuperAdminFinanceiroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminPageScaffold(
      titulo: 'Financeiro das assinaturas SaaS',
      subtitulo: 'Resumo financeiro da plataforma SaaS.',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('assinaturasSaaS')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          double total = 0;

          for (final doc in docs) {
            final valor = doc.data()['valor'];
            if (valor is num) total += valor.toDouble();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receita mensal prevista: R\$ ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B3A44),
                ),
              ),
              const SizedBox(height: 20),
              ...docs.map((doc) {
                final data = doc.data();

                return superAdminListTile(
                  titulo: data['clinicaNome']?.toString() ?? 'Clínica',
                  subtitulo:
                      'Plano: ${data['plano'] ?? '-'} • Valor: R\$ ${data['valor'] ?? '-'} • Status: ${data['status'] ?? '-'}',
                  icone: Icons.payments,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
