import '../gestantes/gestantes_regras.dart';
import '../gestantes/indicadores_gestacionais.dart';

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

/// Anos com pelo menos um nascimento registrado, em ordem crescente.
/// Base para o gráfico de crescimento e os cards de KPI: em vez de
/// comparar sempre "2025 vs 2026" fixo no código, o app descobre
/// sozinho quais anos existem no banco.
List<int> anosComNascimentos(List<Map<String, String>> gestantes) {
  final anos = <int>{};

  for (var g in gestantes) {
    final valorData = primeiraDataPreenchida(g, [
      'dataNascimentoBebe',
      'dataNascimento',
    ]);

    final data = converterDataDashboard(valorData);
    if (data != null) anos.add(data.year);
  }

  final lista = anos.toList()..sort();
  return lista;
}

/// Total de nascimentos de um ano, somando janeiro até [mesLimite]
/// (inclusive). Usado para comparar períodos equivalentes entre anos
/// diferentes — ex.: janeiro–julho/2026 vs janeiro–julho/2025 — em vez
/// de comparar um ano parcial com um ano fechado.
int contarBebesAteMes(
  List<Map<String, String>> gestantes,
  int ano,
  int mesLimite,
) {
  final porMes = contarBebesPorMes(gestantes, ano.toString());
  var total = 0;

  for (var mes = 1; mes <= mesLimite && mes <= 12; mes++) {
    total += porMes[mes] ?? 0;
  }

  return total;
}

/// Pacote completo de indicadores de crescimento anual de nascimentos,
/// calculado sobre os anos disponíveis no banco (sem ano fixo no código).
class CrescimentoNascimentosKpis {
  final int anoAtual;
  final int mesAtual;
  final List<int> anosDisponiveis;
  final Map<int, int> totalPorAno;

  /// % de crescimento no período comparável (jan–mês atual, ano atual
  /// vs mesmo período do ano anterior). Null se não há ano anterior.
  final double? crescimentoPeriodoComparavel;

  /// % de crescimento do mês atual vs o mesmo mês no ano anterior.
  final double? crescimentoMesAtual;

  /// Média das variações % ano-a-ano entre todos os pares de anos
  /// consecutivos disponíveis (crescimento histórico médio).
  final double? mediaCrescimentoHistorico;

  final int melhorAno;
  final int melhorAnoTotal;
  final int totalHistorico;

  const CrescimentoNascimentosKpis({
    required this.anoAtual,
    required this.mesAtual,
    required this.anosDisponiveis,
    required this.totalPorAno,
    required this.crescimentoPeriodoComparavel,
    required this.crescimentoMesAtual,
    required this.mediaCrescimentoHistorico,
    required this.melhorAno,
    required this.melhorAnoTotal,
    required this.totalHistorico,
  });
}

double? _variacaoPercentual(int atual, int anterior) {
  if (anterior == 0) return null; // evita divisão por zero / infinito
  return ((atual - anterior) / anterior) * 100;
}

