class FirebaseHostingGuard {
  static const List<String> passosDeploy = [
    'flutter clean',
    'flutter pub get',
    'flutter build web',
    'firebase deploy',
  ];

  static const List<String> verificacoesObrigatorias = [
    'Firebase inicializado',
    'Hosting configurado',
    'Assets carregando',
    'Login funcionando',
    'Dashboard funcionando',
    'Sem erros no Edge',
  ];

  static bool deploySeguro({
    required bool buildGerado,
    required bool firebaseConectado,
    required bool semErroConsole,
  }) {
    return buildGerado &&
        firebaseConectado &&
        semErroConsole;
  }
}
