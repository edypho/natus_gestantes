import '../pacientes/paciente_identidade.dart';

class AtendimentoModel {
  final String id;
  final String gestanteId;
  final String nomeGestante;
  final String tipoAtendimento;
  final String adminDonoId;
  final String criadoPorUid;

  const AtendimentoModel({
    required this.id,
    required this.gestanteId,
    required this.nomeGestante,
    required this.tipoAtendimento,
    required this.adminDonoId,
    required this.criadoPorUid,
  });

  factory AtendimentoModel.fromMap(Map<String, dynamic> map) {
    return AtendimentoModel(
      id: map['id']?.toString() ?? '',
      gestanteId: pacienteIdDoRegistro(map),
      nomeGestante: map['nomeGestante']?.toString() ?? '',
      tipoAtendimento: map['tipoAtendimento']?.toString() ?? '',
      adminDonoId: map['adminDonoId']?.toString() ?? '',
      criadoPorUid: map['criadoPorUid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return identidadePacienteCanonica({
      'id': id,
      'nomeGestante': nomeGestante,
      'tipoAtendimento': tipoAtendimento,
      'adminDonoId': adminDonoId,
      'criadoPorUid': criadoPorUid,
    }, pacienteId: gestanteId);
  }
}
