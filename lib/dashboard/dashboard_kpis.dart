import 'package:flutter/material.dart';

class DashboardKPIs extends StatelessWidget {
  final List<Widget> children;

  const DashboardKPIs({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}
