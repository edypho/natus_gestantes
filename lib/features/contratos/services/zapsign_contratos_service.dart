import 'package:cloud_functions/cloud_functions.dart';

import '../../../saas/tenant_access_scope.dart';
import '../models/contrato_registro.dart';
import '../models/contrato_solicitacao.dart';
import '../repositories/contratos_repository.dart';

class ZapSignContratosService {
  ZapSignContratosService({
    required TenantAccessScope escopo,
    ContratosRepository? repository,
    FirebaseFunctions? functions,
  }) : _repository = repository ?? ContratosRepository(escopo: escopo),
       _functions = functions ?? FirebaseFunctions.instance;

  final ContratosRepository _repository;
  final FirebaseFunctions _functions;

  Future<String> registrarSolicitacao(ContratoSolicitacao solicitacao) async {
    return _repository.criarSolicitacao(
      pacienteId: solicitacao.pacienteId,
      templateKey: solicitacao.templateKey,
      payload: solicitacao.toMap(),
    );
  }

  Future<Map<String, dynamic>> gerarContrato({
    required String contratoId,
    required ContratoSolicitacao solicitacao,
  }) async {
    final callable = _functions.httpsCallable('gerarContratoZapSign');
    final resposta = await callable.call({
      'contratoId': contratoId,
      'payload': solicitacao.toMap(),
    });

    return Map<String, dynamic>.from(resposta.data as Map);
  }

  Future<Map<String, dynamic>> consultarStatus({
    required String contratoId,
    required String zapsignDocumentId,
  }) async {
    final callable = _functions.httpsCallable('consultarContratoZapSign');
    final resposta = await callable.call({
      'contratoId': contratoId,
      'zapsignDocumentId': zapsignDocumentId,
    });

    return Map<String, dynamic>.from(resposta.data as Map);
  }

  Future<ContratoRegistro?> buscarRegistro(String contratoId) {
    return _repository.buscarPorId(contratoId);
  }
}
