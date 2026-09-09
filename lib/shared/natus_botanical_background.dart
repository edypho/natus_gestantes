import 'package:flutter/material.dart';

class NatusBotanicalBackground extends StatelessWidget {
  final Widget child;

  const NatusBotanicalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF7), Color(0xFFFFF6F1), Color(0xFFFBEDE5)],
        ),
      ),
      child: child,
    );
  }
}
