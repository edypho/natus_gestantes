import '../decorativos/decorativos_natus.dart';
import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import '../shared/formatadores.dart';

Widget dashboardCardAlerta(
  BuildContext context,
  String titulo,
  String valor,
  IconData icone,
  Color cor,
) {
  final isMobile = MediaQuery.of(context).size.width < 700;

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cor.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: cor.withValues(alpha: 0.14),
          child: Icon(icone, color: cor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget dashboardCardFinanceiroResumo(
  BuildContext context,
  String titulo,
  double valor,
  Color cor,
  IconData icone, {
  String sufixo = '',
}) {
  final textoValor = sufixo == '%'
      ? '${valor.toStringAsFixed(1)}%'
      : formatarMoeda(valor);

  final isMobile = MediaQuery.of(context).size.width < 700;

  return Container(
    constraints: const BoxConstraints(minHeight: 118),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cor.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: cor.withValues(alpha: 0.14),
          child: Icon(icone, color: cor, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            textoValor,
            style: TextStyle(
              fontSize: isMobile ? 15 : 17,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget dashboardCardContagemResumo(
  BuildContext context,
  String titulo,
  int valor,
  Color cor,
  IconData icone,
) {
  final isMobile = MediaQuery.of(context).size.width < 700;

  return Container(
    constraints: const BoxConstraints(minHeight: 118),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cor.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: cor.withValues(alpha: 0.14),
          child: Icon(icone, color: cor, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          valor.toString(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    ),
  );
}

Widget dashboardCardResumo(
  BuildContext context,
  String titulo,
  String valor,
  IconData icone, {
  Color? cor,
}) {
  final corFinal = cor ?? NatusApp.vinho;
  final isMobile = MediaQuery.of(context).size.width < 700;

  return Container(
    width: 220,
    height: 110,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [NatusApp.offWhite, NatusApp.creme],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.86), width: 1.1),
      boxShadow: [
        BoxShadow(
          color: NatusApp.vinho.withValues(alpha: 0.075),
          blurRadius: 24,
          spreadRadius: -10,
          offset: const Offset(0, 16),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: corFinal.withValues(alpha: 0.15),
              child: Icon(icone, color: corFinal, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: corFinal,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget dashboardBloco(
  BuildContext context,
  String titulo,
  List<Widget> filhos,
) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8).withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withValues(alpha: 0.84), width: 1.1),
      boxShadow: [
        BoxShadow(
          color: NatusApp.vinho.withValues(alpha: 0.085),
          blurRadius: 30,
          spreadRadius: -12,
          offset: const Offset(0, 18),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NatusApp.vinho,
          ),
        ),
        const SizedBox(height: 12),
        ...filhos,
      ],
    ),
  );
}


Widget blocoDashboardOrganico(
  String titulo,
  String valor,
  IconData icone,
) {
  return CardOrganicoNatus(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF7EEF1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icone,
            color: const Color(0xFF7B3A44),
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                valor,
                style: const TextStyle(
                  color: Color(0xFF7B3A44),
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
