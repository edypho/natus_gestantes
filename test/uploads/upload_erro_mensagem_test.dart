import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/uploads/upload_erro_mensagem.dart';

void main() {
  group('mensagemErroUpload', () {
    test('explica sessão expirada', () {
      expect(
        mensagemErroUpload('storage/unauthenticated'),
        contains('sessão expirou'),
      );
    });

    test('explica falta de permissão sem expor detalhes internos', () {
      final mensagem = mensagemErroUpload('unauthorized');

      expect(mensagem, contains('não tem permissão'));
      expect(mensagem, contains('vínculo com a clínica'));
    });

    test('orienta repetir envio interrompido', () {
      expect(
        mensagemErroUpload('retry-limit-exceeded'),
        contains('Verifique a internet'),
      );
    });

    test('mantém fallback seguro para código desconhecido', () {
      expect(
        mensagemErroUpload('erro-interno-desconhecido'),
        'Não foi possível enviar o comprovante. '
        'Tente novamente em alguns instantes.',
      );
    });
  });
}
