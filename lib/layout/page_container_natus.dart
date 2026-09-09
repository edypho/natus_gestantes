import 'package:flutter/material.dart';

import '../core/natus_breakpoints.dart';
import '../shared/natus_app.dart';
import '../shared/natus_premium_visual.dart';

class PageContainerNatus extends StatelessWidget {
  final String titulo;
  final Widget child;

  const PageContainerNatus({
    super.key,
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = NatusBreakpoints.usarLayoutCompacto(
      context,
      larguraLimite: 720,
    );

    return Stack(
      children: [
        const Positioned(
          right: -90,
          top: 18,
          child: NatusBotanicalAsset(
            asset: NatusBotanicalAssets.branchHorizontal,
            width: 360,
            opacity: 0.045,
          ),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            mobile ? 14 : 30,
            mobile ? 18 : 30,
            mobile ? 14 : 34,
            36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: mobile ? 2 : 4,
                  bottom: mobile ? 18 : 22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: NatusApp.marsala.withValues(alpha: 0.075),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: NatusApp.marsala.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Text(
                        'Natus • gestão obstétrica premium',
                        style: TextStyle(
                          color: NatusApp.marsala,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titulo,
                      style: TextStyle(
                        color: NatusApp.vinho,
                        fontSize: mobile ? 24 : 32,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
