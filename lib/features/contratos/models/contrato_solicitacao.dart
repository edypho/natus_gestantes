class ContratoSolicitacao {
  final String pacienteId;
  final String nomePaciente;
  final String emailPaciente;
  final String telefonePaciente;
  final String cpfPaciente;
  final String enderecoPaciente;
  final String nomeResponsavel;
  final String cpfResponsavel;
  final String enderecoResponsavel;
  final String dpp;
  final String planoNome;
  final String modalidadeNome;
  final String templateKey;
  final String cidadeAssinatura;
  final String dataAssinatura;
  final String formaPagamento;
  final String observacoesContrato;
  final int numeroParcelas;
  final double valorTotal;
  final double valorEntrada;
  final double valorSaldo;
  final double valorParcela;

  const ContratoSolicitacao({
    required this.pacienteId,
    required this.nomePaciente,
    required this.emailPaciente,
    required this.telefonePaciente,
    required this.cpfPaciente,
    required this.enderecoPaciente,
    required this.nomeResponsavel,
    required this.cpfResponsavel,
    required this.enderecoResponsavel,
    required this.dpp,
    required this.planoNome,
    required this.modalidadeNome,
    required this.templateKey,
    required this.cidadeAssinatura,
    required this.dataAssinatura,
    required this.formaPagamento,
    required this.observacoesContrato,
    required this.numeroParcelas,
    required this.valorTotal,
    required this.valorEntrada,
    required this.valorSaldo,
    required this.valorParcela,
  });

  Map<String, dynamic> toMap() {
    return {
      'pacienteId': pacienteId,
      'nomePaciente': nomePaciente,
      'emailPaciente': emailPaciente,
      'telefonePaciente': telefonePaciente,
      'cpfPaciente': cpfPaciente,
      'enderecoPaciente': enderecoPaciente,
      'nomeResponsavel': nomeResponsavel,
      'cpfResponsavel': cpfResponsavel,
      'enderecoResponsavel': enderecoResponsavel,
      'dpp': dpp,
      'planoNome': planoNome,
      'modalidadeNome': modalidadeNome,
      'templateKey': templateKey,
      'cidadeAssinatura': cidadeAssinatura,
      'dataAssinatura': dataAssinatura,
      'formaPagamento': formaPagamento,
      'observacoesContrato': observacoesContrato,
      'numeroParcelas': numeroParcelas,
      'valorTotal': valorTotal,
      'valorEntrada': valorEntrada,
      'valorSaldo': valorSaldo,
      'valorParcela': valorParcela,
    };
  }
}