CrescimentoNascimentosKpis calcularCrescimentoNascimentos(
  List<Map<String, String>> gestantes, {
  DateTime? agora,
}) {
  final hoje = agora ?? DateTime.now();
  final anoAtual = hoje.year;
  final mesAtual = hoje.month;

  final anos = anosComNascimentos(gestantes);

  final totalPorAno = <int, int>{
    for (final ano in anos) ano: contarBebesPorAno(gestantes, ano.toString()),
  };

  final temAnoAnterior = anos.contains(anoAtual - 1);

  final crescimentoPeriodoComparavel = temAnoAnterior
      ? _variacaoPercentual(
          contarBebesAteMes(gestantes, anoAtual, mesAtual),
          contarBebesAteMes(gestantes, anoAtual - 1, mesAtual),
        )
      : null;

  final crescimentoMesAtual = temAnoAnterior
      ? _variacaoPercentual(
          contarBebesPorMes(gestantes, anoAtual.toString())[mesAtual] ?? 0,
          contarBebesPorMes(gestantes, (anoAtual - 1).toString())[mesAtual] ??
              0,
        )
      : null;

  // Média das variações % entre cada par de anos consecutivos completos
  // disponíveis (ignora o ano atual, que costuma estar em andamento).
  final anosFechados = anos.where((a) => a != anoAtual).toList()..sort();
  final variacoes = <double>[];
  for (var i = 1; i < anosFechados.length; i++) {
    final anterior = totalPorAno[anosFechados[i - 1]] ?? 0;
    final atual = totalPorAno[anosFechados[i]] ?? 0;
    final variacao = _variacaoPercentual(atual, anterior);
    if (variacao != null) variacoes.add(variacao);
  }
  final mediaCrescimentoHistorico = variacoes.isEmpty
      ? null
      : variacoes.reduce((a, b) => a + b) / variacoes.length;

  var melhorAno = anoAtual;
  var melhorAnoTotal = 0;
  totalPorAno.forEach((ano, total) {
    if (total > melhorAnoTotal) {
      melhorAno = ano;
      melhorAnoTotal = total;
    }
  });

  final totalHistorico = totalPorAno.values.fold(0, (a, b) => a + b);

  return CrescimentoNascimentosKpis(
    anoAtual: anoAtual,
    mesAtual: mesAtual,
    anosDisponiveis: anos,
    totalPorAno: totalPorAno,
    crescimentoPeriodoComparavel: crescimentoPeriodoComparavel,
    crescimentoMesAtual: crescimentoMesAtual,
    mediaCrescimentoHistorico: mediaCrescimentoHistorico,
    melhorAno: melhorAno,
    melhorAnoTotal: melhorAnoTotal,
    totalHistorico: totalHistorico,
  );
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
          g,
          mesSelecionado,
          anoSelecionado,
        )) {
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
          g,
          mesSelecionado,
          anoSelecionado,
        )) {
      total++;
    }
  }

  return total;
}

// ═══════════════════════════════════════════════════════════════════
// Métricas completas por obstetra (jul/2026)
// ═══════════════════════════════════════════════════════════════════

/// Pacote completo de métricas de UM obstetra — não só partos, mas
/// toda a carteira: quem já pariu, quem ainda está em acompanhamento,
/// risco gestacional, diabetes e proximidade de DPP.
class ObstetraMetricasCompletas {
  final String nomeObstetra;

  /// Toda a carteira do obstetra, independente de status (ativas,
  /// encerradas, histórico) — todas as gestantes já vinculadas a ele.
  final int totalCarteira;

  /// Gestantes atualmente ativas (status Gestante ou Puérpera).
  final int ativasNaCarteira;

  final int jaPariu;
  final int aindaNaoPariu;

  final int partosNormal;
  final int partosCesarea;
  final int partosDomiciliar;

  /// Os três indicadores abaixo consideram apenas gestantes ativas,
  /// no mesmo padrão de contarRiscoGestacional/contarDiabetesGestacional.
  final int riscoHabitual;
  final int riscoIntermediario;
  final int riscoAltoRisco;

  final int diabetesSim;
  final int diabetesNao;

  /// Gestantes ativas com DPP nos próximos 14 dias.
  final int dppProxima;

  const ObstetraMetricasCompletas({
    required this.nomeObstetra,
    required this.totalCarteira,
    required this.ativasNaCarteira,
    required this.jaPariu,
    required this.aindaNaoPariu,
    required this.partosNormal,
    required this.partosCesarea,
    required this.partosDomiciliar,
    required this.riscoHabitual,
    required this.riscoIntermediario,
    required this.riscoAltoRisco,
    required this.diabetesSim,
    required this.diabetesNao,
    required this.dppProxima,
  });
}

/// Uma gestante é considerada "já pariu" quando tem via de nascimento
/// informada OU data de nascimento do bebê preenchida — não depende
/// de statusGestante, porque o status pode não ter sido atualizado.
bool _gestanteJaPariu(Map<String, String> g) {
  final via = (g['viaNascimento'] ?? '').trim().toLowerCase();
  final viaInformada =
      via.isNotEmpty &&
      via != 'não informado' &&
      via != 'nao informado' &&
      via != 'selecione';

  final dataNascimento = primeiraDataPreenchida(g, [
    'dataNascimentoBebe',
    'dataNascimento',
  ]);

  return viaInformada || dataNascimento.isNotEmpty;
}

