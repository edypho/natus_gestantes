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

  group('lancamentoFinanceiroVisivelNoPeriodo', () {
    test('parcela pendente válida aparece na competência', () {
      expect(
        lancamentoFinanceiroVisivelNoPeriodo(
          {
            'vencimento': '05/08/2026',
            'status': 'Pendente',
            'valor': 'R\$ 100,00',
          },
          8,
          2026,
        ),
        isTrue,
      );
    });

    test('baixa remove parcela no mês do pagamento e nos seguintes', () {
      final parcela = {
        'vencimento': '05/08/2026',
        'dataPagamento': '20/07/2026 14:30',
        'status': 'Pago',
        'valor': 'R\$ 100,00',
      };

      expect(lancamentoFinanceiroVisivelNoPeriodo(parcela, 8, 2026), isFalse);
    });

    test('histórico anterior à baixa é preservado', () {
      final parcela = {
        'vencimento': '05/06/2026',
        'dataPagamento': '20/07/2026 14:30',
        'status': 'Pago',
        'valor': 'R\$ 100,00',
      };

      expect(lancamentoFinanceiroVisivelNoPeriodo(parcela, 6, 2026), isTrue);
    });
  });

  group('valorEfetivamenteRecebido', () {
    test('aplica desconto de quitação em registro legado', () {
      expect(
        valorEfetivamenteRecebido({
          'valor': 'R\$ 500,00',
          'quitacaoAntecipada': 'true',
          'descontoQuitacao': '10%',
        }),
        450,
      );
    });

    test('prioriza o valor recebido gravado na baixa', () {
      expect(
        valorEfetivamenteRecebido({
          'valor': 'R\$ 500,00',
          'valorRecebido': 'R\$ 420,00',
        }),
        420,
      );
    });
  });

  group('distribuirSaldoEmParcelas', () {
    test('reduz acordo de 6x para 4x preservando as 2 parcelas pagas', () {
      const valorPlano = 3200.0;
      const valoresPagos = [533.34, 533.33];
      final saldo = valorPlano - valoresPagos.reduce((a, b) => a + b);

      final restantes = distribuirSaldoEmParcelas(saldo, 4 - 2);

      expect(restantes, [1066.67, 1066.66]);
      expect(
        valoresPagos.reduce((a, b) => a + b) +
            restantes.reduce((a, b) => a + b),
        closeTo(valorPlano, 0.001),
      );
    });

    test('fecha diferença de centavos sem perder valor', () {
      final parcelas = distribuirSaldoEmParcelas(100, 3);
      expect(parcelas, [33.34, 33.33, 33.33]);
      expect(parcelas.reduce((a, b) => a + b), closeTo(100, 0.001));
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

    test('total previsto exclui valores já pagos', () {
      expect(calcularTotalPrevistoMesSelecionado(parcelas, 1, 2020), 100.0);
    });

    test('recebido soma apenas pagas do mês', () {
      expect(calcularValorRecebidoMesAtual(parcelas, 1, 2020), 100.0);
    });

    test('a receber soma apenas pendentes do mês', () {
      expect(calcularValorAReceberReal(parcelas, 1, 2020), 100.0);
    });

    test('inadimplência considera somente o saldo ainda aberto', () {
      expect(calcularPercentualInadimplencia(parcelas, 1, 2020), 100.0);
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
