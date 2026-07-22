import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/saas/contexto_saas.dart';
import 'package:natus_gestantes/saas/contexto_saas_guard.dart';
import 'package:natus_gestantes/saas/tenant_access_scope.dart';

ContextoSaaS _contexto({
  String perfil = 'admin',
  String clinicaId = 'clinica-a',
  String adminDonoId = 'clinica-a',
  bool superAdmin = false,
}) {
  return ContextoSaaS(
    uidUsuario: 'usuario-a',
    emailUsuario: 'usuario@natus.test',
    perfil: perfil,
    clinicaId: clinicaId,
    adminDonoId: adminDonoId,
    superAdmin: superAdmin,
  );
}

void main() {
  group('ContextoSaaSGuard', () {
    test('contexto comum válido produz filtro de tenant', () {
      final contexto = _contexto(
        clinicaId: ' clinica-a ',
        adminDonoId: 'clinica-a',
      );

      expect(ContextoSaaSGuard.podeFiltrarPorAdmin(contexto), isTrue);
      expect(ContextoSaaSGuard.adminFiltro(contexto), 'clinica-a');
    });

    test('contexto ausente bloqueia resolução do filtro', () {
      expect(
        () => ContextoSaaSGuard.podeFiltrarPorAdmin(null),
        throwsA(isA<TenantScopeException>()),
      );
      expect(
        () => ContextoSaaSGuard.adminFiltro(null),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('usuário comum sem clínica não vira acesso global', () {
      final contexto = _contexto(clinicaId: '', adminDonoId: '  ');

      expect(
        () => ContextoSaaSGuard.podeFiltrarPorAdmin(contexto),
        throwsA(isA<TenantScopeException>()),
      );
      expect(
        () => ContextoSaaSGuard.adminFiltro(contexto),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('IDs divergentes bloqueiam a resolução do filtro', () {
      final contexto = _contexto(
        clinicaId: 'clinica-a',
        adminDonoId: 'clinica-b',
      );

      expect(
        () => ContextoSaaSGuard.podeFiltrarPorAdmin(contexto),
        throwsA(isA<TenantScopeException>()),
      );
      expect(
        () => ContextoSaaSGuard.adminFiltro(contexto),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('superadmin verificado é o único caso sem filtro', () {
      final contexto = _contexto(
        perfil: 'superAdmin',
        superAdmin: true,
        clinicaId: '',
        adminDonoId: '',
      );

      expect(ContextoSaaSGuard.podeFiltrarPorAdmin(contexto), isFalse);
      expect(ContextoSaaSGuard.adminFiltro(contexto), isNull);
    });

    test('perfil superAdmin sem sinalização é bloqueado', () {
      final contexto = _contexto(perfil: 'superAdmin', superAdmin: false);

      expect(
        () => ContextoSaaSGuard.podeFiltrarPorAdmin(contexto),
        throwsA(isA<TenantScopeException>()),
      );
      expect(
        () => ContextoSaaSGuard.adminFiltro(contexto),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('sinalização superAdmin com perfil comum é bloqueada', () {
      final contexto = _contexto(perfil: 'admin', superAdmin: true);

      expect(
        () => ContextoSaaSGuard.podeFiltrarPorAdmin(contexto),
        throwsA(isA<TenantScopeException>()),
      );
      expect(
        () => ContextoSaaSGuard.adminFiltro(contexto),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('aliases normalizados pelo contexto recebem semântica canônica', () {
      final contexto = ContextoSaaS.fromUsuario(
        uidUsuario: 'uid-super',
        emailUsuario: 'super@natus.test',
        dados: const {'tipoUsuario': 'super_admin'},
        superAdminVerificado: true,
      );

      expect(ContextoSaaSGuard.podeFiltrarPorAdmin(contexto), isFalse);
      expect(ContextoSaaSGuard.adminFiltro(contexto), isNull);
    });
  });
}
