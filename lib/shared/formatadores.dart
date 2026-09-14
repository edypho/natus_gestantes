double converterValor(String texto) {
  final limpo = texto
      .replaceAll('R\$', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();

  if (limpo.isEmpty) return 0;

  return double.tryParse(limpo) ?? 0;
}

double converterPercentual(String texto) {
  final limpo = texto.replaceAll('%', '').trim();
  final percentual = double.tryParse(limpo) ?? 0;
  return percentual / 100;
}

String formatarMoeda(double valor) {
  return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}

/// Formata percentual no padrão brasileiro (vírgula decimal), com sinal
/// explícito de + ou - para deixar clara a direção do crescimento.
/// Ex.: 47.6 -> "+47,6%"; -12.34 -> "-12,3%"; 0 -> "0,0%".
String formatarPercentual(double valor, {bool comSinal = true}) {
  final sinal = comSinal && valor > 0 ? '+' : '';
  return '$sinal${valor.toStringAsFixed(1).replaceAll('.', ',')}%';
}
