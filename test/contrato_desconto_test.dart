import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/financeiro/financeiro_calculos.dart';
import 'package:natus_gestantes/features/contratos/contratos.dart';

void main() {
  test(
    'Mariana: pagamento à vista com desconto não deixa saldo nem parcela',
    () {
      final paciente = <String, String>{
        'plano': 'Presença',
        'valorPlano': 'R\$ 4.000,00',
        'valorDesconto': 'R\$ 240,00',
        'entrada': 'R\$ 3.760,00',
        'valorParcela': 'R\$ 240,00',
      };
      expect(valorLiquidoPlano(paciente), 3760);
      expect(parcelasDoPlano(paciente, 1), isEmpty);
      final contrato = ContratoPayloadMapper.fromPaciente(
        pacienteId: 'teste',
        paciente: paciente,
        valorTotal: 3760,
        valorEntrada: 3760,
        valorSaldo: 0,
        valorParcela: 0,
        numeroParcelas: 1,
      );
      expect(contrato.valorTotal, 3760);
      expect(contrato.valorSaldo, 0);
      expect(contrato.numeroParcelas, 0);
      expect(contrato.valorParcela, 0);
    },
  );

  test('entrada e parcelas fecham o total líquido em centavos', () {
    final parcelas = parcelasDoPlano({
      'valorPlano': 'R\$ 5.000,00',
      'valorDesconto': 'R\$ 250,00',
      'entrada': 'R\$ 1.000,00',
    }, 7);
    expect(
      parcelas.map((v) => (v * 100).round()).reduce((a, b) => a + b),
      375000,
    );
  });

  test('desconto integral não gera parcelas de valor antigo', () {
    expect(
      parcelasDoPlano({
        'valorPlano': 'R\$ 100,00',
        'valorDesconto': 'R\$ 100,00',
        'valorParcela': 'R\$ 100,00',
      }, 3),
      isEmpty,
    );
  });
}
