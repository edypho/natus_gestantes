import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/super_admin/super_admin_access_guard.dart';

void main() {
  group('SuperAdminAccessGuard', () {
    test('aceita somente status ativos da clínica', () {
      expect(SuperAdminAccessGuard.statusClinicaPermiteAcesso('ativa'), isTrue);
      expect(
        SuperAdminAccessGuard.statusClinicaPermiteAcesso(' TESTE '),
        isTrue,
      );

      for (final status in [null, '', 'pausada', 'bloqueada', 'cancelada']) {
        expect(
          SuperAdminAccessGuard.statusClinicaPermiteAcesso(status),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('aceita somente usuário explicitamente ativo', () {
      expect(
        SuperAdminAccessGuard.statusUsuarioPermiteAcesso(' ATIVO '),
        isTrue,
      );

      for (final status in [null, '', 'inativo', 'bloqueado']) {
        expect(
          SuperAdminAccessGuard.statusUsuarioPermiteAcesso(status),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('clínica precisa declarar o mesmo tenant nos dois aliases', () {
      expect(
        SuperAdminAccessGuard.clinicaCorrespondeAoTenant(const {
          'clinicaId': 'clinica-a',
          'adminDonoId': 'clinica-a',
        }, 'clinica-a'),
        isTrue,
      );
      expect(
        SuperAdminAccessGuard.clinicaCorrespondeAoTenant(const {
          'clinicaId': 'clinica-a',
          'adminDonoId': 'clinica-b',
        }, 'clinica-a'),
        isFalse,
      );
      expect(
        SuperAdminAccessGuard.clinicaCorrespondeAoTenant(const {
          'status': 'ativa',
        }, 'clinica-a'),
        isFalse,
      );
    });
  });
}
