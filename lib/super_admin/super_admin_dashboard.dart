import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/natus_breakpoints.dart';
import 'super_admin_stats.dart';
import 'super_admin_widgets.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard SaaS',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B3A44),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Painel administrativo da plataforma Natus SaaS',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 28),
          const SuperAdminStatsGrid(),
          const SizedBox(height: 28),
          const Text(
            'Clínicas ativas por plano',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B3A44),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Distribuição comercial da base SaaS sem expor dados clínicos.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('clinicasSaaS')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final contagemPorPlano = <String, int>{};

              for (final doc in docs) {
                final dados = doc.data();
                final status = (dados['status'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();

                if (status != 'ativa' && status != 'teste') continue;

                var plano = (dados['plano'] ?? '').toString().trim();
                if (plano.isEmpty) plano = 'Plano não informado';

                contagemPorPlano[plano] = (contagemPorPlano[plano] ?? 0) + 1;
              }

              final planosOrdenados = contagemPorPlano.entries.toList()
                ..sort((a, b) {
                  final porQuantidade = b.value.compareTo(a.value);
                  if (porQuantidade != 0) return porQuantidade;
                  return a.key.toLowerCase().compareTo(b.key.toLowerCase());
                });

              if (planosOrdenados.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'Nenhuma clínica ativa com plano identificado no momento.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final larguraDisponivel = constraints.maxWidth;
                  final isMobile =
                      larguraDisponivel < 700 ||
                      NatusBreakpoints.isPhone(context);
                  const espacamento = 8.0;
                  final totalItens = planosOrdenados.length;
                  final colunas = isMobile
                      ? (larguraDisponivel >= 540 ? 3 : 2).clamp(1, totalItens)
                      : totalItens <= 7
                      ? totalItens
                      : ((larguraDisponivel + espacamento) /
                                (104.0 + espacamento))
                            .floor()
                            .clamp(1, 7);
                  final larguraCard =
                      (larguraDisponivel - ((colunas - 1) * espacamento)) /
                      colunas;

                  return Wrap(
                    spacing: espacamento,
                    runSpacing: espacamento,
                    children: planosOrdenados
                        .map(
                          (item) => superAdminCard(
                            titulo: item.key,
                            valor: '${item.value}',
                            icone: Icons.workspace_premium_rounded,
                            width: larguraCard,
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
