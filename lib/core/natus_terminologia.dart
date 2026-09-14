/// Terminologia apresentada na experiência principal do Natus.
///
/// Identificadores legados de banco, rotas e perfis continuam inalterados para
/// preservar compatibilidade. Conceitos obstétricos permanecem disponíveis nos
/// módulos específicos, mas não definem mais o produto inteiro.
abstract final class NatusTermos {
  static const String paciente = 'paciente';
  static const String pacientes = 'pacientes';
  static const String pacienteTitulo = 'Paciente';
  static const String pacientesTitulo = 'Pacientes';

  static const String profissional = 'profissional';
  static const String profissionais = 'profissionais';
  static const String profissionalTitulo = 'Profissional';
  static const String profissionaisTitulo = 'Profissionais';

  static const String clinica = 'clínica';
  static const String acompanhamento = 'acompanhamento';

  /// Converte somente rótulos visíveis. O valor de rota recebido pelo código
  /// continua sendo o legado e não deve ser persistido com este retorno.
  static String rotuloMenu(String rota) {
    return switch (rota) {
      'Gestantes' => pacientesTitulo,
      'Área da gestante' => 'Meu acompanhamento',
      'Cadastro' => 'Cadastrar paciente',
      'Criação de clínica/admin/enfermeira SaaS' =>
        'Criação de clínica/admin/profissional SaaS',
      _ => rota,
    };
  }

  /// Traduz perfis legados sem alterar o valor usado nas permissões.
  static String rotuloPerfil(String perfil) {
    return switch (perfil.trim().toLowerCase()) {
      'gestante' || 'paciente' => pacienteTitulo,
      'enfermeira' || 'obstetra' || 'profissional' => profissionalTitulo,
      'admin' => 'Admin da clínica',
      'superadmin' || 'super_admin' => 'SuperAdmin',
      _ => perfil,
    };
  }

  /// Mantém os códigos de status legados usados nos filtros e no Firestore,
  /// alterando somente o texto exibido na interface.
  static String rotuloStatusPaciente(String status) {
    return switch (status.trim().toLowerCase()) {
      'gestante' => 'Acompanhamento obstétrico',
      'puérpera' || 'puerpera' => 'Pós-parto',
      _ => status,
    };
  }
}
