import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/services/tenant_filter_service.dart';

void main() {
  group('TenantFilterService.deveFiltrarPorAdmin', () {
    test('perfil comum com tenant deve aplicar filtro', () {
      for (final perfil in ['admin', 'enfermeira', 'obstetra', 'gestante']) {
        expect(
          TenantFilterService.deveFiltrarPorAdmin(
            perfil: perfil,
            adminDonoId: ' clinica-a ',
          ),
          isTrue,
          reason: perfil,
        );
      }
    });

    test('somente perfil canônico de superadmin dispensa o filtro', () {
      expect(
        TenantFilterService.deveFiltrarPorAdmin(
          perfil: 'superAdmin',
          adminDonoId: '',
          superAdminVerificado: true,
        ),
        isFalse,
      );

      for (final aliasNaoNormalizado in ['superadmin', 'super_admin']) {
        expect(
          TenantFilterService.deveFiltrarPorAdmin(
            perfil: aliasNaoNormalizado,
            adminDonoId: 'clinica-a',
          ),
          isTrue,
          reason: aliasNaoNormalizado,
        );
      }
    });

    test('tenant vazio mantém obrigatório o filtro fail-closed', () {
      expect(
        TenantFilterService.deveFiltrarPorAdmin(
          perfil: 'admin',
          adminDonoId: '  ',
        ),
        isTrue,
      );
    });

    test('superadmin sem claim verificada continua filtrado', () {
      expect(
        TenantFilterService.deveFiltrarPorAdmin(
          perfil: 'superAdmin',
          adminDonoId: '',
        ),
        isTrue,
      );
    });
  });

  group('TenantFilterService.pertenceAoAdmin', () {
    test('aceita somente item do mesmo tenant para perfil comum', () {
      expect(
        TenantFilterService.pertenceAoAdmin(
          itemAdminDonoId: ' clinica-a ',
          adminDonoId: 'clinica-a',
          perfil: 'admin',
        ),
        isTrue,
      );
      expect(
        TenantFilterService.pertenceAoAdmin(
          itemAdminDonoId: 'clinica-b',
          adminDonoId: 'clinica-a',
          perfil: 'admin',
        ),
        isFalse,
      );
    });

    test('nega item ou contexto com tenant vazio, inclusive ambos vazios', () {
      for (final caso in <({String? item, String admin})>[
        (item: null, admin: 'clinica-a'),
        (item: '', admin: 'clinica-a'),
        (item: 'clinica-a', admin: ''),
        (item: '  ', admin: '  '),
      ]) {
        expect(
          TenantFilterService.pertenceAoAdmin(
            itemAdminDonoId: caso.item,
            adminDonoId: caso.admin,
            perfil: 'admin',
          ),
          isFalse,
          reason: 'item=${caso.item}, admin=${caso.admin}',
        );
      }
    });

    test('alias de superadmin não normalizado não ganha acesso global', () {
      for (final aliasNaoNormalizado in ['superadmin', 'super_admin']) {
        expect(
          TenantFilterService.pertenceAoAdmin(
            itemAdminDonoId: 'clinica-b',
            adminDonoId: 'clinica-a',
            perfil: aliasNaoNormalizado,
          ),
          isFalse,
          reason: aliasNaoNormalizado,
        );
      }
    });

    test('perfil canônico de superadmin pode inspecionar outro tenant', () {
      expect(
        TenantFilterService.pertenceAoAdmin(
          itemAdminDonoId: 'clinica-b',
          adminDonoId: 'clinica-a',
          perfil: 'superAdmin',
          superAdminVerificado: true,
        ),
        isTrue,
      );
    });

    test('perfil superadmin sem claim não ignora o tenant', () {
      expect(
        TenantFilterService.pertenceAoAdmin(
          itemAdminDonoId: 'clinica-b',
          adminDonoId: 'clinica-a',
          perfil: 'superAdmin',
        ),
        isFalse,
      );
    });
  });
}
