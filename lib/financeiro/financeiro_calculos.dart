import 'package:flutter/material.dart';

import '../shared/formatadores.dart';

/// Total contratado após o desconto, arredondado em centavos.
double valorLiquidoPlano(Map<String, String> paciente) {
  final bruto = converterValor(paciente['valorPlano'] ?? '0');
  final desconto = converterValor(paciente['valorDesconto'] ?? '0');
  return ((bruto - desconto).clamp(0, double.infinity) * 100).round() / 100;
}

List<double> parcelasDoPlano(Map<String, String> paciente, int quantidade) {
  final saldo =
      valorLiquidoPlano(paciente) - converterValor(paciente['entrada'] ?? '0');
  return distribuirSaldoEmParcelas(saldo, quantidade);
}

/// Cálculos financeiros do Natus — funções puras, sem estado.
///
/// Extraídas do main.dart no Lote 2b da refatoração. Recebem as listas e o
/// período por parâmetro, o que as torna testáveis isoladamente
/// (ver test/financeiro_calculos_test.dart).

double calcularSaldoAReceber(List<Map<String, String>> gestantes) {
  double total = 0;

  for (var g in gestantes) {
    final valorTexto = g['valorPlano'] ?? '0';

    final valorLimpo = valorTexto
        .replaceAll('R\$ ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();

    final valorNumerico = double.tryParse(valorLimpo) ?? 0;

    total += valorNumerico;
  }

  return total;
}

double calcularValorRecebido(List<Map<String, String>> gestantes) {
  double total = 0;

  for (var g in gestantes) {
    total += converterValor(g['entrada'] ?? '0');
  }

  return total;
}

/// Indica se o lançamento deve participar do financeiro operacional.
///
/// Registros legados sem valor são mantidos no Firestore para auditoria, mas
/// não devem aparecer na tela nem contaminar os indicadores.
bool lancamentoFinanceiroValido(Map<String, String> parcela) {
  final statusRegistro = (parcela['statusRegistro'] ?? '').trim().toLowerCase();

  if (statusRegistro == 'cancelado' ||
      statusRegistro == 'excluido' ||
      statusRegistro == 'ignorado') {
    return false;
  }

  return converterValor(parcela['valor'] ?? '0') > 0;
}

bool _parcelaPaga(Map<String, String> parcela) {
  final status = (parcela['status'] ?? '').trim().toLowerCase();
  return status == 'pago' || status == 'paga';
}

/// Regra de exibição da lista financeira mensal.
///
/// Parcelas abertas aparecem no mês do vencimento (competência). Parcelas
/// pagas aparecem no mês em que o valor foi efetivamente recebido (caixa),
/// usando o vencimento apenas como fallback para registros legados sem
/// `dataPagamento`.
bool lancamentoFinanceiroVisivelNoPeriodo(
  Map<String, String> parcela,
  int mesSelecionado,
  int anoSelecionado,
) {
  if (!lancamentoFinanceiroValido(parcela)) return false;

  if (_parcelaPaga(parcela)) {
    return parcelaFoiPagaNoMesSelecionado(
      parcela,
      mesSelecionado,
      anoSelecionado,
    );
  }

  return parcelaEhDoMesSelecionado(parcela, mesSelecionado, anoSelecionado);
}

double valorEfetivamenteRecebido(Map<String, String> parcela) {
  final valorRegistrado = (parcela['valorRecebido'] ?? '').trim();
  if (valorRegistrado.isNotEmpty) return converterValor(valorRegistrado);

  final valor = converterValor(parcela['valor'] ?? '0');
  final quitacao =
      (parcela['quitacaoAntecipada'] ?? '').toLowerCase() == 'true';
  if (!quitacao) return valor;

  final desconto = converterPercentual(parcela['descontoQuitacao'] ?? '0');
  return (valor * (1 - desconto)).clamp(0, double.infinity).toDouble();
}

/// Redistribui um saldo em parcelas, fechando exatamente os centavos.
///
/// As parcelas já pagas devem ser descontadas antes desta chamada. Assim, ao
/// reduzir um acordo de 6x para 4x depois de 2 baixas, a quantidade restante
/// informada aqui será 2.
List<double> distribuirSaldoEmParcelas(double saldo, int quantidade) {
  if (saldo <= 0 || quantidade <= 0) return const [];

  final saldoCentavos = (saldo * 100).round();
  final centavosBase = saldoCentavos ~/ quantidade;
  final centavosRestantes = saldoCentavos % quantidade;

  return List<double>.generate(quantidade, (indice) {
    final centavos = centavosBase + (indice < centavosRestantes ? 1 : 0);
    return centavos / 100;
  });
}

double calcularValorAReceberReal(
  List<Map<String, String>> parcelas,
  int mesSelecionado,
  int anoSelecionado,
) {
  double total = 0;

  for (var p in parcelas) {
    if (lancamentoFinanceiroValido(p) &&
        parcelaEhDoMesSelecionado(p, mesSelecionado, anoSelecionado) &&
        p['status'] == 'Pendente') {
      total += converterValor(p['valor'] ?? '0');
    }
  }

  return total;
}

bool parcelaEhDoMesAtual(Map<String, String> parcela) {
  try {
    final vencimento = parcela['vencimento'] ?? '';

    final partes = vencimento.split('/');

    if (partes.length != 3) {
      return false;
    }

    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);

    final hoje = DateTime.now();

    return mes == hoje.month && ano == hoje.year;
  } catch (e) {
    return false;
  }
}

