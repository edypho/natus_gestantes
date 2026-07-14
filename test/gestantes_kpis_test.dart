import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/gestantes/gestantes_regras.dart';
import 'package:natus_gestantes/kpis/kpis_calculos.dart';

void main() {
  group('statusGestanteNormalizado', () {
    test('normaliza variações com e sem acento', () {
      expect(
        statusGestanteNormalizado({'statusGestante': 'puerpera'}),
        'Puérpera',
      );
      expect(
        statusGestanteNormalizado({'statusGestante': 'PUÉRPERA'}),
        'Puérpera',
      );
      expect(
        statusGestanteNormalizado({'statusGestante': 'encerrado'}),
        'Encerrada',
      );
      expect(
        statusGestanteNormalizado({'statusGestante': 'histórico'}),
        'Histórico',
      );
    });

    test('ausente ou desconhecido vira Gestante', () {
      expect(statusGestanteNormalizado({}), 'Gestante');
      expect(
        statusGestanteNormalizado({'statusGestante': 'outro'}),
        'Gestante',
      );
    });
  });

  group('gestanteEstaAtiva', () {
    test('gestante e puérpera são ativas', () {
      expect(gestanteEstaAtiva({'statusGestante': 'Gestante'}), isTrue);
      expect(gestanteEstaAtiva({'statusGestante': 'Puérpera'}), isTrue);
    });

    test('flag historico desativa mesmo com status ativo', () {
      expect(
        gestanteEstaAtiva({'statusGestante': 'Gestante', 'historico': 'true'}),
        isFalse,
      );
      expect(
        gestanteEstaAtiva({'statusGestante': 'Gestante', 'historico': 'sim'}),
        isFalse,
      );
    });

    test('encerrada não é ativa', () {
      expect(gestanteEstaAtiva({'statusGestante': 'Encerrada'}), isFalse);
    });
  });

  group('gestanteApareceNaBusca', () {
    final g = {
      'nomeGestante': 'Maria Silva',
      'cidadeGestante': 'Maringá',
      'nomeBebe': 'Alice',
    };

    test('busca vazia retorna tudo', () {
      expect(gestanteApareceNaBusca(g, ''), isTrue);
      expect(gestanteApareceNaBusca(g, '   '), isTrue);
    });

    test('encontra por nome, cidade e bebê, sem case', () {
      expect(gestanteApareceNaBusca(g, 'maria'), isTrue);
      expect(gestanteApareceNaBusca(g, 'MARINGÁ'), isTrue);
      expect(gestanteApareceNaBusca(g, 'alice'), isTrue);
      expect(gestanteApareceNaBusca(g, 'joana'), isFalse);
    });
  });

  group('converterDataDashboard', () {
    test('aceita ISO, brasileiro e brasileiro com hora', () {
      expect(
        converterDataDashboard('2026-05-22T17:38:36.210'),
        DateTime(2026, 5, 22, 17, 38, 36, 210),
      );
      expect(converterDataDashboard('03/06/2026'), DateTime(2026, 6, 3));
      expect(converterDataDashboard('03/06/2026 14:30'), DateTime(2026, 6, 3));
    });

    test('aceita formato Timestamp do Firestore', () {
      final d = converterDataDashboard(
        'Timestamp(seconds=1750000000, nanoseconds=0)',
      );
      expect(d, DateTime.fromMillisecondsSinceEpoch(1750000000 * 1000));
    });

    test('inválido ou vazio retorna null', () {
      expect(converterDataDashboard(null), isNull);
      expect(converterDataDashboard(''), isNull);
      expect(converterDataDashboard('abc'), isNull);
    });
  });

  group('KPIs', () {
    final gestantes = [
      {
        'statusGestante': 'Gestante',
        'dpp': '15/07/2026',
        'dataNascimentoBebe': '',
      },
      {'statusGestante': 'Puérpera', 'dataNascimentoBebe': '10/07/2026'},
      {'statusGestante': 'Encerrada', 'dpp': '20/07/2026'},
      {'statusGestante': 'Gestante', 'dpp': '05/01/2027'},
    ];

    test('contarBebesPorAno usa data de nascimento', () {
      expect(contarBebesPorAno(gestantes, '2026'), 1);
      expect(contarBebesPorAno(gestantes, '2025'), 0);
    });

    test('contarBebesPorMes agrupa por mês', () {
      expect(contarBebesPorMes(gestantes, '2026'), {7: 1});
    });

    test('contarGestantesPorStatus conta exato', () {
      expect(contarGestantesPorStatus(gestantes, 'Gestante'), 2);
      expect(contarGestantesPorStatus(gestantes, 'Encerrada'), 1);
    });

    test('período por DPP: julho/2026 tem 2 (uma ativa, uma encerrada)', () {
      expect(
        gestanteEhDoPeriodoSelecionadoPelaDpp(gestantes[0], 7, 2026),
        isTrue,
      );
      expect(
        contarGestantesPorStatusNoPeriodoDpp(gestantes, 'Encerrada', 7, 2026),
        1,
      );
      expect(contarEncerradasOuHistoricoNoPeriodoDpp(gestantes, 7, 2026), 1);
    });

    test('contarGestantesPorMes agrupa DPPs do ano', () {
      expect(contarGestantesPorMes(gestantes, '2026'), {7: 2});
      expect(contarGestantesPorMes(gestantes, '2027'), {1: 1});
    });
  });

  group('métricas por obstetra', () {
    test(
      'carteira total inclui pacientes ativas, encerradas e do histórico',
      () {
        final pacientes = <Map<String, String>>[
          {
            'nomeGestante': 'Ativa',
            'obstetraGestante': 'Dra. Ana',
            'statusGestante': 'Gestante',
          },
          {
            'nomeGestante': 'Encerrada',
            'obstetraGestante': 'Dra. Ana',
            'statusGestante': 'Encerrada',
            'dataNascimentoBebe': '10/01/2025',
          },
          {
            'nomeGestante': 'Legado',
            'obstetraGestante': 'Ana',
            'statusGestante': 'Histórico',
          },
          {
            'nomeGestante': 'Outra carteira',
            'obstetraGestante': 'Dra. Beatriz',
            'statusGestante': 'Gestante',
          },
        ];

        final metricas = calcularMetricasObstetra(pacientes, 'Dra. Ana');

        expect(metricas.totalCarteira, 3);
        expect(metricas.ativasNaCarteira, 1);
        expect(metricas.jaPariu, 1);
      },
    );
  });
}

// Testes adicionados com a visibilidade por obstetra (jul/2026).
// Mantidos no mesmo arquivo para rodarem junto do domínio de gestantes.
