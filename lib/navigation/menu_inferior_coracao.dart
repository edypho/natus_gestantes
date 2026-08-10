import 'package:flutter/material.dart';

import '../core/natus_terminologia.dart';
import '../shared/natus_app.dart';

class ItemMenuInferior {
  final String titulo;
  final IconData icone;

  const ItemMenuInferior(this.titulo, this.icone);

  String get rotulo => NatusTermos.rotuloMenu(titulo);
}

class _NatusRoundedNotchedShape extends NotchedShape {
  static const _borderRadius = BorderRadius.all(Radius.circular(28));

  const _NatusRoundedNotchedShape();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    final roundedPath = Path()..addRRect(_borderRadius.toRRect(host));
    final notchedPath = const CircularNotchedRectangle().getOuterPath(
      host,
      guest,
    );

    return Path.combine(PathOperation.intersect, roundedPath, notchedPath);
  }
}

class NatusMenuInferiorCoracao extends StatelessWidget {
  final List<ItemMenuInferior> itensEsquerda;
  final List<ItemMenuInferior> itensDireita;
  final String telaAtual;
  final void Function(String titulo) onSelecionarTela;

  const NatusMenuInferiorCoracao({
    required this.itensEsquerda,
    required this.itensDireita,
    required this.telaAtual,
    required this.onSelecionarTela,
    super.key,
  }) : assert(
         itensEsquerda.length == 2 && itensDireita.length == 2,
         'Sao sempre 2 itens de cada lado do coracao central.',
       );

  Widget _botaoAba(ItemMenuInferior item) {
    final ativo = telaAtual == item.titulo;
    final corIcone = ativo ? NatusApp.vinho : NatusApp.textoSuave;

    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: item.rotulo,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelecionarTela(item.titulo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: ativo
                    ? Colors.white.withValues(alpha: 0.46)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: ativo
                      ? Colors.white.withValues(alpha: 0.72)
                      : Colors.transparent,
                ),
                boxShadow: ativo
                    ? [
                        BoxShadow(
                          color: NatusApp.vinho.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: ativo
                          ? NatusApp.rose.withValues(alpha: 0.24)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(item.icone, size: 19, color: corIcone),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: ativo ? FontWeight.w800 : FontWeight.w600,
                      color: corIcone,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: BottomAppBar(
          color: NatusApp.offWhite.withValues(alpha: 0.94),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: const _NatusRoundedNotchedShape(),
          notchMargin: 10,
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                _botaoAba(itensEsquerda[0]),
                _botaoAba(itensEsquerda[1]),
                const SizedBox(width: 94),
                _botaoAba(itensDireita[0]),
                _botaoAba(itensDireita[1]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NatusFabCoracao extends StatelessWidget {
  final bool ativo;
  final VoidCallback onTap;
  final String tooltip;

  const NatusFabCoracao({
    required this.ativo,
    required this.onTap,
    this.tooltip = 'Abrir ação principal',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: ativo ? 1.02 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: NatusApp.vinho.withValues(alpha: ativo ? 0.22 : 0.16),
              blurRadius: ativo ? 28 : 22,
              spreadRadius: ativo ? -8 : -10,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: onTap,
          tooltip: tooltip,
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NatusApp.marsalaSuave,
                  NatusApp.marsala,
                  NatusApp.vinho,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.52),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (ativo)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  Icon(
                    Icons.favorite_rounded,
                    color: NatusApp.escuro ? NatusApp.fundo : NatusApp.offWhite,
                    size: ativo ? 31 : 29,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
