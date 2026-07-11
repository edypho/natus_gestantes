class PlanoSaaS {
  final String nome;
  final int maxGestantes;
  final bool financeiro;
  final bool dashboard;
  final bool exames;
  final bool documentos;
  final bool logs;

  const PlanoSaaS({
    required this.nome,
    required this.maxGestantes,
    required this.financeiro,
    required this.dashboard,
    required this.exames,
    required this.documentos,
    required this.logs,
  });
}

class PlanosNatus {
  static const PlanoSaaS natusInterno = PlanoSaaS(
    nome: 'Natus Interno',
    maxGestantes: 999999,
    financeiro: true,
    dashboard: true,
    exames: true,
    documentos: true,
    logs: true,
  );

  static const PlanoSaaS clinicaStart = PlanoSaaS(
    nome: 'Clínica Start',
    maxGestantes: 30,
    financeiro: true,
    dashboard: true,
    exames: true,
    documentos: true,
    logs: false,
  );

  static const PlanoSaaS clinicaPremium = PlanoSaaS(
    nome: 'Clínica Premium',
    maxGestantes: 300,
    financeiro: true,
    dashboard: true,
    exames: true,
    documentos: true,
    logs: true,
  );
}
