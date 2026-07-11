class LimitesSaaS {
  static bool atingiuLimiteGestantes({
    required int totalAtual,
    required int limitePlano,
  }) {
    return totalAtual >= limitePlano;
  }

  static bool moduloLiberado(bool ativo) {
    return ativo == true;
  }
}
