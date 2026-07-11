import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'natus_app.dart';

class PremiumNatusBackground extends StatelessWidget {
  final Widget child;
  final bool mostrarArteGrande;

  const PremiumNatusBackground({
    super.key,
    required this.child,
    this.mostrarArteGrande = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFBF6), Color(0xFFF8F2E8), Color(0xFFF5EBDB)],
          stops: [0.0, 0.58, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Direção "editorial sereno": fundo limpo, profundidade apenas
          // por dois brilhos de cor muito sutis — sem elementos figurativos.
          const Positioned(
            top: -220,
            right: -180,
            child: _SoftOrb(size: 560, color: Color(0xFFD9BC7E), opacity: 0.14),
          ),
          const Positioned(
            bottom: -260,
            left: -200,
            child: _SoftOrb(
              size: 560,
              color: Color(0xFF8A4247),
              opacity: 0.045,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SoftOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}

class NatusBotanicalAssets {
  static const String branchTall = 'assets/Ramos/6.png';
  static const String branchHero = 'assets/Ramos/6.png';
  static const String branchCornerRight = 'assets/Ramos/3.png';
  static const String branchCornerLeft = 'assets/Ramos/4.png';
  static const String branchFine = 'assets/Ramos/5.png';
  static const String leafScatter = 'assets/Ramos/6.png';
  static const String cornerSoft = 'assets/Ramos/7.png';
  static const String cardLeaf = 'assets/Ramos/8.png';
  static const String branchHorizontal = 'assets/Ramos/9.png';
  static const String branchSmall = 'assets/Ramos/10.png';
  static const String branchAccent = 'assets/Ramos/11.png';
}

class NatusBotanicalAsset extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final double opacity;
  final BoxFit fit;
  final double rotation;
  final Alignment alignment;

  const NatusBotanicalAsset({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.opacity = 0.16,
    this.fit = BoxFit.contain,
    this.rotation = 0,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    // Direção "editorial sereno" (jul/2026): elementos botânicos removidos
    // do visual. O widget foi neutralizado em vez de deletado para não
    // alterar os dezenas de call sites — remoção definitiva no Lote 2f.
    return const SizedBox.shrink();
  }

}

class BotanicalNatusPainter extends CustomPainter {
  final Color color;
  final bool mirror;

  const BotanicalNatusPainter({required this.color, this.mirror = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Direção "editorial sereno": desenho botânico desativado.
    // Painter preservado como no-op para não alterar call sites
    // (menus laterais); remoção definitiva no Lote 2f.
  }

  @override
  bool shouldRepaint(covariant BotanicalNatusPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.mirror != mirror;
  }
}

class NatusPremiumShellCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  const NatusPremiumShellCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin = const EdgeInsets.only(bottom: 18),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFFFFCF7).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinho.withValues(alpha: 0.10),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -34,
            top: -38,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.cornerSoft,
              width: 172,
              opacity: 0.105,
            ),
          ),
          const Positioned(
            left: -42,
            bottom: -46,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.branchSmall,
              width: 150,
              opacity: 0.070,
              rotation: -0.18,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class PremiumHeaderNatus extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final List<String> destaques;

  const PremiumHeaderNatus({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.destaques = const [],
  });

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final mobile = largura < 760;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 22 : 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C1C34), Color(0xFF4B0B1C), Color(0xFF310611)],
        ),
        borderRadius: BorderRadius.circular(mobile ? 32 : 42),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinho.withValues(alpha: 0.24),
            blurRadius: 34,
            spreadRadius: -8,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: const Text(
                  'Natus • Cuidado materno e neonatal',
                  style: TextStyle(
                    color: Color(0xFFFFE8E0),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: mobile ? 30 : 44,
                    height: 1.04,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  subtitulo,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: mobile ? 14 : 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (destaques.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: destaques.map((texto) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        texto,
                        style: const TextStyle(
                          color: Color(0xFFFFF4EF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumMetricCardNatus extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const PremiumMetricCardNatus({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icone,
    this.cor = NatusApp.vinho,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 720;

    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 118 : 132),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCF8), Color(0xFFFFF2EA)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.94), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cor.withValues(alpha: 0.12),
            blurRadius: 26,
            spreadRadius: -12,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -34,
            bottom: -30,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.cardLeaf,
              width: 142,
              opacity: 0.20,
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NatusApp.olivaSeco.withValues(alpha: 0.070),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: NatusApp.olivaSeco.withValues(alpha: 0.14),
                  ),
                ),
                child: Icon(icone, color: cor, size: 24),
              ),
              const Spacer(),
              Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cor,
                  fontSize: mobile ? 23 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NatusApp.textoSuave,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumSectionTitle extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData? icone;

  const PremiumSectionTitle({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icone != null) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: NatusApp.olivaSeco.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NatusApp.marsala.withValues(alpha: 0.08)),
            ),
            child: Icon(icone, color: NatusApp.marsala, size: 22),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: NatusApp.vinho,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitulo!,
                  style: const TextStyle(
                    color: NatusApp.textoSuave,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
