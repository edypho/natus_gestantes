import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_widgets.dart';

class SuperAdminStatsGrid extends StatelessWidget {
  const SuperAdminStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('clinicasSaaS').snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            final ativas = docs.where((doc) {
              final status = doc.data()['status'];
              return status == 'ativa' || status == 'teste';
            }).length;

            return superAdminCard(
              titulo: 'Clínicas ativas/teste SaaS',
              valor: '$ativas',
              icone: Icons.apartment,
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('clinicasSaaS')
              .where('status', isEqualTo: 'pausada')
              .snapshots(),
          builder: (context, snapshot) {
            return superAdminCard(
              titulo: 'Clínicas pausadas SaaS',
              valor: '${snapshot.data?.docs.length ?? 0}',
              icone: Icons.pause_circle,
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('clinicasSaaS')
              .where('status', isEqualTo: 'bloqueada')
              .snapshots(),
          builder: (context, snapshot) {
            return superAdminCard(
              titulo: 'Clínicas bloqueadas SaaS',
              valor: '${snapshot.data?.docs.length ?? 0}',
              icone: Icons.block,
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('usuariosSaaS')
              .where('status', isEqualTo: 'bloqueado')
              .snapshots(),
          builder: (context, snapshot) {
            return superAdminCard(
              titulo: 'Usuários bloqueados SaaS',
              valor: '${snapshot.data?.docs.length ?? 0}',
              icone: Icons.person_off,
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('assinaturasSaaS')
              .where('status', whereIn: ['vencida', 'bloqueada'])
              .snapshots(),
          builder: (context, snapshot) {
            return superAdminCard(
              titulo: 'Mensalidades atrasadas SaaS',
              valor: '${snapshot.data?.docs.length ?? 0}',
              icone: Icons.warning_amber_rounded,
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('assinaturasSaaS').snapshots(),
          builder: (context, snapshot) {
            double total = 0;

            for (final doc in snapshot.data?.docs ?? []) {
              final valor = doc.data()['valor'];
              if (valor is num) {
                total += valor.toDouble();
              }
            }

            return superAdminCard(
              titulo: 'Financeiro assinaturas SaaS',
              valor: 'R\$ ${total.toStringAsFixed(2)}',
              icone: Icons.payments,
            );
          },
        ),
      ],
    );
  }
}
