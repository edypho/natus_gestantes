import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';
import 'super_admin_widgets.dart';

class SuperAdminStatsGrid extends StatelessWidget {
  const SuperAdminStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('clinicasSaaS').snapshots(),
      builder: (context, clinicasSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('usuariosSaaS').snapshots(),
          builder: (context, usuariosSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('assinaturasSaaS').snapshots(),
              builder: (context, assinaturasSnapshot) {
                if (clinicasSnapshot.hasError ||
                    usuariosSnapshot.hasError ||
                    assinaturasSnapshot.hasError) {
                  return const SuperAdminStateMessage(
                    mensagem: 'Não foi possível carregar os indicadores.',
                    icone: Icons.cloud_off_rounded,
                    erro: true,
                  );
                }

                final carregando =
                    clinicasSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    usuariosSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    assinaturasSnapshot.connectionState ==
                        ConnectionState.waiting;
                if (carregando) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final clinicas = clinicasSnapshot.data?.docs ?? [];
                final usuarios = usuariosSnapshot.data?.docs ?? [];
                final assinaturas = assinaturasSnapshot.data?.docs ?? [];
                final ativas = clinicas.where((doc) {
                  final status = _texto(doc.data()['status']);
                  return status == 'ativa' || status == 'teste';
                }).length;
                final bloqueadas = clinicas
                    .where((doc) => _texto(doc.data()['status']) == 'bloqueada')
                    .length;
                final usuariosBloqueados = usuarios
                    .where((doc) => _texto(doc.data()['status']) == 'bloqueado')
                    .length;
                final atrasadas = assinaturas.where((doc) {
                  return const {
                    'vencida',
                    'bloqueada',
                  }.contains(_texto(doc.data()['status']));
                }).length;
                final receita = assinaturas.fold<double>(0, (total, doc) {
                  final valor = doc.data()['valor'];
                  return total + (valor is num ? valor.toDouble() : 0);
                });

                return SuperAdminResponsiveGrid(
                  minItemWidth: 205,
                  maxColumns: 3,
                  children: [
                    superAdminCard(
                      titulo: 'Clínicas ativas ou em teste',
                      valor: '$ativas',
                      icone: Icons.apartment_rounded,
                    ),
                    superAdminCard(
                      titulo: 'Clínicas bloqueadas',
                      valor: '$bloqueadas',
                      icone: Icons.block_rounded,
                      destaque: Colors.red.shade700,
                    ),
                    superAdminCard(
                      titulo: 'Usuários cadastrados',
                      valor: '${usuarios.length}',
                      icone: Icons.people_alt_rounded,
                    ),
                    superAdminCard(
                      titulo: 'Usuários bloqueados',
                      valor: '$usuariosBloqueados',
                      icone: Icons.person_off_rounded,
                      destaque: Colors.orange.shade800,
                    ),
                    superAdminCard(
                      titulo: 'Mensalidades pendentes',
                      valor: '$atrasadas',
                      icone: Icons.warning_amber_rounded,
                      destaque: Colors.orange.shade800,
                    ),
                    superAdminCard(
                      titulo: 'Receita mensal prevista',
                      valor: _moeda(receita),
                      icone: Icons.payments_rounded,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

String _texto(dynamic valor) => (valor ?? '').toString().trim().toLowerCase();

String _moeda(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  return 'R\$ ${partes.first},${partes.last}';
}
