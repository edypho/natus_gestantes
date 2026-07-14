/// Regras de agrupamento de maternidades usadas nos indicadores obstétricos.
library;

class MaternidadeNormalizada {
  const MaternidadeNormalizada({required this.chave, required this.nome});

  final String chave;
  final String nome;
}

const _nomesCanonicos = <String, String>{
  'curitiba': 'Maternidade Curitiba',
  'santa cruz': 'Hospital Santa Cruz',
  'brigida': 'Hospital Santa Brígida',
  'santa brigida': 'Hospital Santa Brígida',
  'gracas': 'Hospital Nossa Senhora das Graças',
  'nossa senhora das gracas': 'Hospital Nossa Senhora das Graças',
};

String _textoNormalizado(String texto) {
  return texto
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Retorna a chave de agrupamento e o nome que deve aparecer no ranking.
///
/// Prefixos institucionais não diferenciam unidades: por exemplo, "Hospital
/// Santa Cruz" e "Santa Cruz" apontam para a mesma maternidade.
MaternidadeNormalizada? normalizarMaternidade(String? valor) {
  final nomeInformado = (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (nomeInformado.isEmpty) return null;

  var chave = _textoNormalizado(nomeInformado);
  if (chave == 'selecione' || chave == 'nao informado' || chave == 'nenhum') {
    return null;
  }

  chave = chave
      .replaceFirst(
        RegExp(
          r'^(?:hospital|maternidade|marenidade)(?:\s+e\s+(?:hospital|maternidade|marenidade))?\s+',
        ),
        '',
      )
      .trim();

  if (chave.isEmpty) return null;

  final nomeCanonico = _nomesCanonicos[chave];
  return MaternidadeNormalizada(
    chave: nomeCanonico == null ? chave : _textoNormalizado(nomeCanonico),
    nome: nomeCanonico ?? nomeInformado,
  );
}

/// Conta cada paciente uma vez na maternidade informada, sem filtrar status.
/// Assim, a base inclui registros ativos, encerrados e de histórico/legado.
Map<String, int> contarPacientesPorMaternidade(
  List<Map<String, String>> pacientes,
) {
  final quantidadePorChave = <String, int>{};
  final nomePorChave = <String, String>{};

  for (final paciente in pacientes) {
    final maternidade = normalizarMaternidade(paciente['hospitalGestante']);
    if (maternidade == null) continue;

    nomePorChave.putIfAbsent(maternidade.chave, () => maternidade.nome);
    quantidadePorChave[maternidade.chave] =
        (quantidadePorChave[maternidade.chave] ?? 0) + 1;
  }

  return {
    for (final item in quantidadePorChave.entries)
      nomePorChave[item.key]!: item.value,
  };
}
