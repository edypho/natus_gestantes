import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/saas/contexto_saas.dart';
import 'package:natus_gestantes/saas/tenant_access_scope.dart';

ContextoSaaS _contexto({
  String uid = 'usuario-a',
  String perfil = 'admin',
  String clinicaId = 'clinica-a',
  String adminDonoId = 'clinica-a',
  String pacienteId = '',
  bool vinculoPacienteConsistente = true,
  bool superAdmin = false,
}) {
  return ContextoSaaS(
    uidUsuario: uid,
    emailUsuario: 'usuario@natus.test',
    perfil: perfil,
    clinicaId: clinicaId,
    adminDonoId: adminDonoId,
    pacienteId: pacienteId,
    vinculoPacienteConsistente: vinculoPacienteConsistente,
    superAdmin: superAdmin,
  );
}

Matcher get _lancaErroDeEscopo => throwsA(isA<TenantScopeException>());

void main() {
  group('TenantAccessScope.fromContexto', () {
    test('cria escopo restrito para usuário comum', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());

      expect(escopo.uidUsuario, 'usuario-a');
      expect(escopo.perfil, 'admin');
      expect(escopo.clinicaId, 'clinica-a');
      expect(escopo.acessoGlobal, isFalse);
    });

    test('aceita clinicaId como vínculo legado único', () {
      final escopo = TenantAccessScope.fromContexto(
        _contexto(clinicaId: ' clinica-a ', adminDonoId: ''),
      );

      expect(escopo.clinicaId, 'clinica-a');
      expect(escopo.acessoGlobal, isFalse);
    });

    test('aceita adminDonoId como vínculo único', () {
      final escopo = TenantAccessScope.fromContexto(
        _contexto(clinicaId: '', adminDonoId: ' clinica-a '),
      );

      expect(escopo.clinicaId, 'clinica-a');
    });

    test('bloqueia UID vazio', () {
      expect(
        () => TenantAccessScope.fromContexto(_contexto(uid: '  ')),
        _lancaErroDeEscopo,
      );
    });

    test('bloqueia perfil desconhecido', () {
      expect(
        () => TenantAccessScope.fromContexto(
          _contexto(perfil: 'perfil-inventado'),
        ),
        _lancaErroDeEscopo,
      );
    });

    test('bloqueia usuário comum sem vínculo de clínica', () {
      expect(
        () => TenantAccessScope.fromContexto(
          _contexto(clinicaId: ' ', adminDonoId: ''),
        ),
        _lancaErroDeEscopo,
      );
    });

    test('paciente exige e preserva o vínculo com o cadastro', () {
      expect(
        () => TenantAccessScope.fromContexto(
          _contexto(perfil: 'gestante', pacienteId: ''),
        ),
        _lancaErroDeEscopo,
      );

      final escopo = TenantAccessScope.fromContexto(
        _contexto(perfil: 'gestante', pacienteId: ' paciente-a '),
      );
      expect(escopo.pacienteId, 'paciente-a');
      expect(escopo.ehPaciente, isTrue);
    });

    test('bloqueia paciente com aliases de identidade divergentes', () {
      expect(
        () => TenantAccessScope.fromContexto(
          _contexto(
            perfil: 'gestante',
            pacienteId: 'paciente-a',
            vinculoPacienteConsistente: false,
          ),
        ),
        _lancaErroDeEscopo,
      );
    });

    test('bloqueia vínculos de clínica divergentes', () {
      expect(
        () => TenantAccessScope.fromContexto(
          _contexto(clinicaId: 'clinica-a', adminDonoId: 'clinica-b'),
        ),
        _lancaErroDeEscopo,
      );
    });

    test('somente superadmin verificado recebe acesso global', () {
      final verificado = TenantAccessScope.fromContexto(
        _contexto(
          perfil: 'superAdmin',
          superAdmin: true,
          clinicaId: '',
          adminDonoId: '',
        ),
      );
      expect(verificado.acessoGlobal, isTrue);
      expect(verificado.clinicaId, isEmpty);
      expect(
        () => TenantAccessScope.fromContexto(
          _contexto(perfil: 'superAdmin', superAdmin: false),
        ),
        _lancaErroDeEscopo,
      );
      expect(
        () => TenantAccessScope.fromContexto(
          _contexto(perfil: 'admin', superAdmin: true),
        ),
        _lancaErroDeEscopo,
      );
    });
  });

  group('pertenceAoTenant', () {
    late TenantAccessScope escopo;

    setUp(() {
      escopo = TenantAccessScope.fromContexto(_contexto());
    });

    test('aceita registro da mesma clínica pelos dois campos suportados', () {
      expect(escopo.pertenceAoTenant({'adminDonoId': 'clinica-a'}), isTrue);
      expect(escopo.pertenceAoTenant({'clinicaId': ' clinica-a '}), isTrue);
      expect(
        escopo.pertenceAoTenant({
          'clinicaId': 'clinica-a',
          'adminDonoId': 'clinica-a',
        }),
        isTrue,
      );
    });

    test('nega outra clínica e registro sem tenant', () {
      expect(escopo.pertenceAoTenant({'adminDonoId': 'clinica-b'}), isFalse);
      expect(escopo.pertenceAoTenant({'clinicaId': '  '}), isFalse);
      expect(escopo.pertenceAoTenant({}), isFalse);
    });

    test('nega registro cujos identificadores de clínica divergem', () {
      expect(
        escopo.pertenceAoTenant({
          'adminDonoId': 'clinica-a',
          'clinicaId': 'clinica-b',
        }),
        isFalse,
      );
      expect(
        escopo.pertenceAoTenant({
          'adminDonoId': 'clinica-b',
          'clinicaId': 'clinica-a',
        }),
        isFalse,
      );
    });

    test('superadmin verificado pode inspecionar registros globais', () {
      final global = TenantAccessScope.fromContexto(
        _contexto(
          perfil: 'superAdmin',
          superAdmin: true,
          clinicaId: '',
          adminDonoId: '',
        ),
      );

      expect(global.pertenceAoTenant({'adminDonoId': 'clinica-b'}), isTrue);
      expect(global.pertenceAoTenant({}), isTrue);
    });
  });

  group('aplicação do tenant em gravações', () {
    test('sobrescreve tenant informado pelo payload sem mutar a origem', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());
      final origem = <String, dynamic>{
        'nome': 'Paciente',
        'clinicaId': 'clinica-invasora',
        'adminDonoId': 'clinica-invasora',
      };

      final resultado = escopo.aplicarEmDados(origem);

      expect(resultado['nome'], 'Paciente');
      expect(resultado['clinicaId'], 'clinica-a');
      expect(resultado['adminDonoId'], 'clinica-a');
      expect(origem['clinicaId'], 'clinica-invasora');
      expect(origem['adminDonoId'], 'clinica-invasora');
    });

    test('sobrescreve tenant também em mapas de texto', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());

      final resultado = escopo.aplicarEmTextos({
        'nome': 'Paciente',
        'clinicaId': 'clinica-b',
        'adminDonoId': 'clinica-b',
      });

      expect(resultado['clinicaId'], 'clinica-a');
      expect(resultado['adminDonoId'], 'clinica-a');
    });

    test('superadmin precisa declarar a clínica de destino', () {
      final global = TenantAccessScope.fromContexto(
        _contexto(
          perfil: 'superAdmin',
          superAdmin: true,
          clinicaId: '',
          adminDonoId: '',
        ),
      );

      expect(
        () => global.aplicarEmDados({'nome': 'Registro'}),
        _lancaErroDeEscopo,
      );

      final resultado = global.aplicarEmDados({
        'adminDonoId': 'clinica-invasora',
      }, clinicaAlvo: ' clinica-b ');
      expect(resultado['clinicaId'], 'clinica-b');
      expect(resultado['adminDonoId'], 'clinica-b');
    });
  });

  group('proteção de atualizações', () {
    test('remove propriedade e autoria sem mutar o payload original', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());
      final origem = <String, dynamic>{
        'nome': 'Nome atualizado',
        'clinicaId': 'clinica-invasora',
        'adminDonoId': 'clinica-invasora',
        'criadoPorUid': 'outro-usuario',
      };

      final resultado = escopo.protegerAtualizacao(origem);

      expect(resultado, {'nome': 'Nome atualizado'});
      expect(origem['clinicaId'], 'clinica-invasora');
      expect(origem['adminDonoId'], 'clinica-invasora');
      expect(origem['criadoPorUid'], 'outro-usuario');
    });

    test('protege também payloads textuais', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());

      final resultado = escopo.protegerAtualizacaoTexto({
        'descricao': 'Atualizada',
        'clinicaId': 'clinica-b',
        'adminDonoId': 'clinica-b',
        'criadoPorUid': 'outro-usuario',
      });

      expect(resultado, {'descricao': 'Atualizada'});
    });
  });

  group('caminhoStorage', () {
    test('mantém uploads dentro do namespace da clínica', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());

      expect(
        escopo.caminhoStorage(r'/perfis\usuario-a//foto.png'),
        'clinicas/clinica-a/perfis/usuario-a/foto.png',
      );
    });

    test('bloqueia caminho relativo vazio', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());

      expect(() => escopo.caminhoStorage(' // '), _lancaErroDeEscopo);
    });

    test('bloqueia segmentos de navegação', () {
      final escopo = TenantAccessScope.fromContexto(_contexto());

      expect(
        () => escopo.caminhoStorage('../outra-clinica/arquivo.pdf'),
        _lancaErroDeEscopo,
      );
    });

    test('bloqueia upload global sem clínica de destino', () {
      final global = TenantAccessScope.fromContexto(
        _contexto(
          perfil: 'superAdmin',
          superAdmin: true,
          clinicaId: '',
          adminDonoId: '',
        ),
      );

      expect(
        () => global.caminhoStorage('documentos/arquivo.pdf'),
        _lancaErroDeEscopo,
      );
    });
  });
}
