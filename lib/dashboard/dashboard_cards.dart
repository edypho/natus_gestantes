import 'package:flutter/material.dart';

class DashboardCards extends StatelessWidget {
  final List<Widget> children;

  const DashboardCards({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: children,
    );
  }
}
