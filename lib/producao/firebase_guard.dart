class FirebaseGuard {
  static bool podeSalvar({
    required bool usuarioLogado,
    required bool firestoreInicializado,
  }) {
    return usuarioLogado &&
        firestoreInicializado;
  }

  static bool podeBuscarDados({
    required bool firestoreInicializado,
  }) {
    return firestoreInicializado;
  }

  static bool podeFazerUpload({
    required bool storageInicializado,
  }) {
    return storageInicializado;
  }
}
