import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';
import 'super_admin_stats.dart';
import 'super_admin_widgets.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminPageScaffold(
      titulo: 'Visão geral da plataforma',
      subtitulo:
          'Acompanhe a operação comercial da Natus sem acessar dados clínicos.',
      icone: Icons.dashboard_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SuperAdminSectionTitle(
            titulo: 'Indicadores principais',
            descricao: 'Situação atual da base, acessos e assinaturas.',
          ),
          const SizedBox(height: 16),
          const SuperAdminStatsGrid(),
          const SizedBox(height: 30),
          const SuperAdminSectionTitle(
            titulo: 'Clínicas por plano',
            descricao: 'Distribuição comercial das clínicas ativas e em teste.',
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('clinicasSaaS')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SuperAdminStateMessage(
                  mensagem: 'Não foi possível carregar os planos.',
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

              final contagemPorPlano = <String, int>{};
              for (final doc in snapshot.data?.docs ?? []) {
                final dados = doc.data();
                final status = (dados['status'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                if (status != 'ativa' && status != 'teste') continue;
                final plano = (dados['plano'] ?? '').toString().trim();
                final nome = plano.isEmpty ? 'Plano não informado' : plano;
                contagemPorPlano[nome] = (contagemPorPlano[nome] ?? 0) + 1;
              }

              final planos = contagemPorPlano.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              if (planos.isEmpty) {
                return const SuperAdminStateMessage(
                  mensagem: 'Nenhuma clínica ativa possui plano identificado.',
                );
              }

              return SuperAdminResponsiveGrid(
                minItemWidth: 190,
                maxColumns: 4,
                children: planos
                    .map(
                      (item) => superAdminCard(
                        titulo: item.key,
                        valor: '${item.value}',
                        icone: Icons.workspace_premium_rounded,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
