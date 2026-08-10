/// Catálogo inicial das especialidades aceitas pelo cadastro modular.
///
/// O valor é persistido como texto para permitir evolução do catálogo sem
/// alterar os identificadores legados dos pacientes já cadastrados.
abstract final class NatusEspecialidades {
  static const String clinicaGeral = 'Clínica geral';
  static const String obstetricia = 'Obstetrícia';
  static const String pediatria = 'Pediatria';

  static const List<String> opcoes = [
    clinicaGeral,
    obstetricia,
    'Ginecologia',
    pediatria,
    'Psicologia',
    'Fisioterapia',
    'Nutrição',
    'Odontologia',
    'Cardiologia',
    'Dermatologia',
    'Ortopedia',
    'Outra especialidade',
  ];

  static bool ehObstetricia(String? especialidade) {
    return (especialidade ?? '').trim().toLowerCase().contains('obstetr');
  }

  static String tituloContato(String especialidade) {
    return switch (especialidade) {
      obstetricia => 'Cônjuge / acompanhante',
      pediatria => 'Responsável legal',
      _ => 'Contato de emergência (opcional)',
    };
  }
}
