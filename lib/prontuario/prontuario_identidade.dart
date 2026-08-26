import '../pacientes/paciente_identidade.dart';

Map<String, String> identidadePacienteProntuario({
  required String pacienteId,
  String? pacienteUid,
}) {
  final idNormalizado = pacienteId.trim();
  if (idNormalizado.isEmpty) {
    throw ArgumentError.value(pacienteId, 'pacienteId', 'não pode ser vazio');
  }
  final identidade = identidadePacienteCanonicaTexto(
    const <String, String>{},
    pacienteId: idNormalizado,
    pacienteUid: pacienteUid,
  );
  for (final campo in camposUidPaciente) {
    identidade.putIfAbsent(campo, () => '');
  }
  return identidade;
}