bool parcelaEhDoMesSelecionado(
  Map<String, String> parcela,
  int mesSelecionado,
  int anoSelecionado,
) {
  try {
    final vencimento = parcela['vencimento'] ?? '';

    final partes = vencimento.split('/');

    if (partes.length != 3) return false;

    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);

    return mes == mesSelecionado && ano == anoSelecionado;
  } catch (e) {
    return false;
  }
}

/// Verifica se uma parcela foi efetivamente PAGA dentro do mês/ano
/// selecionado, usando a data real do pagamento (`dataPagamento`) — e
/// não o vencimento. É isso que diferencia "recebido" (regime de caixa:
/// quando o dinheiro entrou de fato) de "previsto"/"atrasado" (regime
/// de competência: quando a parcela deveria vencer).
///
/// Parcelas antigas sem `dataPagamento` registrado (ex.: importação
/// histórica antes dessa mudança) caem de volta pro vencimento, pra não
/// sumir de relatórios de meses já fechados.
bool parcelaFoiPagaNoMesSelecionado(
  Map<String, String> parcela,
  int mesSelecionado,
  int anoSelecionado,
) {
  if (!lancamentoFinanceiroValido(parcela)) return false;
  if (!_parcelaPaga(parcela)) return false;

  final dataPagamento = (parcela['dataPagamento'] ?? '').trim();

  if (dataPagamento.isEmpty) {
    return parcelaEhDoMesSelecionado(parcela, mesSelecionado, anoSelecionado);
  }

  try {
    final soData = dataPagamento.split(' ').first;
    final partes = soData.split('/');

    if (partes.length != 3) {
      return parcelaEhDoMesSelecionado(parcela, mesSelecionado, anoSelecionado);
    }

    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);

    return mes == mesSelecionado && ano == anoSelecionado;
  } catch (e) {
    return parcelaEhDoMesSelecionado(parcela, mesSelecionado, anoSelecionado);
  }
}

bool parcelaEstaAtrasada(Map<String, String> parcela) {
  try {
    final vencimento = parcela['vencimento'] ?? '';

    final partes = vencimento.split('/');

    if (partes.length != 3) return false;

    final dia = int.parse(partes[0]);
    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);

    final dataVencimento = DateTime(ano, mes, dia);
    final hoje = DateTime.now();

    return hoje.isAfter(dataVencimento) && parcela['status'] == 'Pendente';
  } catch (e) {
    return false;
  }
}

double calcularValorRecebidoMesAtual(
  List<Map<String, String>> parcelas,
  int mesSelecionado,
  int anoSelecionado,
) {
  double total = 0;

  for (var p in parcelas) {
    if (parcelaFoiPagaNoMesSelecionado(p, mesSelecionado, anoSelecionado)) {
      total += valorEfetivamenteRecebido(p);
    }
  }

  return total;
}

double calcularValorAtrasadoMesAtual(
  List<Map<String, String>> parcelas,
  int mesSelecionado,
  int anoSelecionado,
) {
  double total = 0;

  for (var p in parcelas) {
    if (lancamentoFinanceiroValido(p) &&
        parcelaEhDoMesSelecionado(p, mesSelecionado, anoSelecionado) &&
        parcelaEstaAtrasada(p)) {
      total += converterValor(p['valor'] ?? '0');
    }
  }

  return total;
}

int contarParcelasAtrasadasMesSelecionado(
  List<Map<String, String>> parcelas,
  int mesSelecionado,
  int anoSelecionado,
) {
  int total = 0;

  for (var p in parcelas) {
    if (lancamentoFinanceiroValido(p) &&
        parcelaEhDoMesSelecionado(p, mesSelecionado, anoSelecionado) &&
        parcelaEstaAtrasada(p)) {
      total++;
    }
  }

  return total;
}

double calcularTotalPrevistoMesSelecionado(
  List<Map<String, String>> parcelas,
  int mesSelecionado,
  int anoSelecionado,
) {
  double total = 0;

  for (var p in parcelas) {
    if (lancamentoFinanceiroValido(p) &&
        parcelaEhDoMesSelecionado(p, mesSelecionado, anoSelecionado) &&
        !_parcelaPaga(p)) {
      total += converterValor(p['valor'] ?? '0');
    }
  }

  return total;
}

