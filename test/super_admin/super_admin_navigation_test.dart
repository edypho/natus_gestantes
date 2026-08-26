import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/super_admin/super_admin_navigation.dart';

void main() {
  group('SuperAdminNavigation', () {
    test('resolve os novos identificadores', () {
      expect(SuperAdminNavigation.resolver('clinicas').id, 'clinicas');
      expect(SuperAdminNavigation.resolver('assinaturas').id, 'assinaturas');
      expect(SuperAdminNavigation.resolver('nova-clinica').id, 'nova-clinica');
    });

    test('mantém compatibilidade com os nomes legados', () {
      expect(SuperAdminNavigation.resolver('Dashboard SaaS').id, 'visao-geral');
      expect(
        SuperAdminNavigation.resolver('Clínicas cadastradas SaaS').id,
        'clinicas',
      );
      expect(
        SuperAdminNavigation.resolver(
          'Criação de clínica/admin/enfermeira SaaS',
        ).id,
        'nova-clinica',
      );
    });

    test('usa a visão geral para rota desconhecida', () {
      expect(
        SuperAdminNavigation.resolver('rota-inexistente').id,
        'visao-geral',
      );
    });
  });
}
