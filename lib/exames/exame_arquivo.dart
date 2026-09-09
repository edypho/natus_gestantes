import '../pacientes/paciente_identidade.dart';

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
      idGestante: pacienteIdDoRegistro(dados),
      uidGestante: pacienteUidDoRegistro(dados),
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
      idGestante: pacienteIdDoRegistro(dados),
      uidGestante: pacienteUidDoRegistro(dados),
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

  bool pertenceA(Map<String, String> paciente) {
    final id = _idDoPaciente(paciente);
    if (idGestante.isNotEmpty && id.isNotEmpty && idGestante == id) {
      return true;
    }
    if (idGestante.isNotEmpty && id.isNotEmpty) return false;

    final uid = pacienteUidDoRegistro(paciente);
    if (uidGestante.isNotEmpty && uid.isNotEmpty && uidGestante == uid) {
      return true;
    }
    if (uidGestante.isNotEmpty && uid.isNotEmpty) return false;

    final nome = _normalizar(paciente['nomeGestante']);
    return nomeGestante.trim().isNotEmpty &&
        nome.isNotEmpty &&
        _normalizar(nomeGestante) == nome;
  }

  Map<String, String>? pacienteCorrespondente(
    Iterable<Map<String, String>> pacientes,
  ) {
    for (final paciente in pacientes) {
      if (pertenceA(paciente)) return paciente;
    }
    return null;
  }

  String nomeGestanteResolvido(Iterable<Map<String, String>> pacientes) {
    final paciente = pacienteCorrespondente(pacientes);
    if (paciente != null) {
      final nome = (paciente['nomeGestante'] ?? '').trim();
      if (nome.isNotEmpty) {
        return nome;
      }
    }

    if (nomeGestante.trim().isNotEmpty) return nomeGestante.trim();
    return 'Paciente não identificado';
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

  static String _idDoPaciente(Map<String, String> paciente) {
    final idDocumento = (paciente['id'] ?? '').trim();
    return pacienteIdDoRegistro(paciente, pacienteId: idDocumento);
  }
}

class GrupoExamesPaciente {
  final String chavePaciente;
  final String nomePaciente;
  final List<ExameArquivo> exames;

  const GrupoExamesPaciente({
    required this.chavePaciente,
    required this.nomePaciente,
    required this.exames,
  });
}

List<GrupoExamesPaciente> agruparExamesPorPaciente(
  Iterable<ExameArquivo> exames,
  Iterable<Map<String, String>> pacientes,
) {
  final pacientesDisponiveis = pacientes.toList(growable: false);
  final agrupados = <String, List<ExameArquivo>>{};
  final nomes = <String, String>{};

  for (final exame in exames) {
    final paciente = exame.pacienteCorrespondente(pacientesDisponiveis);
    final chave = paciente == null
        ? _chavePacienteNaoCadastrado(exame)
        : _chavePacienteCadastrado(paciente);

    agrupados.putIfAbsent(chave, () => <ExameArquivo>[]).add(exame);
    nomes.putIfAbsent(
      chave,
      () =>
          exame.nomeGestanteResolvido(paciente == null ? const [] : [paciente]),
    );
  }

  final grupos = agrupados.entries.map((entrada) {
    final examesDoPaciente = entrada.value
      ..sort((a, b) => b.dataOrdenacao.compareTo(a.dataOrdenacao));
    return GrupoExamesPaciente(
      chavePaciente: entrada.key,
      nomePaciente: nomes[entrada.key] ?? 'Paciente não identificado',
      exames: examesDoPaciente,
    );
  }).toList();

  grupos.sort(
    (a, b) =>
        a.nomePaciente.toLowerCase().compareTo(b.nomePaciente.toLowerCase()),
  );
  return grupos;
}

String _chavePacienteCadastrado(Map<String, String> paciente) {
  final id = ExameArquivo._idDoPaciente(paciente);
  if (id.isNotEmpty) return 'id:$id';

  final uid = pacienteUidDoRegistro(paciente);
  if (uid.isNotEmpty) return 'uid:$uid';

  return 'nome:${ExameArquivo._normalizar(paciente['nomeGestante'])}';
}

String _chavePacienteNaoCadastrado(ExameArquivo exame) {
  if (exame.idGestante.isNotEmpty) {
    return 'nao-cadastrado:id:${exame.idGestante}';
  }
  if (exame.uidGestante.isNotEmpty) {
    return 'nao-cadastrado:uid:${exame.uidGestante}';
  }

  final nome = ExameArquivo._normalizar(exame.nomeGestante);
  if (nome.isNotEmpty) return 'nao-cadastrado:nome:$nome';
  return 'nao-cadastrado:exame:${exame.origem.name}:${exame.id}';
}

List<ExameArquivo> removerExamesDuplicados(Iterable<ExameArquivo> exames) {
  final unicos = <String, ExameArquivo>{};
  for (final exame in exames) {
    unicos.putIfAbsent(exame.chaveDuplicidade, () => exame);
  }
  return unicos.values.toList();
}
