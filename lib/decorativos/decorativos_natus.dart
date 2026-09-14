import 'package:flutter/material.dart';

import '../shared/natus_premium_visual.dart';

class RaminhoNatus extends StatelessWidget {
  final Alignment alignment;
  final double opacity;
  final double tamanho;

  const RaminhoNatus({
    super.key,
    this.alignment = Alignment.topRight,
    this.opacity = 0.14,
    this.tamanho = 86,
  });

  @override
  Widget build(BuildContext context) {
    // Direção "editorial sereno": raminhos removidos dos cards.
    // Widget neutralizado para preservar os call sites.
    return const SizedBox.shrink();
  }
}

class FundoTelaNatus extends StatelessWidget {
  final Widget child;

  const FundoTelaNatus({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBFC), Color(0xFFF8EEF1)],
        ),
      ),
      child: child,
    );
  }
}

class CardOrganicoNatus extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const CardOrganicoNatus({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 245,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF8D9A7A).withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B3A44).withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -16,
            top: -18,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.cardLeaf,
              width: 112,
              opacity: 0.18,
            ),
          ),
          const Positioned(
            left: -24,
            bottom: -28,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.branchSmall,
              width: 94,
              opacity: 0.09,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
