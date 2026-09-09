import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';
import 'super_admin_widgets.dart';

class SuperAdminCrescimentoPage extends StatelessWidget {
  const SuperAdminCrescimentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminPageScaffold(
      titulo: 'Crescimento da plataforma',
      subtitulo: 'Evolução da base de usuários em períodos comparáveis.',
      icone: Icons.trending_up_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuariosSaaS')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SuperAdminStateMessage(
              mensagem: 'Não foi possível carregar o crescimento.',
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
          final agora = DateTime.now();
          final inicioMes = DateTime(agora.year, agora.month);
          final inicioMesAnterior = DateTime(agora.year, agora.month - 1);
          final ultimos30Dias = agora.subtract(const Duration(days: 30));

          final datas = docs
              .map((doc) => _data(doc.data()['criadoEm']))
              .whereType<DateTime>()
              .toList();
          final noMes = datas.where((data) => !data.isBefore(inicioMes)).length;
          final mesAnterior = datas.where((data) {
            return !data.isBefore(inicioMesAnterior) &&
                data.isBefore(inicioMes);
          }).length;
          final nosUltimos30 = datas
              .where((data) => !data.isBefore(ultimos30Dias))
              .length;
          final variacao = mesAnterior == 0
              ? (noMes == 0 ? '0%' : 'nova base')
              : '${(((noMes - mesAnterior) / mesAnterior) * 100).toStringAsFixed(0)}%';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SuperAdminResponsiveGrid(
                minItemWidth: 205,
                maxColumns: 4,
                children: [
                  superAdminCard(
                    titulo: 'Total de usuários',
                    valor: '${docs.length}',
                    icone: Icons.people_alt_rounded,
                  ),
                  superAdminCard(
                    titulo: 'Novos neste mês',
                    valor: '$noMes',
                    icone: Icons.person_add_alt_1_rounded,
                  ),
                  superAdminCard(
                    titulo: 'Novos nos últimos 30 dias',
                    valor: '$nosUltimos30',
                    icone: Icons.calendar_month_rounded,
                  ),
                  superAdminCard(
                    titulo: 'Variação sobre o mês anterior',
                    valor: variacao,
                    icone: Icons.trending_up_rounded,
                  ),
                ],
              ),
              if (datas.length != docs.length) ...[
                const SizedBox(height: 18),
                SuperAdminStateMessage(
                  mensagem:
                      '${docs.length - datas.length} cadastro(s) antigo(s) não possuem data e aparecem apenas no total.',
                  icone: Icons.info_outline_rounded,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

DateTime? _data(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}
