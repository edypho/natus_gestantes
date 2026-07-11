class PreBuildCheck {
  static const List<String> itensCriticos = [
    'flutter run -d edge',
    'flutter build web',
    'firebase deploy',
  ];

  static const List<String> colecoesCriticas = [
    'usuarios',
    'gestantes',
    'atendimentos',
    'parcelasFinanceiras',
    'documentos',
    'exames',
    'biblioteca',
  ];

  static bool podeGerarBuild({
    required bool appRodandoNoEdge,
    required bool loginValidado,
    required bool dashboardValidado,
    required bool financeiroValidado,
  }) {
    return appRodandoNoEdge &&
        loginValidado &&
        dashboardValidado &&
        financeiroValidado;
  }
}
