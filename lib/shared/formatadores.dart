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