double calcularPercentualInadimplencia(
  List<Map<String, String>> parcelas,
  int mesSelecionado,
  int anoSelecionado,
) {
  final totalPrevisto = calcularTotalPrevistoMesSelecionado(
    parcelas,
    mesSelecionado,
    anoSelecionado,
  );
  final totalAtrasado = calcularValorAtrasadoMesAtual(
    parcelas,
    mesSelecionado,
    anoSelecionado,
  );

  if (totalPrevisto == 0) {
    return 0;
  }

  return (totalAtrasado / totalPrevisto) * 100;
}

Color corInadimplencia(double valor) {
  if (valor == 0) {
    return Colors.green;
  } else if (valor <= 20) {
    return Colors.orange;
  } else {
    return Colors.red;
  }
}

String formatarDataFinanceira(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();

  return '$dia/$mes/$ano';
}

String gerarVencimentoEntrada() {
  return formatarDataFinanceira(DateTime.now());
}

String gerarVencimentoParcela(int numeroParcela) {
  final hoje = DateTime.now();

  // Entrada fica no mês atual.
  // A 1ª parcela começa apenas no mês seguinte ao mês de entrada.
  final mesDaParcela = DateTime(hoje.year, hoje.month + numeroParcela, 1);

  final quintoDiaUtil = calcularQuintoDiaUtil(
    mesDaParcela.year,
    mesDaParcela.month,
  );

  return formatarDataFinanceira(quintoDiaUtil);
}

String gerarVencimentoParcelaHistorico(int numeroParcela, int parcelasPagas) {
  final hoje = DateTime.now();

  final deslocamentoMes = numeroParcela - parcelasPagas;

  final mesReferencia = DateTime(hoje.year, hoje.month + deslocamentoMes, 1);

  final quintoDiaUtil = calcularQuintoDiaUtil(
    mesReferencia.year,
    mesReferencia.month,
  );

  return formatarDataFinanceira(quintoDiaUtil);
}

String gerarVencimentoEntradaHistorico(int parcelasPagas) {
  final hoje = DateTime.now();

  if (parcelasPagas <= 0) {
    return gerarVencimentoEntrada();
  }

  final vencimentoPrimeiraParcelaPaga = calcularQuintoDiaUtil(
    hoje.year,
    hoje.month + (1 - parcelasPagas),
  );

  final vencimentoEntrada = DateTime(
    vencimentoPrimeiraParcelaPaga.year,
    vencimentoPrimeiraParcelaPaga.month - 1,
    vencimentoPrimeiraParcelaPaga.day,
  );

  return formatarDataFinanceira(vencimentoEntrada);
}

DateTime calcularQuintoDiaUtil(int ano, int mes) {
  int diasUteisEncontrados = 0;

  for (int dia = 1; dia <= 31; dia++) {
    final data = DateTime(ano, mes, dia);

    if (data.month != mes) {
      break;
    }

    final ehSabado = data.weekday == DateTime.saturday;
    final ehDomingo = data.weekday == DateTime.sunday;

    if (!ehSabado && !ehDomingo) {
      diasUteisEncontrados++;
    }

    if (diasUteisEncontrados == 5) {
      return data;
    }
  }

  return DateTime(ano, mes, 5);
}

double converterValorDinamico(dynamic valor) {
  if (valor is num) return valor.toDouble();
  return converterValor((valor ?? '0').toString());
}

String rotuloParcelaFinanceira(Map<String, String> parcela) {
  final tipo = (parcela['tipo'] ?? '').trim().toLowerCase();
  final descricao = (parcela['descricao'] ?? '').trim();

  if (tipo == 'entrada') return 'Entrada';
  if (descricao.isNotEmpty) return descricao;

  final numero = (parcela['numero'] ?? '').trim();
  if (numero == '0') return 'Entrada';
  if (numero.isNotEmpty) return '$numeroª Parcela';

  return 'Parcela';
}

// ═══════════════════════════════════════════════════════════════════
// Quitação antecipada (jul/2026)
// ═══════════════════════════════════════════════════════════════════

/// Parcelas ainda não pagas de uma gestante específica.
List<Map<String, String>> parcelasPendentesDaGestante(
  List<Map<String, String>> parcelas,
  String nomeGestante,
) {
  final nome = nomeGestante.trim().toLowerCase();

  return parcelas.where((p) {
    final mesmaGestante = (p['gestante'] ?? '').trim().toLowerCase() == nome;
    return mesmaGestante &&
        p['status'] != 'Pago' &&
        lancamentoFinanceiroValido(p);
  }).toList();
}

/// Soma dos valores de uma lista de parcelas (formato brasileiro).
double somarValorParcelas(List<Map<String, String>> parcelas) {
  double total = 0;
  for (final p in parcelas) {
    total += converterValor(p['valor'] ?? '0');
  }
  return total;
}

/// Valor final da quitação após o desconto percentual (0 a 100).
/// Arredonda para centavos.
double valorQuitacaoComDesconto(double total, double percentualDesconto) {
  final p = percentualDesconto.clamp(0, 100);
  final valor = total * (1 - p / 100);
  return (valor * 100).roundToDouble() / 100;
}
