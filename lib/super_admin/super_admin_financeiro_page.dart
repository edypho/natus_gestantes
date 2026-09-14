import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';
import 'super_admin_lists.dart';
import 'super_admin_widgets.dart';

class SuperAdminFinanceiroPage extends StatelessWidget {
  const SuperAdminFinanceiroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminPageScaffold(
      titulo: 'Financeiro de assinaturas',
      subtitulo: 'Receita prevista e situação comercial das assinaturas.',
      icone: Icons.payments_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('assinaturasSaaS')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SuperAdminStateMessage(
              mensagem: 'Não foi possível carregar as assinaturas.',
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
          final receitaTotal = docs.fold<double>(0, (total, doc) {
            final valor = doc.data()['valor'];
            return total + (valor is num ? valor.toDouble() : 0);
          });
          final ativas = docs.where((doc) {
            final status = _status(doc.data()['status']);
            return status == 'ativa' || status == 'teste';
          }).length;
          final pendentes = docs.where((doc) {
            return const {
              'vencida',
              'bloqueada',
            }.contains(_status(doc.data()['status']));
          }).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SuperAdminResponsiveGrid(
                minItemWidth: 210,
                maxColumns: 3,
                children: [
                  superAdminCard(
                    titulo: 'Receita mensal prevista',
                    valor: _moeda(receitaTotal),
                    icone: Icons.attach_money_rounded,
                  ),
                  superAdminCard(
                    titulo: 'Assinaturas ativas',
                    valor: '$ativas',
                    icone: Icons.verified_rounded,
                  ),
                  superAdminCard(
                    titulo: 'Assinaturas pendentes',
                    valor: '$pendentes',
                    icone: Icons.warning_amber_rounded,
                    destaque: Colors.orange.shade800,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const SuperAdminSectionTitle(
                titulo: 'Assinaturas',
                descricao: 'Valores, planos e situação de cada clínica.',
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const SuperAdminStateMessage(
                  mensagem: 'Nenhuma assinatura foi cadastrada ainda.',
                )
              else
                ...docs.map((doc) {
                  final data = doc.data();
                  final status = data['status']?.toString() ?? 'sem status';
                  final valor = data['valor'];
                  final valorNumerico = valor is num
                      ? valor.toDouble()
                      : double.tryParse(valor?.toString() ?? '') ?? 0;

                  return superAdminListTile(
                    titulo: data['clinicaNome']?.toString() ?? 'Clínica',
                    subtitulo:
                        'Plano: ${data['plano'] ?? 'Não informado'} • ${_moeda(valorNumerico)} por mês',
                    icone: Icons.receipt_long_rounded,
                    trailing: _StatusAssinatura(status: status),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _StatusAssinatura extends StatelessWidget {
  const _StatusAssinatura({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizado = _status(status);
    final cor = switch (normalizado) {
      'ativa' || 'teste' => Colors.green.shade700,
      'vencida' || 'bloqueada' => Colors.red.shade700,
      _ => Colors.grey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _status(dynamic valor) => (valor ?? '').toString().trim().toLowerCase();

String _moeda(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  return 'R\$ ${partes.first},${partes.last}';
}
