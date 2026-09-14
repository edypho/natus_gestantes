class EnvioAcessoGuard {
  final Set<String> _pacientesEmAndamento = <String>{};

  bool emAndamento(String pacienteId) {
    return _pacientesEmAndamento.contains(pacienteId.trim());
  }

  bool iniciar(String pacienteId) {
    final id = pacienteId.trim();
    return id.isNotEmpty && _pacientesEmAndamento.add(id);
  }

  void concluir(String pacienteId) {
    _pacientesEmAndamento.remove(pacienteId.trim());
  }
}
