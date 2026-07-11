/// Regras de negócio sobre gestantes — funções puras, sem estado.
/// Extraídas do main.dart no Lote 2c da refatoração.
/// Testes em test/gestantes_regras_test.dart.
library;

String statusGestanteNormalizado(Map<String, String> g) {
  final status = (g['statusGestante'] ?? 'Gestante').trim().toLowerCase();

  if (status.contains('puerpera') || status.contains('puérpera')) {
    return 'Puérpera';
  }

  if (status.contains('encerrada') || status.contains('encerrado')) {
    return 'Encerrada';
  }

  if (status.contains('historico') || status.contains('histórico')) {
    return 'Histórico';
  }

  return 'Gestante';
}

bool gestanteEstaAtiva(Map<String, String> g) {
  final status = statusGestanteNormalizado(g);
  final historico = (g['historico'] ?? '').trim().toLowerCase();

  if (historico == 'true' || historico == 'sim' || historico == '1') {
    return false;
  }

  return status == 'Gestante' || status == 'Puérpera';
}

bool gestanteApareceNaBusca(Map<String, String> g, String busca) {
  final textoBusca = busca.trim().toLowerCase();

  if (textoBusca.isEmpty) {
    return true;
  }

  final campos = [
    g['nomeGestante'],
    g['telefoneGestante'],
    g['emailGestante'],
    g['cidadeGestante'],
    g['bairroGestante'],
    g['hospitalGestante'],
    g['obstetraGestante'],
    g['convenioGestante'],
    g['nomeBebe'],
    g['cpfGestante'],
  ];

  return campos.any((valor) {
    return (valor ?? '').toLowerCase().contains(textoBusca);
  });
}

List<Map<String, String>> gestantesAtivas(
  List<Map<String, String>> gestantes,
) {
  return gestantes.where(gestanteEstaAtiva).toList();
}

bool gestanteAtivaParaContracoes(Map<String, String> g) {
  final historico = (g['historico'] ?? '').trim().toLowerCase();

  if (historico == 'true' || historico == 'sim' || historico == '1') {
    return false;
  }

  return statusGestanteNormalizado(g) == 'Gestante';
}

int diasParaDpp(String dpp) {
  try {
    final partes = dpp.split('/');
    if (partes.length != 3) return 9999;

    final dia = int.parse(partes[0]);
    final mes = int.parse(partes[1]);
    final ano = int.parse(partes[2]);

    final dataDpp = DateTime(ano, mes, dia);
    final hoje = DateTime.now();

    return dataDpp.difference(hoje).inDays;
  } catch (e) {
    return 9999;
  }
}

DateTime? converterDataDashboard(String? valor) {
  if (valor == null) return null;

  final texto = valor.trim();
  if (texto.isEmpty) return null;

  // Formato ISO: 2026-05-22T17:38:36.210
  final dataIso = DateTime.tryParse(texto);
  if (dataIso != null) return dataIso;

  // Formato brasileiro: 03/06/2026 ou 03/06/2026 14:30
  final somenteData = texto.split(' ').first.trim();
  final partes = somenteData.split('/');

  if (partes.length == 3) {
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);

    if (dia != null && mes != null && ano != null) {
      return DateTime(ano, mes, dia);
    }
  }

  // Segurança para datas que vierem como Timestamp(seconds=..., nanoseconds=...)
  final timestampMatch = RegExp(r'seconds=(\d+)').firstMatch(texto);
  final segundos = int.tryParse(timestampMatch?.group(1) ?? '');

  if (segundos != null) {
    return DateTime.fromMillisecondsSinceEpoch(segundos * 1000);
  }

  return null;
}

String primeiraDataPreenchida(
  Map<String, String> dados,
  List<String> campos,
) {
  for (final campo in campos) {
    final valor = (dados[campo] ?? '').trim();
    if (valor.isNotEmpty) return valor;
  }

  return '';
}

// ═══════════════════════════════════════════════════════════════════
// Visibilidade por obstetra (jul/2026)
// ═══════════════════════════════════════════════════════════════════

/// Normaliza nome de profissional para comparação: minúsculas, sem
/// pronomes de tratamento (dr., dra., doutor, doutora) e espaços únicos.
String normalizarNomeProfissional(String nome) {
  var n = nome.trim().toLowerCase();

  for (final prefixo in ['dr.', 'dra.', 'dr ', 'dra ', 'doutor ', 'doutora ']) {
    if (n.startsWith(prefixo)) {
      n = n.substring(prefixo.length);
      break;
    }
  }

  return n.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Uma gestante pertence à carteira do obstetra quando o campo
/// `obstetraGestante` do cadastro corresponde ao nome dele
/// (comparação normalizada).
bool gestantePertenceAoObstetra(
  Map<String, String> g,
  String nomeObstetra,
) {
  final nome = normalizarNomeProfissional(nomeObstetra);
  if (nome.isEmpty) return false;

  final campo = normalizarNomeProfissional(g['obstetraGestante'] ?? '');
  return campo == nome;
}

/// Aplica o filtro de carteira quando o usuário é obstetra;
/// demais perfis enxergam a lista completa.
List<Map<String, String>> filtrarGestantesPorPerfil(
  List<Map<String, String>> gestantes, {
  required String tipoUsuario,
  required String nomeUsuario,
}) {
  if (tipoUsuario.trim().toLowerCase() != 'obstetra') return gestantes;

  return gestantes
      .where((g) => gestantePertenceAoObstetra(g, nomeUsuario))
      .toList();
}
