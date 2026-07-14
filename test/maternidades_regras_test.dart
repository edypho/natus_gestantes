import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/gestantes/maternidades_regras.dart';

void main() {
  group('normalizarMaternidade', () {
    test('unifica os nomes equivalentes informados pela clínica', () {
      final grupos = <String, List<String>>{
        'Maternidade Curitiba': [
          'Maternidade Curitiba',
          'Curitiba',
          'Marenidade Curitiba',
        ],
        'Hospital Santa Cruz': ['Santa Cruz', 'Hospital Santa Cruz'],
        'Hospital Santa Brígida': [
          'Brigida',
          'Santa Brigida',
          'Hospital Santa Brígida',
        ],
        'Hospital Nossa Senhora das Graças': [
          'Graças',
          'Nossa Senhora das Graças',
          'Hospital Nossa Senhora das Gracas',
        ],
      };

      for (final grupo in grupos.entries) {
        for (final variacao in grupo.value) {
          expect(normalizarMaternidade(variacao)?.nome, grupo.key);
        }
      }
    });

    test('ignora valores vazios e não informados', () {
      expect(normalizarMaternidade(null), isNull);
      expect(normalizarMaternidade(''), isNull);
      expect(normalizarMaternidade('Selecione'), isNull);
      expect(normalizarMaternidade('Não informado'), isNull);
    });
  });

  test('contagem agrupa aliases e inclui toda a base histórica', () {
    final pacientes = <Map<String, String>>[
      {'hospitalGestante': 'Brigida', 'statusGestante': 'Gestante'},
      {'hospitalGestante': 'Santa Brígida', 'statusGestante': 'Encerrada'},
      {
        'hospitalGestante': 'Hospital Santa Brigida',
        'statusGestante': 'Histórico',
      },
      {'hospitalGestante': 'Hospital Santa Cruz', 'statusGestante': 'Gestante'},
    ];

    expect(contarPacientesPorMaternidade(pacientes), {
      'Hospital Santa Brígida': 3,
      'Hospital Santa Cruz': 1,
    });
  });
}
