import '../models/contrato_solicitacao.dart';
import '../services/catalogo_contratos_natus.dart';

class ContratoPayloadMapper {
  static Map<String, dynamic> criarMetadadosIniciais({
    required Map<String, dynamic> paciente,
    required double valorTotal,
    required double valorEntrada,
    required double valorSaldo,
    required double valorParcela,
    required int numeroParcelas,
  }) {
    final template = CatalogoContratosNatus.localizarPorPlanoEModalidade(
      nomePlano: (paciente['plano'] ?? '').toString(),
      consultorio: (paciente['consultorio'] ?? '').toString(),
    );
    final valorContratual = template?.valorPadrao ?? valorTotal;
    final entradaContratual = valorEntrada.clamp(0, valorContratual).toDouble();
    final saldoContratual = valorContratual - entradaContratual;
    final parcelasContratuais = numeroParcelas < 1 ? 1 : numeroParcelas;

    return {
      'contratoGeracaoAutomatica': template != null,
      'contratoStatus': 'pendente',
      'contratoTemplateKey': template?.chave ?? '',
      'contratoPlanoCodigo': template?.planoCodigo.name ?? '',
      'contratoModalidadeCodigo': template?.modalidadeCodigo.name ?? '',
      'contratoTemplatePronto': template?.prontoParaIntegracao ?? false,
      'contratoResumo': {
        'planoNome': (paciente['plano'] ?? '').toString(),
        'modalidadeNome':
            template?.nomeModalidade ??
            _nomeModalidade((paciente['consultorio'] ?? '').toString()),
        'valorTotal': valorContratual,
        'valorEntrada': entradaContratual,
        'valorSaldo': saldoContratual,
        'numeroParcelas': parcelasContratuais,
        'valorParcela': saldoContratual / parcelasContratuais,
      },
    };
  }

  static ContratoSolicitacao fromPaciente({
    required String pacienteId,
    required Map<String, dynamic> paciente,
    required double valorTotal,
    required double valorEntrada,
    required double valorSaldo,
    required double valorParcela,
    required int numeroParcelas,
  }) {
    final template = CatalogoContratosNatus.localizarPorPlanoEModalidade(
      nomePlano: (paciente['plano'] ?? '').toString(),
      consultorio: (paciente['consultorio'] ?? '').toString(),
    );
    final valorContratual = template?.valorPadrao ?? valorTotal;
    final entradaContratual = valorEntrada.clamp(0, valorContratual).toDouble();
    final saldoContratual = valorContratual - entradaContratual;
    final parcelasContratuais = numeroParcelas < 1 ? 1 : numeroParcelas;

    final enderecoPaciente = _montarEnderecoPaciente(paciente);

    return ContratoSolicitacao(
      pacienteId: pacienteId,
      nomePaciente: (paciente['nomeGestante'] ?? '').toString(),
      emailPaciente: (paciente['emailGestante'] ?? '').toString(),
      telefonePaciente: (paciente['telefoneGestante'] ?? '').toString(),
      cpfPaciente: (paciente['cpfGestante'] ?? '').toString(),
      rgPaciente: (paciente['rgGestante'] ?? '').toString(),
      enderecoPaciente: enderecoPaciente,
      nomeResponsavel: (paciente['nomePai'] ?? '').toString(),
      cpfResponsavel: (paciente['cpfPai'] ?? '').toString(),
      enderecoResponsavel: enderecoPaciente,
      dpp: (paciente['dpp'] ?? '').toString(),
      planoNome: template?.nomePlano ?? (paciente['plano'] ?? '').toString(),
      modalidadeNome:
          template?.nomeModalidade ??
          _nomeModalidade((paciente['consultorio'] ?? '').toString()),
      templateKey: template?.chave ?? '',
      cidadeAssinatura: (paciente['cidadeGestante'] ?? 'Curitiba').toString(),
      dataAssinatura: DateTime.now().toIso8601String(),
      formaPagamento: (paciente['formaPagamento'] ?? '').toString(),
      vencimentoParcelas: '',
      observacoesContrato: '',
      numeroParcelas: parcelasContratuais,
      valorTotal: valorContratual,
      valorEntrada: entradaContratual,
      valorSaldo: saldoContratual,
      valorParcela: saldoContratual / parcelasContratuais,
    );
  }

  static String _nomeModalidade(String consultorio) {
    final valor = consultorio.trim().toLowerCase();
    return valor == 'sim' ? 'Consultorio' : 'Residencial';
  }

  static String _montarEnderecoPaciente(Map<String, dynamic> paciente) {
    final partes = <String>[
      (paciente['enderecoGestante'] ?? '').toString(),
      (paciente['numeroGestante'] ?? '').toString(),
      (paciente['complementoGestante'] ?? '').toString(),
      (paciente['bairroGestante'] ?? '').toString(),
      (paciente['cidadeGestante'] ?? '').toString(),
      (paciente['estadoGestante'] ?? '').toString(),
      (paciente['cepGestante'] ?? '').toString(),
    ];

    return partes.where((parte) => parte.trim().isNotEmpty).join(', ');
  }
}
