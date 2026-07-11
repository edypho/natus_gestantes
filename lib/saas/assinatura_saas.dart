class AssinaturaSaaS {
  final String adminDonoId;
  final String plano;
  final String status;
  final DateTime? vencimento;

  const AssinaturaSaaS({
    required this.adminDonoId,
    required this.plano,
    required this.status,
    this.vencimento,
  });

  bool get ativa {
    return status == StatusAssinaturaSaaS.ativa;
  }

  bool get bloqueada {
    return status == StatusAssinaturaSaaS.bloqueada ||
        status == StatusAssinaturaSaaS.cancelada;
  }
}

class StatusAssinaturaSaaS {
  static const String ativa = 'ativa';
  static const String teste = 'teste';
  static const String vencida = 'vencida';
  static const String bloqueada = 'bloqueada';
  static const String cancelada = 'cancelada';
}
