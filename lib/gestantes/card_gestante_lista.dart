import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import '../dashboard/dashboard_cards_natus.dart';

/// Card de gestante na listagem — layout guiado por
/// design_referencia_visual.png: avatar com iniciais, nome + badge de
/// status, linha de IG • DPP, dados do bebê e (com permissão) do plano.
class NatusCardGestanteLista extends StatelessWidget {
  final Map<String, String> gestante;
  final String igAtual;
  final String statusNormalizado;
  final bool mostrarFinanceiro;
  final VoidCallback onAbrir;
  final VoidCallback onExcluir;

  const NatusCardGestanteLista({
    super.key,
    required this.gestante,
    required this.igAtual,
    required this.statusNormalizado,
    required this.mostrarFinanceiro,
    required this.onAbrir,
    required this.onExcluir,
  });

  String get _iniciais {
    final nome = (gestante['nomeGestante'] ?? '').trim();
    if (nome.isEmpty) return '?';
    final partes =
        nome.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nome = gestante['nomeGestante'] ?? '';
    final dpp = gestante['dpp'] ?? '-';
    final nomeBebe = gestante['nomeBebe'] ?? '-';
    final sexo = gestante['sexo'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onAbrir,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      NatusApp.marsala.withValues(alpha: 0.12),
                  child: Text(
                    _iniciais,
                    style: TextStyle(
                      color: NatusApp.marsala,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: NatusApp.texto,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          NatusStatusBadge(statusNormalizado),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'IG: $igAtual  •  DPP: $dpp',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: NatusApp.textoSuave,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '👶 $nomeBebe • $sexo',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: NatusApp.textoSuave,
                        ),
                      ),
                      if (mostrarFinanceiro) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${gestante['plano'] ?? '-'}  •  ${gestante['valorPlano'] ?? '-'}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: NatusApp.douradoEscuro,
                          ),
                        ),
                      ],
                      NatusAlertaDpp(gestante),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  icon: Icon(
                    Icons.more_vert,
                    color: NatusApp.textoSuave,
                    size: 20,
                  ),
                  onSelected: (opcao) {
                    if (opcao == 'abrir') onAbrir();
                    if (opcao == 'excluir') onExcluir();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'abrir',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 18, color: NatusApp.vinho),
                          SizedBox(width: 10),
                          Text('Abrir ficha'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Color(0xFFB3413B)),
                          SizedBox(width: 10),
                          Text('Excluir'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
