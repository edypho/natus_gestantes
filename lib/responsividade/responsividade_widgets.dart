import 'package:flutter/material.dart';

import '../core/natus_breakpoints.dart';

bool isMobile(BuildContext context) {
  return NatusBreakpoints.usarLayoutCompacto(context);
}

int gridResponsivo(BuildContext context) {
  final largura = MediaQuery.of(context).size.width;

  if (largura >= 1600) return 5;
  if (largura >= 1200) return 4;
  if (largura >= 900) return 3;
  if (largura >= 600) return 2;

  return 1;
}

double larguraResponsivaCard(BuildContext context) {
  final largura = MediaQuery.of(context).size.width;

  if (largura >= 1400) return 340;
  if (largura >= 1000) return 300;
  if (largura >= 700) return 260;

  return double.infinity;
}
