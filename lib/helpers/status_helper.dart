String normalizarStatus(dynamic valor) {
  if (valor == null) {
    return '';
  }

  return valor.toString().trim().toLowerCase();
}

bool statusEhPago(dynamic valor) {
  final status = normalizarStatus(valor);

  return status == 'pago' || status == 'paga';
}

bool statusEhEncerrado(dynamic valor) {
  final status = normalizarStatus(valor);

  return status == 'encerrada' || status == 'encerrado';
}
