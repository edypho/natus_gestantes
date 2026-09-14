import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/core/natus_especialidades.dart';

void main() {
  test('catálogo cobre acompanhamentos clínicos e obstétricos', () {
    expect(NatusEspecialidades.opcoes, contains('Clínica geral'));
    expect(NatusEspecialidades.opcoes, contains('Obstetrícia'));
    expect(NatusEspecialidades.opcoes, contains('Pediatria'));
    expect(NatusEspecialidades.opcoes, contains('Psicologia'));
  });

  test('somente obstetrícia ativa o módulo obstétrico', () {
    expect(NatusEspecialidades.ehObstetricia('Obstetrícia'), isTrue);
    expect(NatusEspecialidades.ehObstetricia('Clínica geral'), isFalse);
  });

  test('adapta o vínculo solicitado conforme a especialidade', () {
    expect(
      NatusEspecialidades.tituloContato('Obstetrícia'),
      'Cônjuge / acompanhante',
    );
    expect(NatusEspecialidades.tituloContato('Pediatria'), 'Responsável legal');
    expect(
      NatusEspecialidades.tituloContato('Cardiologia'),
      'Contato de emergência (opcional)',
    );
  });
}
