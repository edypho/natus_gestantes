class PrimeiroLoginSaaSGuard {
  static bool deveTrocarSenha(Map<String, dynamic>? usuario) {
    if (usuario == null) {
      return false;
    }

    return usuario['primeiroLogin'] == true;
  }

  @Deprecated('Senhas temporárias não são armazenadas nem exibidas.')
  static String senhaTemporaria(Map<String, dynamic>? _) => '';
}
