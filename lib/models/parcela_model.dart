import '../pacientes/paciente_identidade.dart';

class ParcelaModel {
  final String id;
  final String gestanteId;
  final String nomeGestante;
  final double valor;
  final String status;
  final String adminDonoId;

  const ParcelaModel({
    required this.id,
    required this.gestanteId,
    required this.nomeGestante,
    required this.valor,
    required this.status,
    required this.adminDonoId,
  });

  factory ParcelaModel.fromMap(Map<String, dynamic> map) {
    final valorBruto = map['valor'];

    return ParcelaModel(
      id: map['id']?.toString() ?? '',
      gestanteId: pacienteIdDoRegistro(map),
      nomeGestante: map['nomeGestante']?.toString() ?? '',
      valor: valorBruto is num ? valorBruto.toDouble() : 0,
      status: map['status']?.toString() ?? 'Pendente',
      adminDonoId: map['adminDonoId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return identidadePacienteCanonica({
      'id': id,
      'nomeGestante': nomeGestante,
      'valor': valor,
      'status': status,
      'adminDonoId': adminDonoId,
    }, pacienteId: gestanteId);
  }
}
