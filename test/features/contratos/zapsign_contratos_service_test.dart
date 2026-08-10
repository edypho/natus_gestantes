import 'package:flutter_test/flutter_test.dart';
import 'package:natus_gestantes/features/contratos/contratos.dart';
import 'package:natus_gestantes/saas/contexto_saas.dart';
import 'package:natus_gestantes/saas/tenant_access_scope.dart';

final class _FakeZapSignFunctionsGateway implements ZapSignFunctionsGateway {
  String? contratoGeradoId;
  Map<String, dynamic>? payloadGerado;
  String? contratoConsultadoId;
  String? documentoConsultadoId;

  @override
  Future<Map<String, dynamic>> gerarContrato({
    required String contratoId,
    required Map<String, dynamic> payload,
  }) async {
    contratoGeradoId = contratoId;
    payloadGerado = payload;
    return {'status': 'enviado', 'documentoId': 'documento-zapsign'};
  }

  @override
  Future<Map<String, dynamic>> consultarContrato({
    required String contratoId,
    required String zapsignDocumentId,
  }) async {
    contratoConsultadoId = contratoId;
    documentoConsultadoId = zapsignDocumentId;
    return {'status': 'assinado'};
  }
}

TenantAccessScope _escopoAdministrativo() {
  return TenantAccessScope.fromContexto(
    const ContextoSaaS(
      uidUsuario: 'admin-1',
      emailUsuario: 'admin@natus.test',
      perfil: 'admin',
      clinicaId: 'clinica-1',
      adminDonoId: 'clinica-1',
      superAdmin: false,
    ),
  );
}

const _solicitacao = ContratoSolicitacao(
  pacienteId: 'paciente-1',
  nomePaciente: 'Paciente Teste',
  emailPaciente: 'paciente@natus.test',
  telefonePaciente: '11999999999',
  cpfPaciente: '00000000000',
  rgPaciente: '000000000',
  enderecoPaciente: 'Rua Teste, 1',
  nomeResponsavel: '',
  cpfResponsavel: '',
  enderecoResponsavel: '',
  dpp: '',
  planoNome: 'Plano Teste',
  modalidadeNome: 'Modalidade Teste',
  templateKey: 'template-1',
  cidadeAssinatura: 'Sao Paulo',
  dataAssinatura: '2026-07-22',
  formaPagamento: 'parcelado',
  vencimentoParcelas: 'todo dia 10',
  observacoesContrato: '',
  numeroParcelas: 3,
  valorTotal: 3000,
  valorEntrada: 0,
  valorSaldo: 3000,
  valorParcela: 1000,
);

void main() {
  late _FakeZapSignFunctionsGateway gateway;
  late ZapSignContratosService service;

  setUp(() {
    gateway = _FakeZapSignFunctionsGateway();
    service = ZapSignContratosService(
      escopo: _escopoAdministrativo(),
      functionsGateway: gateway,
    );
  });

  test('encaminha a geracao ao gateway e preserva o payload', () async {
    final resposta = await service.gerarContrato(
      contratoId: 'contrato-1',
      solicitacao: _solicitacao,
    );

    expect(gateway.contratoGeradoId, 'contrato-1');
    expect(gateway.payloadGerado, _solicitacao.toMap());
    expect(resposta, {'status': 'enviado', 'documentoId': 'documento-zapsign'});
  });

  test('encaminha a consulta com os identificadores corretos', () async {
    final resposta = await service.consultarStatus(
      contratoId: 'contrato-1',
      zapsignDocumentId: 'documento-zapsign',
    );

    expect(gateway.contratoConsultadoId, 'contrato-1');
    expect(gateway.documentoConsultadoId, 'documento-zapsign');
    expect(resposta, {'status': 'assinado'});
  });
}
