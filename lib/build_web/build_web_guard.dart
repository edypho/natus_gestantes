class BuildWebGuard {
  static const List<String> comandosSeguros = [
    'flutter clean',
    'flutter pub get',
    'flutter run -d edge',
    'flutter build web',
  ];

  static const List<String> validacoesAntesBuild = [
    'Login funcionando',
    'Dashboard carregando',
    'Financeiro carregando',
    'Pacientes carregando',
    'Exames carregando',
    'Firebase conectado',
  ];

  static bool podeBuildar({
    required bool edgeOk,
    required bool firebaseOk,
    required bool semErroConsole,
  }) {
    return edgeOk && firebaseOk && semErroConsole;
  }
}
