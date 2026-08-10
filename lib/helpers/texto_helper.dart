String textoSeguro(dynamic valor, {String fallback = '-'}) {
  if (valor == null) {
    return fallback;
  }

  final texto = valor.toString().trim();

  if (texto.isEmpty) {
    return fallback;
  }

  return texto;
}

bool textoExiste(dynamic valor) {
  if (valor == null) {
    return false;
  }

  return valor.toString().trim().isNotEmpty;
}

String capitalizarPrimeira(String texto) {
  if (texto.trim().isEmpty) {
    return texto;
  }

  return texto[0].toUpperCase() + texto.substring(1);
}
