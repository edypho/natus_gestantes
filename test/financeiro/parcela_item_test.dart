import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/financeiro/parcela_item.dart';

void main() {
  testWidgets('bloqueia ações e mantém layout durante upload em 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NatusParcelaItem(
            parcela: const {
              'gestante': 'Paciente com nome extenso para validar o layout',
              'vencimento': '26/08/2026',
              'valor': 'R\$ 1.250,00',
            },
            rotulo: 'Parcela 1 de 3',
            pago: false,
            atrasado: false,
            processando: true,
            comprovanteSelecionadoNome: 'comprovante-pagamento.pdf',
            onAbrirComprovante: () {},
            onSelecionarComprovante: () {},
            onDarBaixa: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
