import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/gestantes/indicadores_gestacionais.dart';

void main() {
  group('normalizarRiscoGestacional', () {
    test('normaliza classificações conhecidas', () {
      expect(normalizarRiscoGestacional('risco habitual'), 'Habitual');
      expect(normalizarRiscoGestacional('INTERMEDIARIO'), 'Intermediário');
      expect(normalizarRiscoGestacional('Alto risco'), 'Alto Risco');
    });

    test('valor vazio ou desconhecido vira não informado', () {
      expect(normalizarRiscoGestacional(null), 'Não informado');
      expect(normalizarRiscoGestacional(''), 'Não informado');
      expect(normalizarRiscoGestacional('Outro'), 'Não informado');
    });
  });

  group('normalizarDiabetesGestacional', () {
    test('normaliza respostas com e sem acento', () {
      expect(normalizarDiabetesGestacional('Sim'), 'Sim');
      expect(normalizarDiabetesGestacional('NÃO'), 'Não');
      expect(normalizarDiabetesGestacional('nao informado'), 'Não informado');
    });

    test('valor vazio ou desconhecido vira não informado', () {
      expect(normalizarDiabetesGestacional(null), 'Não informado');
      expect(normalizarDiabetesGestacional(''), 'Não informado');
      expect(normalizarDiabetesGestacional('Talvez'), 'Não informado');
    });
  });

  test('contagens consideram somente gestantes ativas classificadas', () {
    final gestantes = <Map<String, String>>[
      {
        'statusGestante': 'Gestante',
        'riscoGestacional': 'Habitual',
        'diabetesGestacional': 'Não',
      },
      {
        'statusGestante': 'Gestante',
        'riscoGestacional': 'alto risco',
        'diabetesGestacional': 'sim',
      },
      {
        'statusGestante': 'Gestante',
        'riscoGestacional': 'Não informado',
        'diabetesGestacional': 'Não informado',
      },
      {
        'statusGestante': 'Encerrada',
        'riscoGestacional': 'Intermediário',
        'diabetesGestacional': 'Sim',
      },
    ];

    expect(contarRiscosGestacionais(gestantes), {
      'Habitual': 1,
      'Intermediário': 0,
      'Alto Risco': 1,
    });
    expect(contarDiabetesGestacionais(gestantes), {'Sim': 1, 'Não': 1});
  });
}
