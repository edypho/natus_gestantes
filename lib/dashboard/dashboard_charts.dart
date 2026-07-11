import 'package:flutter/material.dart';

class DashboardCharts extends StatelessWidget {
  final List<Widget> children;

  const DashboardCharts({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children,
    );
  }
}
