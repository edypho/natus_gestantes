import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/saas/contexto_saas.dart';
import 'package:natus_gestantes/saas/tenant_access_scope.dart';

ContextoSaaS _contexto({
  String perfil = 'admin',
  bool superAdmin = false,
  String clinicaId = 'clinica-a',
  String adminDonoId = 'clinica-a',
  bool vinculoPacienteConsistente = true,
}) {
  return ContextoSaaS(
    uidUsuario: 'usuario-a',
    nomeUsuario: 'Usuário A',
    emailUsuario: 'usuario@natus.test',
    perfil: perfil,
    clinicaId: clinicaId,
    adminDonoId: adminDonoId,
    vinculoPacienteConsistente: vinculoPacienteConsistente,
    superAdmin: superAdmin,
  );
}

void main() {
  group('ContextoSaaS.fromUsuario', () {
    test('normaliza dados textuais e o alias paciente', () {
      final contexto = ContextoSaaS.fromUsuario(
        uidUsuario: '  uid-paciente  ',
        emailUsuario: '  paciente@natus.test  ',
        dados: const {
          'nome': '  Paciente Natus  ',
          'tipoUsuario': 'PACIENTE',
          'pacienteId': '  paciente-a  ',
          'clinicaId': '  clinica-a  ',
          'adminDonoId': '  clinica-a  ',
        },
      );

      expect(contexto.uidUsuario, 'uid-paciente');
      expect(contexto.nomeUsuario, 'Paciente Natus');
      expect(contexto.emailUsuario, 'paciente@natus.test');
      expect(contexto.perfil, 'gestante');
      expect(contexto.clinicaId, 'clinica-a');
      expect(contexto.adminDonoId, 'clinica-a');
      expect(contexto.pacienteId, 'paciente-a');
      expect(contexto.vinculoPacienteConsistente, isTrue);
      expect(contexto.superAdmin, isFalse);
    });

    test('usa idGestante legado quando pacienteId está vazio', () {
      final contexto = ContextoSaaS.fromUsuario(
        uidUsuario: 'uid-paciente',
        emailUsuario: 'paciente@natus.test',
        dados: const {
          'tipoUsuario': 'paciente',
          'pacienteId': '   ',
          'idGestante': ' paciente-legada ',
          'adminDonoId': 'clinica-a',
        },
      );

      expect(contexto.pacienteId, 'paciente-legada');
      expect(contexto.vinculoPacienteConsistente, isTrue);
    });

    test('bloqueia aliases divergentes do identificador do paciente', () {
      final contexto = ContextoSaaS.fromUsuario(
        uidUsuario: 'uid-paciente',
        emailUsuario: 'paciente@natus.test',
        dados: const {
          'tipoUsuario': 'paciente',
          'pacienteId': 'paciente-a',
          'idGestante': 'paciente-b',
          'clinicaId': 'clinica-a',
          'adminDonoId': 'clinica-a',
        },
      );

      expect(contexto.vinculoPacienteConsistente, isFalse);
      expect(
        () => TenantAccessScope.fromContexto(contexto),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('bloqueia aliases de UID divergentes ou de outro usuário', () {
      for (final dadosUid in <Map<String, dynamic>>[
        const {'uidPaciente': 'uid-paciente', 'uidGestante': 'outro-uid'},
        const {'uidGestante': 'outro-uid'},
      ]) {
        final contexto = ContextoSaaS.fromUsuario(
          uidUsuario: 'uid-paciente',
          emailUsuario: 'paciente@natus.test',
          dados: {
            'tipoUsuario': 'paciente',
            'pacienteId': 'paciente-a',
            'clinicaId': 'clinica-a',
            'adminDonoId': 'clinica-a',
            ...dadosUid,
          },
        );

        expect(
          contexto.vinculoPacienteConsistente,
          isFalse,
          reason: '$dadosUid',
        );
        expect(
          () => TenantAccessScope.fromContexto(contexto),
          throwsA(isA<TenantScopeException>()),
          reason: '$dadosUid',
        );
      }
    });

    test('normaliza aliases de superadmin do documento protegido', () {
      for (final alias in ['superadmin', 'super_admin', 'SUPERADMIN']) {
        final contexto = ContextoSaaS.fromUsuario(
          uidUsuario: 'uid-super',
          emailUsuario: 'super@natus.test',
          dados: {'tipoUsuario': alias},
          superAdminVerificado: true,
        );

        expect(contexto.perfil, 'superAdmin', reason: 'alias: $alias');
        expect(contexto.superAdmin, isTrue, reason: 'alias: $alias');
        expect(contexto.podeVerTudo, isTrue, reason: 'alias: $alias');
      }
    });

    test('texto de perfil sem claim não eleva para acesso global', () {
      final contexto = ContextoSaaS.fromUsuario(
        uidUsuario: 'uid-super',
        emailUsuario: 'super@natus.test',
        dados: const {'tipoUsuario': 'superAdmin'},
      );

      expect(contexto.perfil, 'superAdmin');
      expect(contexto.superAdmin, isFalse);
      expect(contexto.podeVerTudo, isFalse);
    });

    test('usa o campo de perfil não vazio e bloqueia aliases divergentes', () {
      final fallback = ContextoSaaS.fromUsuario(
        uidUsuario: 'uid',
        emailUsuario: 'usuario@natus.test',
        dados: const {
          'tipo': '',
          'tipoUsuario': 'admin',
          'clinicaId': 'clinica-a',
        },
      );
      final divergente = ContextoSaaS.fromUsuario(
        uidUsuario: 'uid',
        emailUsuario: 'usuario@natus.test',
        dados: const {
          'tipo': 'admin',
          'tipoUsuario': 'obstetra',
          'clinicaId': 'clinica-a',
        },
      );

      expect(fallback.perfil, 'admin');
      expect(
        () => TenantAccessScope.fromContexto(divergente),
        throwsA(isA<TenantScopeException>()),
      );
    });

    test('normaliza perfis clínicos conhecidos ignorando caixa', () {
      const esperadoPorEntrada = {
        'ADMIN': 'admin',
        'Enfermeira': 'enfermeira',
        'OBSTETRA': 'obstetra',
        'PROFISSIONAL': 'profissional',
        'GESTANTE': 'gestante',
      };

      for (final entrada in esperadoPorEntrada.entries) {
        final contexto = ContextoSaaS.fromUsuario(
          uidUsuario: 'uid',
          emailUsuario: 'usuario@natus.test',
          dados: {'tipoUsuario': entrada.key, 'adminDonoId': 'clinica-a'},
        );

        expect(contexto.perfil, entrada.value, reason: entrada.key);
        expect(contexto.superAdmin, isFalse, reason: entrada.key);
      }
    });
  });

  group('validação local do contexto', () {
    test('acesso global exige perfil e sinalização de superadmin', () {
      expect(
        _contexto(perfil: 'superAdmin', superAdmin: true).podeVerTudo,
        isTrue,
      );
      expect(
        _contexto(perfil: 'superAdmin', superAdmin: false).podeVerTudo,
        isFalse,
      );
      expect(_contexto(perfil: 'admin', superAdmin: true).podeVerTudo, isFalse);
    });

    test('considera IDs vazios ou só com espaços como ausentes', () {
      final contexto = _contexto(clinicaId: '  ', adminDonoId: '  ');

      expect(contexto.temAdminDono, isFalse);
      expect(contexto.temClinica, isFalse);
    });

    test('aceita um único identificador de clínica preenchido', () {
      expect(
        _contexto(clinicaId: 'clinica-a', adminDonoId: '').temClinica,
        isTrue,
      );
      expect(
        _contexto(clinicaId: '', adminDonoId: 'clinica-a').temClinica,
        isTrue,
      );
    });

    test('detecta identificadores de clínica divergentes', () {
      final contexto = _contexto(
        clinicaId: 'clinica-a',
        adminDonoId: 'clinica-b',
      );

      expect(contexto.vinculoClinicaConsistente, isFalse);
    });

    test('considera vínculos iguais após trim como consistentes', () {
      final contexto = _contexto(
        clinicaId: ' clinica-a ',
        adminDonoId: 'clinica-a',
      );

      expect(contexto.vinculoClinicaConsistente, isTrue);
    });
  });
}
