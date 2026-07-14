import 'gestantes_regras.dart';

const opcoesRiscoGestacional = <String>[
  'Não informado',
  'Habitual',
  'Intermediário',
  'Alto Risco',
];

const opcoesDiabetesGestacional = <String>['Não informado', 'Sim', 'Não'];

String normalizarRiscoGestacional(String? valor) {
  final normalizado = _normalizar(valor);

  if (normalizado.contains('alto')) return 'Alto Risco';
  if (normalizado.contains('inter')) return 'Intermediário';
  if (normalizado.contains('habit')) return 'Habitual';

  return 'Não informado';
}

String normalizarDiabetesGestacional(String? valor) {
  final normalizado = _normalizar(valor);

  if (normalizado.isEmpty || normalizado.contains('informado')) {
    return 'Não informado';
  }
  if (normalizado.startsWith('sim')) return 'Sim';
  if (normalizado.startsWith('nao')) return 'Não';

  return 'Não informado';
}

Map<String, int> contarRiscosGestacionais(
  Iterable<Map<String, String>> gestantes,
) {
  final resultado = {'Habitual': 0, 'Intermediário': 0, 'Alto Risco': 0};

  for (final gestante in gestantesAtivas(gestantes.toList())) {
    final classificacao = normalizarRiscoGestacional(
      gestante['riscoGestacional'],
    );

    if (resultado.containsKey(classificacao)) {
      resultado[classificacao] = resultado[classificacao]! + 1;
    }
  }

  return resultado;
}

Map<String, int> contarDiabetesGestacionais(
  Iterable<Map<String, String>> gestantes,
) {
  final resultado = {'Sim': 0, 'Não': 0};

  for (final gestante in gestantesAtivas(gestantes.toList())) {
    final classificacao = normalizarDiabetesGestacional(
      gestante['diabetesGestacional'],
    );

    if (resultado.containsKey(classificacao)) {
      resultado[classificacao] = resultado[classificacao]! + 1;
    }
  }

  return resultado;
}

String _normalizar(String? valor) {
  return (valor ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
}
