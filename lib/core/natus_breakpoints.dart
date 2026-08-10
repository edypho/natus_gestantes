import 'package:flutter/widgets.dart';

abstract final class NatusBreakpoints {
  static const double menorLadoTelefone = 600;

  static bool tamanhoDeTelefone(Size tamanho) {
    return tamanho.shortestSide < menorLadoTelefone;
  }

  static bool isPhone(BuildContext context) {
    return tamanhoDeTelefone(MediaQuery.sizeOf(context));
  }

  static bool usarLayoutCompacto(
    BuildContext context, {
    double larguraLimite = 700,
  }) {
    return usarLayoutCompactoParaTamanho(
      MediaQuery.sizeOf(context),
      larguraLimite: larguraLimite,
    );
  }

  static bool usarLayoutCompactoParaTamanho(
    Size tamanho, {
    double larguraLimite = 700,
  }) {
    return tamanho.width < larguraLimite || tamanhoDeTelefone(tamanho);
  }
}
