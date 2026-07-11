class StatusService {
  static bool pago(dynamic valor) {
    final status = valor?.toString().trim().toLowerCase() ?? '';
    return status == 'pago' || status == 'paga';
  }

  static bool gestanteAtiva(dynamic valor) {
    final status = valor?.toString().trim().toLowerCase() ?? '';
    return status != 'histórico' &&
        status != 'historico' &&
        status != 'encerrada' &&
        status != 'encerrado';
  }
}
