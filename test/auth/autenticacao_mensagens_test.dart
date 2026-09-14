import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/auth/autenticacao_mensagens.dart';

void main() {
  group('autenticação', () {
    test('normaliza o e-mail sem alterar nenhum caractere da senha', () {
      final credenciais = credenciaisAcesso(
        email: '  PACIENTE@EXEMPLO.COM ',
        senha: ' senha com espaços ',
      );

      expect(credenciais.email, 'paciente@exemplo.com');
      expect(credenciais.senha, ' senha com espaços ');
    });

    test('valida formato mínimo de e-mail', () {
      expect(emailAcessoValido('paciente@exemplo.com'), isTrue);
      expect(emailAcessoValido('paciente@'), isFalse);
      expect(emailAcessoValido('paciente exemplo.com'), isFalse);
    });

    test('não revela se um e-mail está cadastrado', () {
      expect(
        mensagemErroRedefinicaoSenha('user-not-found'),
        mensagemRedefinicaoSenhaSolicitada,
      );
      expect(mensagemRedefinicaoSenhaSolicitada, isNot(contains('não existe')));
    });

    test('explica falhas operacionais sem expor detalhes internos', () {
      expect(mensagemErroLogin('network-request-failed'), contains('internet'));
      expect(
        mensagemErroLogin('invalid-credential'),
        'E-mail ou senha inválidos.',
      );
      expect(
        mensagemErroRedefinicaoSenha('internal-error'),
        'Não foi possível solicitar a redefinição de senha agora.',
      );
    });

    test('orienta a equipe quando o login ainda não existe', () {
      expect(
        mensagemErroEnvioAcessoParaEquipe('user-not-found'),
        'Não existe um login vinculado a esse e-mail. Revise o cadastro.',
      );
      expect(
        mensagemErroEnvioAcessoParaEquipe('network-request-failed'),
        contains('internet'),
      );
    });
  });
}
