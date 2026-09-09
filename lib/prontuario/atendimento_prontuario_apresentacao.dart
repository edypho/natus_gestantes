class CampoProntuarioApresentacao {
  const CampoProntuarioApresentacao({
    required this.chave,
    required this.rotulo,
    required this.valor,
  });

  final String chave;
  final String rotulo;
  final String valor;
}

class _CampoProntuarioConfig {
  const _CampoProntuarioConfig(this.chave, this.rotulo);

  final String chave;
  final String rotulo;
}

const _camposAnamnese = <_CampoProntuarioConfig>[
  _CampoProntuarioConfig('queixaPrincipal', 'Queixa principal'),
  _CampoProntuarioConfig('historicoObstetrico', 'Histórico obstétrico'),
  _CampoProntuarioConfig('historicoSaude', 'Histórico de saúde'),
  _CampoProntuarioConfig('alergias', 'Alergias'),
  _CampoProntuarioConfig('medicamentos', 'Medicamentos em uso'),
  _CampoProntuarioConfig('habitos', 'Hábitos e rotina'),
  _CampoProntuarioConfig(
    'aspectosEmocionais',
    'Aspectos emocionais e rede de apoio',
  ),
  _CampoProntuarioConfig('planejamentoParto', 'Planejamento de parto'),
  _CampoProntuarioConfig('amamentacao', 'Intenção / histórico de amamentação'),
];

const _camposExameFisico = <_CampoProntuarioConfig>[
  _CampoProntuarioConfig('pa', 'Pressão arterial'),
  _CampoProntuarioConfig('fc', 'Frequência cardíaca'),
  _CampoProntuarioConfig('temperatura', 'Temperatura'),
  _CampoProntuarioConfig('peso', 'Peso'),
  _CampoProntuarioConfig('altura', 'Altura'),
  _CampoProntuarioConfig('imc', 'IMC'),
  _CampoProntuarioConfig('alturaUterina', 'Altura uterina'),
  _CampoProntuarioConfig('bcf', 'Batimentos cardiofetais (BCF)'),
  _CampoProntuarioConfig('edema', 'Edema'),
  _CampoProntuarioConfig('mamas', 'Mamas'),
  _CampoProntuarioConfig('abdome', 'Abdome'),
  _CampoProntuarioConfig('observacoes', 'Observações clínicas'),
];

const _camposPlanoCuidado = <_CampoProntuarioConfig>[
  _CampoProntuarioConfig('condutas', 'Condutas realizadas'),
  _CampoProntuarioConfig('orientacoes', 'Orientações fornecidas'),
  _CampoProntuarioConfig('encaminhamentos', 'Encaminhamentos'),
  _CampoProntuarioConfig('retorno', 'Retorno previsto'),
  _CampoProntuarioConfig('observacoes', 'Observações adicionais'),
];

const _camposPorTipo = <String, List<_CampoProntuarioConfig>>{
  'anamnese': _camposAnamnese,
  'exame físico': _camposExameFisico,
  'plano de cuidado': _camposPlanoCuidado,
};

const _todosOsCamposClinicos = <_CampoProntuarioConfig>[
  ..._camposAnamnese,
  ..._camposExameFisico,
  ..._camposPlanoCuidado,
];

/// Converte os dados persistidos em conteúdo seguro para apresentação.
///
/// A lista permitida é intencional: IDs, vínculos de clínica, autoria técnica
/// e outros metadados nunca devem aparecer como conteúdo clínico da timeline.
List<CampoProntuarioApresentacao> camposClinicosDoAtendimento(
  Map<String, dynamic> dados,
) {
  final tipo = (dados['tipo'] ?? '').toString().trim().toLowerCase();
  final configuracoes = _camposPorTipo[tipo] ?? _todosOsCamposClinicos;
  final chavesIncluidas = <String>{};
  final resultado = <CampoProntuarioApresentacao>[];

  for (final configuracao in configuracoes) {
    if (!chavesIncluidas.add(configuracao.chave)) continue;

    final valorOriginal = dados[configuracao.chave];
    if (valorOriginal == null) continue;

    final valor = valorOriginal.toString().trim();
    if (valor.isEmpty) continue;

    resultado.add(
      CampoProntuarioApresentacao(
        chave: configuracao.chave,
        rotulo: configuracao.rotulo,
        valor: valor,
      ),
    );
  }

  return resultado;
}
