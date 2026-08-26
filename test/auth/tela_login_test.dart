import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/auth/tela_login.dart';

void main() {
  Future<void> montarLogin(WidgetTester tester, {required Size tamanho}) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: TelaLogin()));
    await tester.pump();
  }

  testWidgets('oferece recuperação de senha sem overflow em tela móvel', (
    tester,
  ) async {
    await montarLogin(tester, tamanho: const Size(320, 568));

    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mantém formulário legível em 1024x900', (tester) async {
    await montarLogin(tester, tamanho: const Size(1024, 900));

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
