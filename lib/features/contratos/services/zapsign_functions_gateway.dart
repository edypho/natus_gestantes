import 'package:cloud_functions/cloud_functions.dart';

abstract interface class ZapSignFunctionsGateway {
  Future<Map<String, dynamic>> gerarContrato({
    required String contratoId,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>> consultarContrato({
    required String contratoId,
    required String zapsignDocumentId,
  });
}

final class FirebaseZapSignFunctionsGateway implements ZapSignFunctionsGateway {
  @override
  Future<Map<String, dynamic>> gerarContrato({
    required String contratoId,
    required Map<String, dynamic> payload,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('gerarContratoZapSign');
    final resposta = await callable.call({
      'contratoId': contratoId,
      'payload': payload,
    });

    return Map<String, dynamic>.from(resposta.data as Map);
  }

  @override
  Future<Map<String, dynamic>> consultarContrato({
    required String contratoId,
    required String zapsignDocumentId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('consultarContratoZapSign');
    final resposta = await callable.call({
      'contratoId': contratoId,
      'zapsignDocumentId': zapsignDocumentId,
    });

    return Map<String, dynamic>.from(resposta.data as Map);
  }
}
