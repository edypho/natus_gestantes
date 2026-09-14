const int quantidadeInicialPacientes = 30;

List<T> pacientesVisiveis<T>(List<T> pacientes, int limite) {
  if (limite <= 0 || pacientes.isEmpty) return <T>[];
  if (limite >= pacientes.length) return pacientes;
  return pacientes.take(limite).toList(growable: false);
}

int proximoLimitePacientes(
  int limiteAtual,
  int total, {
  int quantidade = quantidadeInicialPacientes,
}) {
  if (total <= 0 || quantidade <= 0) return 0;
  final proximo = limiteAtual + quantidade;
  return proximo < total ? proximo : total;
}
