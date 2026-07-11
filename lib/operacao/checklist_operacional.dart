class ChecklistOperacionalNatus {
  static const List<String> validacoesCriticas = [
    'Login superAdmin',
    'Login admin',
    'Dashboard carregando',
    'Cadastro de gestante',
    'Parcelas geradas',
    'Financeiro filtrando',
    'Exames abrindo',
    'Documentos abrindo',
    'Mapa carregando',
    'Biblioteca carregando',
  ];

  static const List<String> comandosFinais = [
    'flutter clean',
    'flutter pub get',
    'flutter run -d edge',
    'flutter build web',
    'firebase deploy',
  ];

  static bool sistemaProntoParaOperar({
    required bool loginOk,
    required bool dashboardOk,
    required bool gestantesOk,
    required bool financeiroOk,
    required bool examesOk,
  }) {
    return loginOk &&
        dashboardOk &&
        gestantesOk &&
        financeiroOk &&
        examesOk;
  }
}
