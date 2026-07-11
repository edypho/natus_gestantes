class PrimeiroLoginSaaSGuard {
  static bool deveTrocarSenha(Map<String, dynamic>? usuario) {
    if (usuario == null) {
      return false;
    }

    return usuario['primeiroLogin'] == true;
  }

  static String senhaTemporaria(Map<String, dynamic>? usuario) {
    return usuario?['senhaTemporaria']?.toString() ?? '';
  }
}
