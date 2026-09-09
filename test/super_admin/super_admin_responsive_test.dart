import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/super_admin/super_admin_layout.dart';
import 'package:natus_gestantes/super_admin/super_admin_lists.dart';
import 'package:natus_gestantes/super_admin/super_admin_shell.dart';
import 'package:natus_gestantes/super_admin/super_admin_widgets.dart';
import 'package:natus_gestantes/shared/natus_app.dart';

void main() {
  Future<void> configurarTela(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Widget paginaTeste() {
    return MaterialApp(
      home: Scaffold(
        body: SuperAdminPageScaffold(
          titulo: 'Clínicas',
          subtitulo: 'Controle comercial e situação de acesso.',
          icone: Icons.apartment_rounded,
          actions: const [
            FilledButton(onPressed: null, child: Text('Nova clínica')),
          ],
          child: Column(
            children: [
              SuperAdminResponsiveGrid(
                children: [
                  superAdminCard(
                    titulo: 'Clínicas ativas',
                    valor: '12',
                    icone: Icons.apartment_rounded,
                  ),
                  superAdminCard(
                    titulo: 'Mensalidades pendentes',
                    valor: '2',
                    icone: Icons.warning_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              superAdminListTile(
                titulo: 'Clínica Natus',
                subtitulo: 'Plano Premium • Administrador: admin@natus.com',
                icone: Icons.apartment_rounded,
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    OutlinedButton(onPressed: null, child: Text('Pausar')),
                    OutlinedButton(onPressed: null, child: Text('Bloquear')),
                    FilledButton(onPressed: null, child: Text('Reativar')),
                    TextButton(onPressed: null, child: Text('Desativar')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  for (final size in const [Size(320, 800), Size(800, 600), Size(1024, 900)]) {
    testWidgets(
      'organiza conteúdo sem overflow em ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await configurarTela(tester, size);
        await tester.pumpWidget(paginaTeste());
        await tester.pump();

        expect(find.text('Clínicas'), findsOneWidget);
        expect(find.text('Clínica Natus'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shell desktop mantém navegação separada do módulo clínico', (
    tester,
  ) async {
    await configurarTela(tester, const Size(1024, 900));
    await tester.pumpWidget(
      NatusApp(
        home: SuperAdminShell(
          nomeUsuario: 'Super Admin',
          emailUsuario: 'admin@admin.com',
          pageBuilder: (id) => Center(child: Text('pagina-$id')),
        ),
      ),
    );

    expect(find.text('ADMINISTRAÇÃO DA PLATAFORMA'), findsOneWidget);
    expect(find.text('pagina-visao-geral'), findsOneWidget);
    await tester.tap(find.text('Clínicas'));
    await tester.pumpAndSettle();
    expect(find.text('pagina-clinicas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell mobile abre drawer e troca de área sem overflow', (
    tester,
  ) async {
    await configurarTela(tester, const Size(320, 800));
    await tester.pumpWidget(
      NatusApp(
        home: SuperAdminShell(
          nomeUsuario: 'Super Admin',
          emailUsuario: 'admin@admin.com',
          pageBuilder: (id) => Center(child: Text('pagina-$id')),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('ADMINISTRAÇÃO DA PLATAFORMA'), findsOneWidget);
    await tester.tap(find.text('Assinaturas'));
    await tester.pumpAndSettle();
    expect(find.text('pagina-assinaturas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
