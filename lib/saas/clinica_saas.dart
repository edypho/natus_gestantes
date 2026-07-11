class ClinicaSaaS {
  final String id;
  final String nome;
  final String adminDonoId;
  final String plano;
  final String status;

  const ClinicaSaaS({
    required this.id,
    required this.nome,
    required this.adminDonoId,
    required this.plano,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'adminDonoId': adminDonoId,
      'plano': plano,
      'status': status,
    };
  }

  factory ClinicaSaaS.fromMap(Map<String, dynamic> map) {
    return ClinicaSaaS(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      adminDonoId: map['adminDonoId']?.toString() ?? '',
      plano: map['plano']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }
}
