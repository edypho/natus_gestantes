import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/auth/envio_acesso_guard.dart';

void main() {
  group('EnvioAcessoGuard', () {
    test('impede dois envios simultâneos para o mesmo paciente', () {
      final guard = EnvioAcessoGuard();

      expect(guard.iniciar('paciente-1'), isTrue);
      expect(guard.emAndamento('paciente-1'), isTrue);
      expect(guard.iniciar('paciente-1'), isFalse);
    });

    test('libera nova tentativa depois da conclusão', () {
      final guard = EnvioAcessoGuard();

      expect(guard.iniciar(' paciente-1 '), isTrue);
      guard.concluir('paciente-1');

      expect(guard.emAndamento('paciente-1'), isFalse);
      expect(guard.iniciar('paciente-1'), isTrue);
    });

    test('rejeita identificador vazio', () {
      final guard = EnvioAcessoGuard();

      expect(guard.iniciar('   '), isFalse);
    });
  });
}
