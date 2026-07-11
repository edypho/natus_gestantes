import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/financeiro/financeiro_calculos.dart';

void main() {
  final parcelas = [
    {'gestante': 'Maria Silva', 'status': 'Pago', 'valor': 'R\$ 480,00'},
    {'gestante': 'Maria Silva', 'status': 'Pendente', 'valor': 'R\$ 480,00'},
    {'gestante': 'maria silva ', 'status': 'Pendente', 'valor': 'R\$ 480,00'},
    {'gestante': 'Ana Costa', 'status': 'Pendente', 'valor': 'R\$ 900,00'},
  ];

  group('parcelasPendentesDaGestante', () {
    test('filtra por gestante ignorando caixa/espaços e exclui pagas', () {
      final pendentes = parcelasPendentesDaGestante(parcelas, 'Maria Silva');
      expect(pendentes.length, 2);
      expect(pendentes.every((p) => p['status'] != 'Pago'), isTrue);
    });

    test('gestante sem pendências retorna vazio', () {
      final maria = [
        {'gestante': 'Maria', 'status': 'Pago', 'valor': 'R\$ 100,00'},
      ];
      expect(parcelasPendentesDaGestante(maria, 'Maria'), isEmpty);
    });
  });

  group('somarValorParcelas', () {
    test('soma formato brasileiro', () {
      final pendentes = parcelasPendentesDaGestante(parcelas, 'Maria Silva');
      expect(somarValorParcelas(pendentes), 960.0);
    });
  });

  group('valorQuitacaoComDesconto', () {
    test('aplica percentual e arredonda a centavos', () {
      expect(valorQuitacaoComDesconto(960.0, 5), 912.0);
      expect(valorQuitacaoComDesconto(1000.0, 0), 1000.0);
      expect(valorQuitacaoComDesconto(333.33, 10), 300.0);
    });

    test('limita percentual fora da faixa', () {
      expect(valorQuitacaoComDesconto(100.0, 150), 0.0);
      expect(valorQuitacaoComDesconto(100.0, -5), 100.0);
    });
  });
}
