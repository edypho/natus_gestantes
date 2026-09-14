import '../models/contrato_template_config.dart';

class CatalogoContratosNatus {
  static const List<ContratoTemplateConfig> templates = [
    ContratoTemplateConfig(
      chave: 'presenca_consultorio',
      planoCodigo: ContratoPlanoCodigo.presenca,
      modalidadeCodigo: ContratoModalidadeCodigo.consultorio,
      nomePlano: 'Presenca',
      nomeModalidade: 'Consultorio',
      valorPadrao: 4000,
    ),
    ContratoTemplateConfig(
      chave: 'plenitude_consultorio',
      planoCodigo: ContratoPlanoCodigo.plenitude,
      modalidadeCodigo: ContratoModalidadeCodigo.consultorio,
      nomePlano: 'Plenitude',
      nomeModalidade: 'Consultorio',
      valorPadrao: 5000,
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

    for (final template in templates) {
      if (template.planoCodigo == planoCodigo) {
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
