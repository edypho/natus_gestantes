import 'package:flutter/material.dart';

import 'natus_app.dart';

/// Aplica a marca Natus de forma consistente em superficies claras e escuras.
///
/// O arquivo original permanece como fonte unica da logo; a cor e aplicada em
/// tempo de execucao para nao manter copias divergentes do mesmo simbolo.
class NatusLogo extends StatelessWidget {
  const NatusLogo({
    super.key,
    this.color,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  final Color? color;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Natus',
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          color ?? NatusApp.marsala,
          BlendMode.srcIn,
        ),
        child: Image.asset(
          'assets/logo.png',
          height: height,
          width: width,
          fit: fit,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => Text(
            'Natus',
            style: TextStyle(
              color: color ?? NatusApp.marsala,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
