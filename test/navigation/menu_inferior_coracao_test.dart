import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/navigation/menu_inferior_coracao.dart';

const _itensEsquerda = <ItemMenuInferior>[
  ItemMenuInferior('Agenda', Icons.event_note_rounded),
  ItemMenuInferior('Pacientes', Icons.people_alt_rounded),
];

const _itensDireita = <ItemMenuInferior>[
  ItemMenuInferior('Mapa', Icons.map_rounded),
  ItemMenuInferior('Exames', Icons.biotech_rounded),
];

Widget _appDeTeste({
  required ValueChanged<String> onSelecionarTela,
  double escalaTexto = 1,
  EdgeInsets areaSegura = EdgeInsets.zero,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(escalaTexto),
        padding: areaSegura,
        viewPadding: areaSegura,
      ),
      child: child!,
    ),
    home: Scaffold(
      extendBody: true,
      body: const ColoredBox(color: Colors.white),
      bottomNavigationBar: NatusMenuInferiorCoracao(
        itensEsquerda: _itensEsquerda,
        itensDireita: _itensDireita,
        telaAtual: 'Agenda',
        onSelecionarTela: onSelecionarTela,
      ),
      floatingActionButton: NatusFabCoracao(
        ativo: true,
        tooltip: 'Abrir acompanhamento',
        onTap: () {},
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    ),
  );
}

void _configurarTelaIPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _configurarTela(WidgetTester tester, {required Size tamanho}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamanho;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _esperarCentroPerfeito(WidgetTester tester) {
  final barra = tester.getRect(
    find.byKey(NatusMenuInferiorMetricas.chaveBarra),
  );
  final coracao = tester.getRect(
    find.byKey(NatusMenuInferiorMetricas.chaveCoracao),
  );
  final centroViewport = tester.view.physicalSize.width / 2;

  expect(barra.center.dx, closeTo(centroViewport, 0.01));
  expect(coracao.center.dx, closeTo(centroViewport, 0.01));
  expect(barra.center.dx, closeTo(coracao.center.dx, 0.01));
  expect(
    tester.getSize(find.byKey(NatusMenuInferiorMetricas.chaveCoracao)),
    const Size.square(NatusMenuInferiorMetricas.diametroCoracao),
  );
}

void main() {
  testWidgets('barra usa sua propria forma recortada sem fundo retangular', (
    tester,
  ) async {
    _configurarTelaIPhone(tester);
    await tester.pumpWidget(_appDeTeste(onSelecionarTela: (_) {}));

    final barra = tester.widget<BottomAppBar>(find.byType(BottomAppBar));

    expect(barra.color, isNot(Colors.transparent));
    expect(barra.clipBehavior, Clip.antiAlias);
    expect(find.byType(BackdropFilter), findsNothing);

    final path = barra.shape!.getOuterPath(
      const Rect.fromLTWH(0, 0, 370, 72),
      Rect.fromCircle(center: const Offset(185, 0), radius: 47),
    );

    expect(path.contains(const Offset(185, 2)), isFalse);
    expect(path.contains(const Offset(24, 24)), isTrue);
    expect(path.contains(const Offset(1, 1)), isFalse);
  });

  testWidgets('itens continuam navegaveis depois do recorte', (tester) async {
    _configurarTelaIPhone(tester);
    String? telaSelecionada;
    await tester.pumpWidget(
      _appDeTeste(onSelecionarTela: (tela) => telaSelecionada = tela),
    );

    await tester.tap(find.text('Exames'));
    await tester.pump();

    expect(telaSelecionada, 'Exames');
    expect(tester.takeException(), isNull);
  });

  testWidgets('barra informa seleção e ação central ao VoiceOver', (
    tester,
  ) async {
    _configurarTelaIPhone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_appDeTeste(onSelecionarTela: (_) {}));

    expect(find.bySemanticsLabel('Agenda'), findsOneWidget);
    expect(find.byTooltip('Abrir acompanhamento'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('barra nao estoura em iPhone estreito com texto ampliado', (
    tester,
  ) async {
    _configurarTelaIPhone(tester);
    await tester.pumpWidget(
      _appDeTeste(onSelecionarTela: (_) {}, escalaTexto: 1.3),
    );

    expect(find.byType(NatusMenuInferiorCoracao), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android mantém barra, recorte e coração no mesmo centro', (
    tester,
  ) async {
    _configurarTela(tester, tamanho: const Size(360, 800));
    await tester.pumpWidget(
      _appDeTeste(
        onSelecionarTela: (_) {},
        areaSegura: const EdgeInsets.only(bottom: 24),
      ),
    );

    _esperarCentroPerfeito(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS não desloca a barra com safe area lateral assimétrica', (
    tester,
  ) async {
    _configurarTela(tester, tamanho: const Size(390, 844));
    await tester.pumpWidget(
      _appDeTeste(
        onSelecionarTela: (_) {},
        areaSegura: const EdgeInsets.only(left: 47, bottom: 34),
      ),
    );

    _esperarCentroPerfeito(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web responsiva preserva o centro matemático da viewport', (
    tester,
  ) async {
    _configurarTela(tester, tamanho: const Size(412, 915));
    await tester.pumpWidget(_appDeTeste(onSelecionarTela: (_) {}));

    _esperarCentroPerfeito(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('referência visual mantém o coração encaixado no recorte', (
    tester,
  ) async {
    _configurarTela(tester, tamanho: const Size(390, 844));
    await tester.pumpWidget(
      _appDeTeste(
        onSelecionarTela: (_) {},
        areaSegura: const EdgeInsets.only(bottom: 34),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/menu_inferior_coracao_390x844.png'),
    );
  });
}
