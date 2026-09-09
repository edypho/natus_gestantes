import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/prontuario/prontuario_identidade.dart';

void main() {
  group('identidadePacienteProntuario', () {
    test('grava aliases canônicos e legados com os mesmos valores', () {
      final identidade = identidadePacienteProntuario(
        pacienteId: ' paciente-1 ',
        pacienteUid: ' uid-1 ',
      );

      expect(identidade, {
        'pacienteId': 'paciente-1',
        'gestanteId': 'paciente-1',
        'idGestante': 'paciente-1',
        'uidPaciente': 'uid-1',
        'pacienteUid': 'uid-1',
        'uidGestante': 'uid-1',
        'gestanteUid': 'uid-1',
      });
    });

    test('permite paciente sem login, preservando aliases de UID vazios', () {
      final identidade = identidadePacienteProntuario(
        pacienteId: 'paciente-sem-login',
      );

      expect(identidade['pacienteId'], 'paciente-sem-login');
      expect(identidade['uidPaciente'], isEmpty);
      expect(identidade['uidGestante'], isEmpty);
    });

    test('rejeita identificador de paciente vazio', () {
      expect(
        () => identidadePacienteProntuario(pacienteId: '  '),
        throwsArgumentError,
      );
    });
  });
}
