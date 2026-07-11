import 'package:flutter/material.dart';

/// Assets botânicos seguros para Flutter Web.
///
/// Importante: não usamos mais base64 neste arquivo. Imagens grandes em base64
/// quebravam o CanvasKit no web. Agora tudo deve vir de assets reais em
/// assets/Ramos/ registrados no pubspec.yaml.
class NatusBotanicalImage extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final double opacity;
  final BoxFit fit;

  const NatusBotanicalImage({
    super.key,
    this.asset = 'assets/Ramos/1.png',
    this.width,
    this.height,
    this.opacity = 0.12,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          asset,
          width: width,
          height: height,
          fit: fit,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
