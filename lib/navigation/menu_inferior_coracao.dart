import 'package:flutter/material.dart';
import '../shared/natus_app.dart';

/// Um item do menu inferior: ícone + título (o título dobra como chave
/// de navegação, igual ao `telaAtual` usado no menu lateral).
class ItemMenuInferior {
  final String titulo;
  final IconData icone;

  const ItemMenuInferior(this.titulo, this.icone);
}

/// Menu inferior mobile com um entalhe central pro botão coração —
/// dois itens de cada lado. É só um atalho visual pros itens mais
/// usados no dia a dia; o resto do menu continua no drawer lateral.
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
         'São sempre 2 itens de cada lado do coração central.',
       );

  Widget _botaoAba(ItemMenuInferior item) {
    final ativo = telaAtual == item.titulo;
    final cor = ativo ? NatusApp.marsala : NatusApp.textoSuave;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelecionarTela(item.titulo),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icone, size: 23, color: cor),
                const SizedBox(height: 3),
                Text(
                  item.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: ativo ? FontWeight.w800 : FontWeight.w600,
                    color: cor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: NatusApp.offWhite,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 8,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            _botaoAba(itensEsquerda[0]),
            _botaoAba(itensEsquerda[1]),
            const SizedBox(width: 56), // espaço reservado pro entalhe do FAB
            _botaoAba(itensDireita[0]),
            _botaoAba(itensDireita[1]),
          ],
        ),
      ),
    );
  }
}

/// Botão flutuante em formato de coração, encaixado no entalhe do menu
/// inferior — a ação central (Dashboard / Área da gestante, conforme
/// o perfil).
class NatusFabCoracao extends StatelessWidget {
  final bool ativo;
  final VoidCallback onTap;

  const NatusFabCoracao({required this.ativo, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: NatusApp.marsala,
      elevation: ativo ? 6 : 4,
      shape: const CircleBorder(),
      child: Icon(
        Icons.favorite_rounded,
        color: NatusApp.escuro ? NatusApp.fundo : NatusApp.offWhite,
        size: 28,
      ),
    );
  }
}
