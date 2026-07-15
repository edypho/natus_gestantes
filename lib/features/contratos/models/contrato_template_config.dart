enum ContratoPlanoCodigo { acolher, presenca, plenitude }

enum ContratoModalidadeCodigo { consultorio, residencial }

class ContratoTemplateConfig {
  final String chave;
  final ContratoPlanoCodigo planoCodigo;
  final ContratoModalidadeCodigo modalidadeCodigo;
  final String nomePlano;
  final String nomeModalidade;
  final double valorPadrao;
  final String templateIdZapSign;

  const ContratoTemplateConfig({
    required this.chave,
    required this.planoCodigo,
    required this.modalidadeCodigo,
    required this.nomePlano,
    required this.nomeModalidade,
    required this.valorPadrao,
    this.templateIdZapSign = '',
  });

  bool get prontoParaIntegracao => templateIdZapSign.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'chave': chave,
      'planoCodigo': planoCodigo.name,
      'modalidadeCodigo': modalidadeCodigo.name,
      'nomePlano': nomePlano,
      'nomeModalidade': nomeModalidade,
      'valorPadrao': valorPadrao,
      'templateIdZapSign': templateIdZapSign,
      'prontoParaIntegracao': prontoParaIntegracao,
    };
  }
}
