class ContratoRegistro {
  final String id;
  final String pacienteId;
  final String templateKey;
  final String status;
  final String zapsignDocumentId;
  final String zapsignSignerUrl;
  final String criadoEm;
  final String atualizadoEm;
  final Map<String, dynamic> payload;

  const ContratoRegistro({
    required this.id,
    required this.pacienteId,
    required this.templateKey,
    required this.status,
    required this.zapsignDocumentId,
    required this.zapsignSignerUrl,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.payload,
  });

  factory ContratoRegistro.fromMap(Map<String, dynamic> map) {
    return ContratoRegistro(
      id: map['id']?.toString() ?? '',
      pacienteId: map['pacienteId']?.toString() ?? '',
      templateKey: map['templateKey']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pendente',
      zapsignDocumentId: map['zapsignDocumentId']?.toString() ?? '',
      zapsignSignerUrl: map['zapsignSignerUrl']?.toString() ?? '',
      criadoEm: map['criadoEm']?.toString() ?? '',
      atualizadoEm: map['atualizadoEm']?.toString() ?? '',
      payload: Map<String, dynamic>.from(
        map['payload'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pacienteId': pacienteId,
      'templateKey': templateKey,
      'status': status,
      'zapsignDocumentId': zapsignDocumentId,
      'zapsignSignerUrl': zapsignSignerUrl,
      'criadoEm': criadoEm,
      'atualizadoEm': atualizadoEm,
      'payload': payload,
    };
  }
}
