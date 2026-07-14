enum OrigemExameArquivo { exames, documentos }

class ExameArquivo {
  final String id;
  final OrigemExameArquivo origem;
  final String idGestante;
  final String uidGestante;
  final String nomeGestante;
  final String nomeArquivo;
  final String url;
  final String criadoEm;

  const ExameArquivo({
    required this.id,
    required this.origem,
    required this.idGestante,
    required this.uidGestante,
    required this.nomeGestante,
    required this.nomeArquivo,
    required this.url,
    required this.criadoEm,
  });

  factory ExameArquivo.fromExame(String id, Map<String, dynamic> dados) {
    return ExameArquivo(
      id: id,
      origem: OrigemExameArquivo.exames,
      idGestante: _primeiroValor(dados, ['idGestante', 'gestanteId']),
      uidGestante: _primeiroValor(dados, ['uidGestante', 'gestanteUid']),
      nomeGestante: _primeiroValor(dados, ['nomeGestante', 'gestante']),
      nomeArquivo: _primeiroValor(dados, [
        'nomeArquivo',
        'arquivoNome',
        'nome',
      ], fallback: 'Exame'),
      url: _primeiroValor(dados, ['url', 'arquivoUrl']),
      criadoEm: _primeiroValor(dados, ['criadoEm', 'data']),
    );
  }

  factory ExameArquivo.fromDocumento(Map<String, String> dados) {
    return ExameArquivo(
      id: dados['id'] ?? '',
      origem: OrigemExameArquivo.documentos,
      idGestante: dados['idGestante'] ?? dados['gestanteId'] ?? '',
      uidGestante: dados['uidGestante'] ?? dados['gestanteUid'] ?? '',
      nomeGestante: dados['nomeGestante'] ?? dados['gestante'] ?? '',
      nomeArquivo:
          dados['arquivoNome'] ??
          dados['nomeArquivo'] ??
          dados['nome'] ??
          'Exame',
      url: dados['arquivoUrl'] ?? dados['url'] ?? '',
      criadoEm: dados['criadoEm'] ?? dados['data'] ?? '',
    );
  }

  static bool documentoEhExame(Map<String, String> documento) {
    return _normalizar(documento['tipo']) == 'exame';
  }

  bool pertenceA(Map<String, String> gestante) {
    final id = (gestante['id'] ?? '').trim();
    if (idGestante.isNotEmpty && id.isNotEmpty && idGestante == id) {
      return true;
    }

    final uid = (gestante['uidGestante'] ?? '').trim();
    if (uidGestante.isNotEmpty && uid.isNotEmpty && uidGestante == uid) {
      return true;
    }

    final nome = _normalizar(gestante['nomeGestante']);
    return nomeGestante.trim().isNotEmpty &&
        nome.isNotEmpty &&
        _normalizar(nomeGestante) == nome;
  }

  String nomeGestanteResolvido(Iterable<Map<String, String>> gestantes) {
    if (nomeGestante.trim().isNotEmpty) return nomeGestante.trim();

    for (final gestante in gestantes) {
      if (pertenceA(gestante)) {
        final nome = (gestante['nomeGestante'] ?? '').trim();
        if (nome.isNotEmpty) return nome;
      }
    }

    return 'Gestante não identificada';
  }

  DateTime get dataOrdenacao {
    final iso = DateTime.tryParse(criadoEm.trim());
    if (iso != null) return iso;

    final partes = criadoEm.trim().split(RegExp(r'[ /:]'));
    if (partes.length >= 3) {
      final dia = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final ano = int.tryParse(partes[2]);
      final hora = partes.length > 3 ? int.tryParse(partes[3]) ?? 0 : 0;
      final minuto = partes.length > 4 ? int.tryParse(partes[4]) ?? 0 : 0;

      if (dia != null && mes != null && ano != null) {
        return DateTime(ano, mes, dia, hora, minuto);
      }
    }

    return DateTime(1900);
  }

  String get dataExibicao {
    final data = dataOrdenacao;
    if (data.year == 1900) return 'Data não informada';

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String get chaveDuplicidade {
    final urlNormalizada = url.trim().toLowerCase();
    if (urlNormalizada.isNotEmpty) return 'url:$urlNormalizada';
    return '${origem.name}:$id';
  }

  static String _primeiroValor(
    Map<String, dynamic> dados,
    List<String> campos, {
    String fallback = '',
  }) {
    for (final campo in campos) {
      final valor = dados[campo]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return fallback;
  }

  static String _normalizar(String? valor) {
    return (valor ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }
}

List<ExameArquivo> removerExamesDuplicados(Iterable<ExameArquivo> exames) {
  final unicos = <String, ExameArquivo>{};
  for (final exame in exames) {
    unicos.putIfAbsent(exame.chaveDuplicidade, () => exame);
  }
  return unicos.values.toList();
}
