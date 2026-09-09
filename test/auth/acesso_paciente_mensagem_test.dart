import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/auth/acesso_paciente_mensagem.dart';

void main() {
  group('mensagem de redefinição de senha do paciente', () {
    test('normaliza telefone brasileiro sem duplicar o código do país', () {
      expect(
        normalizarTelefoneWhatsAppBrasil('(11) 99999-9999'),
        '5511999999999',
      );
      expect(
        normalizarTelefoneWhatsAppBrasil('+55 11 99999-9999'),
        '5511999999999',
      );
      expect(
        normalizarTelefoneWhatsAppBrasil('(55) 99999-9999'),
        '5555999999999',
      );
    });

    test('gera URI com mensagem codificada uma única vez', () {
      final uri = uriWhatsAppRedefinicaoSenhaPaciente(
        telefone: '(11) 99999-9999',
        nome: 'Raquel',
        email: 'RAQUEL@EXEMPLO.COM',
      );

      expect(uri.host, 'wa.me');
      expect(uri.path, '/5511999999999');
      expect(
        uri.queryParameters['text'],
        mensagemRedefinicaoSenhaPaciente(
          nome: 'Raquel',
          email: 'raquel@exemplo.com',
        ),
      );
      expect(uri.toString(), isNot(contains('%25')));
      expect(uri.toString(), contains('%F0%9F%A4%8D'));
    });
  });
}
