import '../../../saas/tenant_access_scope.dart';
import '../models/contrato_registro.dart';
import '../models/contrato_solicitacao.dart';
import '../repositories/contratos_repository.dart';
import 'zapsign_functions_gateway.dart';

class ZapSignContratosService {
  ZapSignContratosService({
    required TenantAccessScope escopo,
    ContratosRepository? repository,
    ZapSignFunctionsGateway? functionsGateway,
  }) : _escopo = escopo,
       _repositoryOverride = repository,
       _functionsGateway =
           functionsGateway ?? FirebaseZapSignFunctionsGateway();

  final TenantAccessScope _escopo;
  final ContratosRepository? _repositoryOverride;
  final ZapSignFunctionsGateway _functionsGateway;

  late final ContratosRepository _repository =
      _repositoryOverride ?? ContratosRepository(escopo: _escopo);

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
  }) => _functionsGateway.gerarContrato(
    contratoId: contratoId,
    payload: solicitacao.toMap(),
  );

  Future<Map<String, dynamic>> consultarStatus({
    required String contratoId,
    required String zapsignDocumentId,
  }) => _functionsGateway.consultarContrato(
    contratoId: contratoId,
    zapsignDocumentId: zapsignDocumentId,
  );

  Future<ContratoRegistro?> buscarRegistro(String contratoId) {
    return _repository.buscarPorId(contratoId);
  }

  Future<Map<String, dynamic>> reemitirOuEnviarContrato({
    required String pacienteId,
    String contratoId = '',
    required String operacaoId,
    required bool confirmarReemissao,
  }) {
    return _functionsGateway.reemitirOuEnviarContrato(
      pacienteId: pacienteId,
      contratoId: contratoId,
      operacaoId: operacaoId,
      confirmarReemissao: confirmarReemissao,
    );
  }
}
