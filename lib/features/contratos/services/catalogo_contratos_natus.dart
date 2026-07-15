import '../models/contrato_template_config.dart';

class CatalogoContratosNatus {
  static const List<ContratoTemplateConfig> templates = [
    ContratoTemplateConfig(
      chave: 'acolher_consultorio',
      planoCodigo: ContratoPlanoCodigo.acolher,
      modalidadeCodigo: ContratoModalidadeCodigo.consultorio,
      nomePlano: 'Acolher',
      nomeModalidade: 'Consultorio',
      valorPadrao: 3000,
    ),
    ContratoTemplateConfig(
      chave: 'acolher_residencial',
      planoCodigo: ContratoPlanoCodigo.acolher,
      modalidadeCodigo: ContratoModalidadeCodigo.residencial,
      nomePlano: 'Acolher',
      nomeModalidade: 'Residencial',
      valorPadrao: 3300,
    ),
    ContratoTemplateConfig(
      chave: 'presenca_consultorio',
      planoCodigo: ContratoPlanoCodigo.presenca,
      modalidadeCodigo: ContratoModalidadeCodigo.consultorio,
      nomePlano: 'Presenca',
      nomeModalidade: 'Consultorio',
      valorPadrao: 3500,
    ),
    ContratoTemplateConfig(
      chave: 'presenca_residencial',
      planoCodigo: ContratoPlanoCodigo.presenca,
      modalidadeCodigo: ContratoModalidadeCodigo.residencial,
      nomePlano: 'Presenca',
      nomeModalidade: 'Residencial',
      valorPadrao: 3800,
    ),
    ContratoTemplateConfig(
      chave: 'plenitude_consultorio',
      planoCodigo: ContratoPlanoCodigo.plenitude,
      modalidadeCodigo: ContratoModalidadeCodigo.consultorio,
      nomePlano: 'Plenitude',
      nomeModalidade: 'Consultorio',
      valorPadrao: 4200,
    ),
    ContratoTemplateConfig(
      chave: 'plenitude_residencial',
      planoCodigo: ContratoPlanoCodigo.plenitude,
      modalidadeCodigo: ContratoModalidadeCodigo.residencial,
      nomePlano: 'Plenitude',
      nomeModalidade: 'Residencial',
      valorPadrao: 4500,
    ),
  ];

  static ContratoTemplateConfig? localizarPorChave(String chave) {
    final chaveNormalizada = chave.trim().toLowerCase();

    for (final template in templates) {
      if (template.chave == chaveNormalizada) {
        return template;
      }
    }

    return null;
  }

  static ContratoTemplateConfig? localizarPorPlanoEModalidade({
    required String nomePlano,
    required String consultorio,
  }) {
    final templatePorNomeCompleto = localizarPorNomePlanoCompleto(nomePlano);
    if (templatePorNomeCompleto != null) {
      return templatePorNomeCompleto;
    }

    final planoCodigo = _planoPorNome(nomePlano);
    if (planoCodigo == null) {
      return null;
    }

    final modalidadeCodigo = _modalidadePorCampo(consultorio);

    for (final template in templates) {
      if (template.planoCodigo == planoCodigo &&
          template.modalidadeCodigo == modalidadeCodigo) {
        return template;
      }
    }

    return null;
  }

  static ContratoTemplateConfig? localizarPorNomePlanoCompleto(
    String nomePlano,
  ) {
    final valor = _normalizar(nomePlano);

    for (final template in templates) {
      final nomeCompleto = _normalizar(
        '${template.nomePlano} ${template.nomeModalidade}',
      );

      if (nomeCompleto == valor) {
        return template;
      }
    }

    return null;
  }

  static ContratoPlanoCodigo? _planoPorNome(String nomePlano) {
    final valor = _normalizar(nomePlano);

    if (valor.contains('acolher')) {
      return ContratoPlanoCodigo.acolher;
    }

    if (valor.contains('presenca')) {
      return ContratoPlanoCodigo.presenca;
    }

    if (valor.contains('plenitude')) {
      return ContratoPlanoCodigo.plenitude;
    }

    return null;
  }

  static ContratoModalidadeCodigo _modalidadePorCampo(String consultorio) {
    final valor = _normalizar(consultorio);
    if (valor == 'sim' ||
        valor == 'consultorio' ||
        valor.contains('consultorio')) {
      return ContratoModalidadeCodigo.consultorio;
    }

    return ContratoModalidadeCodigo.residencial;
  }

  static String _normalizar(String valor) {
    const mapaAcentos = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };

    final texto = valor.toLowerCase().trim();
    final buffer = StringBuffer();

    for (final caractere in texto.split('')) {
      buffer.write(mapaAcentos[caractere] ?? caractere);
    }

    return buffer.toString();
  }
}
