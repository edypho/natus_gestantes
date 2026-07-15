import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import '../shared/natus_logo.dart';

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
          colors: [NatusApp.menuTopo, NatusApp.menuMeio, NatusApp.menuBase],
        ),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -10,
            offset: const Offset(10, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const SizedBox(
              height: 96,
              child: NatusLogo(color: NatusApp.sobreMarca),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: itens.length,
                itemBuilder: (context, index) {
                  final item = itens[index];
                  final ativo = item.rota == selecionado;

                  return ListTile(
                    leading: Icon(item.icone, color: NatusApp.sobreMarca),
                    title: Text(
                      item.titulo,
                      style: const TextStyle(color: NatusApp.sobreMarca),
                    ),
                    selected: ativo,
                    selectedTileColor: NatusApp.sobreMarca.withValues(
                      alpha: 0.12,
                    ),
                    onTap: () => onSelecionar(item.rota),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
