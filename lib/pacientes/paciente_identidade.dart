const camposIdPaciente = <String>['pacienteId', 'gestanteId', 'idGestante'];

const camposUidPaciente = <String>[
  'uidPaciente',
  'pacienteUid',
  'uidGestante',
  'gestanteUid',
];

String pacienteIdDoRegistro(Map<String, dynamic> dados, {String? pacienteId}) {
  return _resolverAliasUnico(
    dados,
    camposIdPaciente,
    valorAdicional: pacienteId,
    rotulo: 'ID do paciente',
  );
}

String pacienteUidDoRegistro(
  Map<String, dynamic> dados, {
  String? pacienteUid,
}) {
  return _resolverAliasUnico(
    dados,
    camposUidPaciente,
    valorAdicional: pacienteUid,
    rotulo: 'UID do paciente',
  );
}

bool identidadePacienteConsistente(Map<String, dynamic> dados) {
  try {
    pacienteIdDoRegistro(dados);
    pacienteUidDoRegistro(dados);
    return true;
  } on FormatException {
    return false;
  }
}

Map<String, dynamic> identidadePacienteCanonica(
  Map<String, dynamic> dados, {
  String? pacienteId,
  String? pacienteUid,
}) {
  final id = pacienteIdDoRegistro(dados, pacienteId: pacienteId);
  final uid = pacienteUidDoRegistro(dados, pacienteUid: pacienteUid);
  final resultado = <String, dynamic>{...dados};

  if (id.isNotEmpty) {
    for (final campo in camposIdPaciente) {
      resultado[campo] = id;
    }
  }
  if (uid.isNotEmpty) {
    for (final campo in camposUidPaciente) {
      resultado[campo] = uid;
    }
  }

  return resultado;
}

Map<String, String> identidadePacienteCanonicaTexto(
  Map<String, String> dados, {
  String? pacienteId,
  String? pacienteUid,
}) {
  final normalizado = identidadePacienteCanonica(
    Map<String, dynamic>.from(dados),
    pacienteId: pacienteId,
    pacienteUid: pacienteUid,
  );
  return normalizado.map(
    (chave, valor) => MapEntry(chave, (valor ?? '').toString()),
  );
}

bool registroPertenceAoPaciente(
  Map<String, dynamic> dados, {
  required String pacienteId,
  required String pacienteUid,
}) {
  try {
    final id = pacienteIdDoRegistro(dados);
    final uid = pacienteUidDoRegistro(dados);
    final idEsperado = pacienteId.trim();
    final uidEsperado = pacienteUid.trim();

    return (id.isEmpty || id == idEsperado) &&
        (uid.isEmpty || uid == uidEsperado) &&
        (id.isNotEmpty || uid.isNotEmpty);
  } on FormatException {
    return false;
  }
}

String _resolverAliasUnico(
  Map<String, dynamic> dados,
  List<String> campos, {
  String? valorAdicional,
  required String rotulo,
}) {
  final valores = <String>{};
  for (final campo in campos) {
    final valor = (dados[campo] ?? '').toString().trim();
    if (valor.isNotEmpty) valores.add(valor);
  }

  final adicional = (valorAdicional ?? '').trim();
  if (adicional.isNotEmpty) valores.add(adicional);

  if (valores.length > 1) {
    throw FormatException('$rotulo possui aliases divergentes.');
  }

  return valores.isEmpty ? '' : valores.single;
}
