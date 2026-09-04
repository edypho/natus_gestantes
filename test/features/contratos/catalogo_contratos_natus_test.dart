import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/features/contratos/contratos.dart';

void main() {
  test('catálogo contratual contém somente os dois planos atuais', () {
    expect(CatalogoContratosNatus.templates.map((template) => template.chave), [
      'presenca_consultorio',
      'plenitude_consultorio',
    ]);
    expect(CatalogoContratosNatus.templates[0].valorPadrao, 4000);
    expect(CatalogoContratosNatus.templates[1].valorPadrao, 5000);
  });

  test('planos antigos residenciais migram para o modelo de consultório', () {
    final presenca = CatalogoContratosNatus.localizarPorPlanoEModalidade(
      nomePlano: 'Plano Natus Presença - Residencial',
      consultorio: 'Não',
    );
    final plenitude = CatalogoContratosNatus.localizarPorPlanoEModalidade(
      nomePlano: 'Plenitude',
      consultorio: 'Residencial',
    );

    expect(presenca?.chave, 'presenca_consultorio');
    expect(presenca?.valorPadrao, 4000);
    expect(plenitude?.chave, 'plenitude_consultorio');
    expect(plenitude?.valorPadrao, 5000);
  });

  test('metadados usam valor fixo e recalculam o parcelamento', () {
    final metadados = ContratoPayloadMapper.criarMetadadosIniciais(
      paciente: const {'plano': 'Presença', 'consultorio': 'Não'},
      valorTotal: 3500,
      valorEntrada: 1000,
      valorSaldo: 2500,
      valorParcela: 500,
      numeroParcelas: 5,
    );
    final resumo = Map<String, dynamic>.from(
      metadados['contratoResumo'] as Map,
    );

    expect(metadados['contratoTemplateKey'], 'presenca_consultorio');
    expect(resumo['modalidadeNome'], 'Consultorio');
    expect(resumo['valorTotal'], 4000);
    expect(resumo['valorSaldo'], 3000);
    expect(resumo['valorParcela'], 600);
  });
}
