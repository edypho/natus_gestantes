import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import '../shared/natus_premium_visual.dart';

class AppShellNatus extends StatelessWidget {
  final Widget menu;
  final Widget conteudo;

  const AppShellNatus({
    super.key,
    required this.menu,
    required this.conteudo,
  });

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final mobile = largura < 800;

    if (mobile) {
      return PremiumNatusBackground(
        mostrarArteGrande: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          drawer: Drawer(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            width: 310,
            child: menu,
          ),
          body: Builder(
            builder: (context) {
              return Stack(
                children: [
                  conteudo,
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: Material(
                        color: NatusApp.offWhite.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(18),
                        elevation: 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.84),
                              ),
                            ),
                            child: Icon(
                              Icons.menu_rounded,
                              color: NatusApp.vinho,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return PremiumNatusBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            menu,
            Expanded(
              child: conteudo,
            ),
          ],
        ),
      ),
    );
  }
}
