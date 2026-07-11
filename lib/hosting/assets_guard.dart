class AssetsGuard {
  static bool assetValido(String? caminho) {
    if (caminho == null) {
      return false;
    }

    return caminho.trim().isNotEmpty;
  }

  static bool logoDisponivel(String? caminhoLogo) {
    return assetValido(caminhoLogo);
  }
}
