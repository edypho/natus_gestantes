import 'package:flutter/material.dart';

import 'natus_app.dart';

class FundoPremiumNatus extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FundoPremiumNatus({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NatusApp.creme, Color(0xFFFFFBF7), Color(0xFFF8E8E0)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -110,
            top: -95,
            child: BolhaOrganicaNatus(tamanho: 270, opacity: 0.12),
          ),
          const Positioned(
            left: -120,
            bottom: -120,
            child: BolhaOrganicaNatus(tamanho: 310, opacity: 0.09),
          ),
          const Positioned(
            right: 28,
            bottom: 24,
            child: FolhasLinearesNatus(
              tamanho: 145,
              opacity: 0.12,
              rotacao: -0.16,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class BolhaOrganicaNatus extends StatelessWidget {
  final double tamanho;
  final double opacity;
  final Color? color;

  const BolhaOrganicaNatus({
    super.key,
    this.tamanho = 220,
    this.opacity = 0.12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            color: color ?? NatusApp.rose,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(tamanho * 0.58),
              topRight: Radius.circular(tamanho * 0.40),
              bottomLeft: Radius.circular(tamanho * 0.36),
              bottomRight: Radius.circular(tamanho * 0.62),
            ),
          ),
        ),
      ),
    );
  }
}

class FolhasLinearesNatus extends StatelessWidget {
  final double tamanho;
  final double opacity;
  final double rotacao;
  final Color? color;

  const FolhasLinearesNatus({
    super.key,
    this.tamanho = 120,
    this.opacity = 0.22,
    this.rotacao = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotacao,
          child: CustomPaint(
            size: Size(tamanho, tamanho),
            painter: _FolhasLinearesPainter(color ?? NatusApp.douradoSuave),
          ),
        ),
      ),
    );
  }
}

class _FolhasLinearesPainter extends CustomPainter {
  final Color color;

  _FolhasLinearesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Direção "editorial sereno": folhas lineares desativadas (no-op).
  }

  @override
  bool shouldRepaint(covariant _FolhasLinearesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class HeaderPremiumNatus extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icone;

  const HeaderPremiumNatus({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.icone = Icons.spa_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinho.withValues(alpha: 0.055),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -10,
            top: -18,
            child: FolhasLinearesNatus(
              tamanho: 108,
              opacity: 0.12,
              rotacao: -0.35,
            ),
          ),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [NatusApp.marsala, NatusApp.vinhoProfundo],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icone, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: NatusApp.vinho,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: NatusApp.textoSuave,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
