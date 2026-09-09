import 'package:flutter/material.dart';

import 'dashboard_cards.dart';
import 'dashboard_charts.dart';
import 'dashboard_kpis.dart';

class DashboardPage extends StatelessWidget {
  final List<Widget> cards;
  final List<Widget> charts;
  final List<Widget> kpis;

  const DashboardPage({
    super.key,
    required this.cards,
    required this.charts,
    required this.kpis,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardKPIs(children: kpis),
          const SizedBox(height: 18),
          DashboardCards(children: cards),
          const SizedBox(height: 18),
          DashboardCharts(children: charts),
        ],
      ),
    );
  }
}
