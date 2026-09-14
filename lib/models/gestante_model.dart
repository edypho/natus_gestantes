import '../pacientes/paciente_identidade.dart';

class GestanteModel {
  final String id;
  final String nomeGestante;
  final String statusGestante;
  final String adminDonoId;
  final String uidGestante;

  const GestanteModel({
    required this.id,
    required this.nomeGestante,
    required this.statusGestante,
    required this.adminDonoId,
    required this.uidGestante,
  });

  factory GestanteModel.fromMap(Map<String, dynamic> map) {
    return GestanteModel(
      id: pacienteIdDoRegistro(map, pacienteId: map['id']?.toString()),
      nomeGestante: map['nomeGestante']?.toString() ?? '',
      statusGestante: map['statusGestante']?.toString() ?? 'Gestante',
      adminDonoId: map['adminDonoId']?.toString() ?? '',
      uidGestante: pacienteUidDoRegistro(map),
    );
  }

  Map<String, dynamic> toMap() {
    return identidadePacienteCanonica(
      {
        'id': id,
        'nomeGestante': nomeGestante,
        'statusGestante': statusGestante,
        'adminDonoId': adminDonoId,
      },
      pacienteId: id,
      pacienteUid: uidGestante,
    );
  }
}
