class NullGuard {
  static String texto(dynamic valor) {
    if (valor == null) {
      return '-';
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return '-';
    }

    return texto;
  }

  static List lista(dynamic valor) {
    if (valor == null) {
      return [];
    }

    if (valor is List) {
      return valor;
    }

    return [];
  }

  static Map mapa(dynamic valor) {
    if (valor == null) {
      return {};
    }

    if (valor is Map) {
      return valor;
    }

    return {};
  }
}
