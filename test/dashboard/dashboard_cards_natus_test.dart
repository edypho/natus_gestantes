import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/dashboard/dashboard_cards_natus.dart';

Widget _appDeTeste() {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: NatusAlertasDashboardLayout(
          children: [
            NatusCardAlertaDashboard(
              'DPP próxima',
              '0 paciente(s)',
              Icons.warning,
              Colors.orange,
              key: const Key('dpp'),
            ),
            NatusCardAlertaDashboard(
              'Parcelas atrasadas',
              '0 parcela(s)',
              Icons.warning_amber,
              Colors.red,
              key: const Key('parcelas'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _appCardsResumo() {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: NatusCardsResumoLayout(
          children: [
            Container(key: const Key('primeiro'), height: 110),
            Container(key: const Key('segundo'), height: 110),
          ],
        ),
      ),
    ),
  );
}

Widget _appFiltroPeriodo() {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: NatusFiltroPeriodoDashboard(
          mes: 8,
          ano: 2026,
          onMesAlterado: (_) {},
          onAnoAlterado: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('alertas ficam empilhados no iPhone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_appDeTeste());

    final dpp = tester.getRect(find.byKey(const Key('dpp')));
    final parcelas = tester.getRect(find.byKey(const Key('parcelas')));

    expect(parcelas.top, greaterThan(dpp.bottom));
    expect(dpp.width, parcelas.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alertas permanecem lado a lado em tela larga', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_appDeTeste());

    final dpp = tester.getRect(find.byKey(const Key('dpp')));
    final parcelas = tester.getRect(find.byKey(const Key('parcelas')));

    expect(parcelas.left, greaterThan(dpp.right));
    expect(parcelas.top, dpp.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumos ocupam toda a largura em iPhone estreito', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_appCardsResumo());

    final primeiro = tester.getRect(find.byKey(const Key('primeiro')));
    final segundo = tester.getRect(find.byKey(const Key('segundo')));

    expect(primeiro.width, 342);
    expect(segundo.top, greaterThan(primeiro.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumos usam duas colunas em iPhone largo', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_appCardsResumo());

    final primeiro = tester.getRect(find.byKey(const Key('primeiro')));
    final segundo = tester.getRect(find.byKey(const Key('segundo')));

    expect(primeiro.width, 185);
    expect(segundo.left, greaterThan(primeiro.right));
    expect(segundo.top, primeiro.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumos permanecem lado a lado em 1024x900', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_appCardsResumo());

    final primeiro = tester.getRect(find.byKey(const Key('primeiro')));
    final segundo = tester.getRect(find.byKey(const Key('segundo')));

    expect(segundo.left, greaterThan(primeiro.right));
    expect(segundo.top, primeiro.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro de período quebra linha sem overflow em tela estreita', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_appFiltroPeriodo());

    final mes = tester.getRect(find.byKey(const Key('dashboard-filtro-mes')));
    final ano = tester.getRect(find.byKey(const Key('dashboard-filtro-ano')));

    expect(ano.top, greaterThan(mes.bottom));
    expect(tester.takeException(), isNull);
  });
}
