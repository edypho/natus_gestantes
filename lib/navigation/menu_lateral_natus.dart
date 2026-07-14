import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import '../shared/natus_premium_visual.dart';

import 'menu_item_natus.dart';

class MenuLateralNatus extends StatelessWidget {
  final List<MenuItemNatus> itens;
  final String selecionado;
  final void Function(String rota) onSelecionar;

  const MenuLateralNatus({
    super.key,
    required this.itens,
    required this.selecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NatusApp.marsala, NatusApp.vinho, NatusApp.vinhoProfundo],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              right: -46,
              bottom: 10,
              child: Opacity(
                opacity: 0.12,
                child: CustomPaint(
                  size: Size(170, 230),
                  painter: BotanicalNatusPainter(color: Color(0xFFFFE6DD)),
                ),
              ),
            ),
            Column(
              children: [
            const SizedBox(height: 18),
            const Text(
              'Natus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: itens.length,
                itemBuilder: (context, index) {
                  final item = itens[index];
                  final ativo = item.rota == selecionado;

                  return ListTile(
                    leading: Icon(
                      item.icone,
                      color: Colors.white,
                    ),
                    title: Text(
                      item.titulo,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    selected: ativo,
                    selectedTileColor: Colors.white.withValues(alpha: 0.12),
                    onTap: () => onSelecionar(item.rota),
                  );
                },
              ),
            ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
