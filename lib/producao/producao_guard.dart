class ProducaoGuard {
  static bool bloquearNull(dynamic valor) {
    return valor != null;
  }

  static String textoSeguro(dynamic valor) {
    if (valor == null) {
      return '-';
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return '-';
    }

    return texto;
  }

  static bool listaSegura(List? lista) {
    return lista != null;
  }

  static bool mapaSeguro(Map? mapa) {
    return mapa != null;
  }

  static bool loginSeguro({required String email, required String senha}) {
    return email.trim().isNotEmpty && senha.trim().isNotEmpty;
  }
}