/// Calcula o pacote completo de métricas de um único obstetra, a partir
/// da carteira dele (gestantes cujo campo `obstetraGestante` corresponde
/// ao nome informado — comparação normalizada via `gestantePertenceAoObstetra`).
ObstetraMetricasCompletas calcularMetricasObstetra(
  List<Map<String, String>> todasGestantes,
  String nomeObstetra,
) {
  final carteira = todasGestantes
      .where((g) => gestantePertenceAoObstetra(g, nomeObstetra))
      .toList();

  final ativas = gestantesAtivas(carteira);

  var jaPariu = 0;
  var aindaNaoPariu = 0;
  var partosNormal = 0;
  var partosCesarea = 0;
  var partosDomiciliar = 0;

  for (final g in carteira) {
    if (_gestanteJaPariu(g)) {
      jaPariu++;

      final via = (g['viaNascimento'] ?? '').trim().toLowerCase();
      if (via.contains('ces')) {
        partosCesarea++;
      } else if (via.contains('casa') || via.contains('domicil')) {
        partosDomiciliar++;
      } else if (via.contains('normal') ||
          via.contains('vaginal') ||
          via.contains('vagianl') ||
          via.contains('vagina') ||
          via.contains('parto')) {
        partosNormal++;
      }
    } else {
      aindaNaoPariu++;
    }
  }

  var riscoHabitual = 0;
  var riscoIntermediario = 0;
  var riscoAltoRisco = 0;
  var diabetesSim = 0;
  var diabetesNao = 0;
  var dppProxima = 0;

  for (final g in ativas) {
    final risco = normalizarRiscoGestacional(g['riscoGestacional']);
    if (risco == 'Alto Risco') {
      riscoAltoRisco++;
    } else if (risco == 'Intermediário') {
      riscoIntermediario++;
    } else if (risco == 'Habitual') {
      riscoHabitual++;
    }

    final diabetes = normalizarDiabetesGestacional(g['diabetesGestacional']);
    if (diabetes == 'Sim') {
      diabetesSim++;
    } else if (diabetes == 'Não') {
      diabetesNao++;
    }

    final status = statusGestanteNormalizado(g);
    if (status == 'Gestante' && diasParaDpp(g['dpp'] ?? '') <= 14) {
      dppProxima++;
    }
  }

  return ObstetraMetricasCompletas(
    nomeObstetra: nomeObstetra,
    totalCarteira: carteira.length,
    ativasNaCarteira: ativas.length,
    jaPariu: jaPariu,
    aindaNaoPariu: aindaNaoPariu,
    partosNormal: partosNormal,
    partosCesarea: partosCesarea,
    partosDomiciliar: partosDomiciliar,
    riscoHabitual: riscoHabitual,
    riscoIntermediario: riscoIntermediario,
    riscoAltoRisco: riscoAltoRisco,
    diabetesSim: diabetesSim,
    diabetesNao: diabetesNao,
    dppProxima: dppProxima,
  );
}

/// Calcula as métricas completas de todos os obstetras — usado por
/// enfermeira/admin, que enxergam a clínica inteira.
///
/// A lista de nomes é a UNIÃO de duas fontes:
/// - os obstetras cadastrados na tela de equipe (`obstetras`) — garante
///   que quem acabou de entrar, ainda sem gestante nenhuma, apareça;
/// - os nomes que aparecem no campo `obstetraGestante` das gestantes —
///   garante que ninguém que já atende gestantes fique de fora só por
///   não estar formalmente cadastrado na coleção de obstetras.
///
/// Nomes são unificados por comparação normalizada (`normalizarNomeProfissional`),
/// então "Dra. Fulana" e "fulana" contam como o mesmo obstetra.
List<ObstetraMetricasCompletas> calcularMetricasTodosObstetras(
  List<Map<String, String>> todasGestantes,
  List<Map<String, String>> obstetras,
) {
  final nomesCadastrados = obstetras
      .map((o) => (o['nome'] ?? '').trim())
      .where((nome) => nome.isNotEmpty);

  final nomesNasGestantes = todasGestantes
      .map((g) => (g['obstetraGestante'] ?? '').trim())
      .where((nome) => nome.isNotEmpty);

  // Chave normalizada -> primeira grafia encontrada (pra exibir bonito).
  final nomePorChave = <String, String>{};

  for (final nome in [...nomesCadastrados, ...nomesNasGestantes]) {
    final chave = normalizarNomeProfissional(nome);
    if (chave.isEmpty) continue;
    nomePorChave.putIfAbsent(chave, () => nome);
  }

  final nomes = nomePorChave.values.toList()..sort();

  return nomes
      .map((nome) => calcularMetricasObstetra(todasGestantes, nome))
      .toList();
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
