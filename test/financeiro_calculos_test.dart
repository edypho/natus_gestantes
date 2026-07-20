import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/financeiro/financeiro_calculos.dart';

void main() {
  group('calcularSaldoAReceber', () {
    test('soma valores de plano em formato brasileiro', () {
      final gestantes = [
        {'valorPlano': 'R\$ 1.500,00'},
        {'valorPlano': 'R\$ 2.000,50'},
      ];
      expect(calcularSaldoAReceber(gestantes), 3500.50);
    });

    test('ignora valores inválidos ou ausentes', () {
      final gestantes = [
        {'valorPlano': 'abc'},
        <String, String>{},
      ];
      expect(calcularSaldoAReceber(gestantes), 0);
    });
  });

  group('parcelaEhDoMesSelecionado', () {
    test('reconhece parcela do mês/ano selecionado', () {
      expect(
        parcelaEhDoMesSelecionado({'vencimento': '10/07/2026'}, 7, 2026),
        isTrue,
      );
      expect(
        parcelaEhDoMesSelecionado({'vencimento': '10/08/2026'}, 7, 2026),
        isFalse,
      );
    });

    test('vencimento malformado retorna false sem lançar', () {
      expect(parcelaEhDoMesSelecionado({'vencimento': 'x'}, 7, 2026), isFalse);
      expect(parcelaEhDoMesSelecionado({}, 7, 2026), isFalse);
    });
  });

  group('lancamentoFinanceiroValido', () {
    test('aceita lançamento com valor positivo', () {
      expect(lancamentoFinanceiroValido({'valor': 'R\$ 120,50'}), isTrue);
    });

    test('ignora registros legados sem valor', () {
      expect(lancamentoFinanceiroValido({'valor': 'R\$ 0,00'}), isFalse);
      expect(lancamentoFinanceiroValido({'valor': ''}), isFalse);
      expect(lancamentoFinanceiroValido({}), isFalse);
    });

    test('ignora lançamento explicitamente cancelado', () {
      expect(
        lancamentoFinanceiroValido({
          'valor': 'R\$ 100,00',
          'statusRegistro': 'cancelado',
        }),
        isFalse,
      );
    });
  });

  group('parcelaEstaAtrasada', () {
    test('pendente com vencimento no passado está atrasada', () {
      expect(
        parcelaEstaAtrasada({'vencimento': '05/01/2020', 'status': 'Pendente'}),
        isTrue,
      );
    });

    test('paga nunca está atrasada', () {
      expect(
        parcelaEstaAtrasada({'vencimento': '05/01/2020', 'status': 'Pago'}),
        isFalse,
      );
    });

    test('vencimento no futuro não está atrasada', () {
      expect(
        parcelaEstaAtrasada({'vencimento': '05/01/2099', 'status': 'Pendente'}),
        isFalse,
      );
    });
  });

  group('cálculos do mês selecionado', () {
    final parcelas = [
      {'vencimento': '05/01/2020', 'status': 'Pago', 'valor': 'R\$ 100,00'},
      {'vencimento': '05/01/2020', 'status': 'Pendente', 'valor': 'R\$ 100,00'},
      {'vencimento': '05/02/2020', 'status': 'Pendente', 'valor': 'R\$ 999,00'},
      {
        'vencimento': '05/01/2020',
        'status': 'Pendente',
        'statusRegistro': 'cancelado',
        'valor': 'R\$ 700,00',
      },
      {'vencimento': '05/01/2020', 'status': 'Pendente', 'valor': 'R\$ 0,00'},
    ];

    test('total previsto considera só o mês selecionado', () {
      expect(calcularTotalPrevistoMesSelecionado(parcelas, 1, 2020), 200.0);
    });

    test('recebido soma apenas pagas do mês', () {
      expect(calcularValorRecebidoMesAtual(parcelas, 1, 2020), 100.0);
    });

    test('a receber soma apenas pendentes do mês', () {
      expect(calcularValorAReceberReal(parcelas, 1, 2020), 100.0);
    });

    test('inadimplência: 100 atrasado sobre 200 previsto = 50%', () {
      expect(calcularPercentualInadimplencia(parcelas, 1, 2020), 50.0);
    });

    test(
      'inadimplência sem parcelas no período é 0 (sem divisão por zero)',
      () {
        expect(calcularPercentualInadimplencia(parcelas, 6, 2030), 0);
      },
    );
  });

  group('calcularQuintoDiaUtil', () {
    test('julho/2026: 5º dia útil é dia 7 (1º cai na quarta)', () {
      expect(calcularQuintoDiaUtil(2026, 7), DateTime(2026, 7, 7));
    });

    test('fevereiro/2026: 1º cai no domingo, 5º dia útil é dia 6', () {
      expect(calcularQuintoDiaUtil(2026, 2), DateTime(2026, 2, 6));
    });
  });

  group('formatarDataFinanceira', () {
    test('formata com zeros à esquerda', () {
      expect(formatarDataFinanceira(DateTime(2026, 7, 8)), '08/07/2026');
    });
  });
}
