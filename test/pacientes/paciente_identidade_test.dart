import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/pacientes/paciente_identidade.dart';

void main() {
  group('identidade do paciente', () {
    test('resolve qualquer alias legado', () {
      expect(
        pacienteIdDoRegistro(const {'idGestante': ' paciente-1 '}),
        'paciente-1',
      );
      expect(pacienteUidDoRegistro(const {'gestanteUid': ' uid-1 '}), 'uid-1');
    });

    test('completa todos os aliases canônicos sem perder outros dados', () {
      final resultado = identidadePacienteCanonica(const {
        'nome': 'Raquel',
        'gestanteId': 'paciente-1',
      }, pacienteUid: 'uid-1');

      for (final campo in camposIdPaciente) {
        expect(resultado[campo], 'paciente-1');
      }
      for (final campo in camposUidPaciente) {
        expect(resultado[campo], 'uid-1');
      }
      expect(resultado['nome'], 'Raquel');
    });

    test('rejeita aliases divergentes em vez de escolher silenciosamente', () {
      expect(
        () => identidadePacienteCanonica(const {
          'pacienteId': 'paciente-1',
          'idGestante': 'paciente-2',
        }),
        throwsFormatException,
      );
      expect(
        identidadePacienteConsistente(const {
          'uidPaciente': 'uid-1',
          'uidGestante': 'uid-2',
        }),
        isFalse,
      );
    });

    test('valida vínculo por ID, UID e aliases legados', () {
      expect(
        registroPertenceAoPaciente(
          const {'gestanteId': 'paciente-1', 'pacienteUid': 'uid-1'},
          pacienteId: 'paciente-1',
          pacienteUid: 'uid-1',
        ),
        isTrue,
      );
      expect(
        registroPertenceAoPaciente(
          const {'gestanteId': 'paciente-2', 'pacienteUid': 'uid-1'},
          pacienteId: 'paciente-1',
          pacienteUid: 'uid-1',
        ),
        isFalse,
      );
    });
  });
}
