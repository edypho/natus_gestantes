import '../gestantes/gestantes_regras.dart';

/// KPIs do dashboard — contagens sobre a lista de gestantes.
/// Funções puras extraídas do main.dart no Lote 2c.
/// Testes em test/kpis_calculos_test.dart.

int contarBebesPorAno(List<Map<String, String>> gestantes, String ano) {
  int total = 0;

  for (var g in gestantes) {
    final valorData = primeiraDataPreenchida(g, [
      'dataNascimentoBebe',
      'dataNascimento',
    ]);

    final dataNascimento = converterDataDashboard(valorData);

    if (dataNascimento != null && dataNascimento.year.toString() == ano) {
      total++;
    }
  }

  return total;
}

Map<int, int> contarBebesPorMes(
  List<Map<String, String>> gestantes,
  String ano,
) {
  final resultado = <int, int>{};

  for (var g in gestantes) {
    final valorData = primeiraDataPreenchida(g, [
      'dataNascimentoBebe',
      'dataNascimento',
    ]);

    final dataNascimento = converterDataDashboard(valorData);

    if (dataNascimento == null) continue;
    if (dataNascimento.year.toString() != ano) continue;

    final mes = dataNascimento.month;
    resultado[mes] = (resultado[mes] ?? 0) + 1;
  }

  return resultado;
}

int contarBebesNoPeriodoSelecionado(
  List<Map<String, String>> gestantes,
  int mesSelecionado,
  int anoSelecionado,
) {
  int total = 0;

  for (var g in gestantes) {
    final valorData = primeiraDataPreenchida(g, [
      'dataNascimentoBebe',
      'dataNascimento',
    ]);

    final dataNascimento = converterDataDashboard(valorData);

    if (dataNascimento == null) continue;

    if (dataNascimento.month == mesSelecionado &&
        dataNascimento.year == anoSelecionado) {
      total++;
    }
  }

  return total;
}

int contarEncerradasOuHistoricoNoPeriodoDpp(
  List<Map<String, String>> gestantes,
  int mesSelecionado,
  int anoSelecionado,
) {
  int total = 0;

  for (var g in gestantes) {
    final statusAtual = (g['statusGestante'] ?? 'Gestante').trim();

    final ehEncerradaOuHistorico =
        statusAtual == 'Encerrada' || statusAtual == 'Histórico';

    if (ehEncerradaOuHistorico &&
        gestanteEhDoPeriodoSelecionadoPelaDpp(
            g, mesSelecionado, anoSelecionado)) {
      total++;
    }
  }

  return total;
}

Map<int, int> contarGestantesPorMes(
  List<Map<String, String>> gestantes,
  String ano,
) {
  final resultado = <int, int>{};

  for (var g in gestantes) {
    final valorDpp = primeiraDataPreenchida(g, [
      'dpp',
      'DPP',
      'dataDpp',
      'dataDPP',
    ]);

    final dataDpp = converterDataDashboard(valorDpp);

    if (dataDpp == null) continue;
    if (dataDpp.year.toString() != ano) continue;

    final mes = dataDpp.month;
    resultado[mes] = (resultado[mes] ?? 0) + 1;
  }

  return resultado;
}

int contarGestantesPorStatus(
  List<Map<String, String>> gestantes,
  String status,
) {
  int total = 0;

  for (var g in gestantes) {
    final statusAtual = g['statusGestante'] ?? 'Gestante';

    if (statusAtual == status) {
      total++;
    }
  }

  return total;
}

bool gestanteEhDoPeriodoSelecionadoPelaDpp(
  Map<String, String> g,
  int mesSelecionado,
  int anoSelecionado,
) {
  final valorDpp = primeiraDataPreenchida(g, [
    'dpp',
    'DPP',
    'dataDpp',
    'dataDPP',
  ]);

  final dataDpp = converterDataDashboard(valorDpp);

  if (dataDpp == null) return false;

  return dataDpp.month == mesSelecionado && dataDpp.year == anoSelecionado;
}

int contarGestantesPorStatusNoPeriodoDpp(
  List<Map<String, String>> gestantes,
  String status,
  int mesSelecionado,
  int anoSelecionado,
) {
  int total = 0;

  for (var g in gestantes) {
    final statusAtual = g['statusGestante'] ?? 'Gestante';

    if (statusAtual == status &&
        gestanteEhDoPeriodoSelecionadoPelaDpp(
            g, mesSelecionado, anoSelecionado)) {
      total++;
    }
  }

  return total;
}

int contarGestantesProximasDpp(List<Map<String, String>> gestantes) {
  int total = 0;

  for (var g in gestantes) {
    final status = g['statusGestante'] ?? 'Gestante';

    if (status != 'Gestante') continue;

    final dias = diasParaDpp(g['dpp'] ?? '');

    if (dias <= 14) {
      total++;
    }
  }

  return total;
}
