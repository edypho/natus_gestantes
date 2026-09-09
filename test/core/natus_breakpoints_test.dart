import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/core/natus_breakpoints.dart';

void main() {
  group('NatusBreakpoints', () {
    test('mantém iPhone em layout compacto nas duas orientações', () {
      expect(
        NatusBreakpoints.usarLayoutCompactoParaTamanho(const Size(390, 844)),
        isTrue,
      );
      expect(
        NatusBreakpoints.usarLayoutCompactoParaTamanho(const Size(844, 390)),
        isTrue,
      );
    });

    test('não classifica iPad ou desktop como telefone', () {
      expect(
        NatusBreakpoints.tamanhoDeTelefone(const Size(768, 1024)),
        isFalse,
      );
      expect(
        NatusBreakpoints.tamanhoDeTelefone(const Size(1440, 900)),
        isFalse,
      );
    });

    test('preserva breakpoints específicos de cada tela', () {
      expect(
        NatusBreakpoints.usarLayoutCompactoParaTamanho(
          const Size(768, 1024),
          larguraLimite: 800,
        ),
        isTrue,
      );
      expect(
        NatusBreakpoints.usarLayoutCompactoParaTamanho(
          const Size(1024, 768),
          larguraLimite: 800,
        ),
        isFalse,
      );
    });
  });
}
