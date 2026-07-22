class ContextoSaaS {
  final String uidUsuario;
  final String nomeUsuario;
  final String emailUsuario;
  final String perfil;
  final String clinicaId;
  final String adminDonoId;
  final String pacienteId;
  final bool vinculoPacienteConsistente;
  final bool superAdmin;

  const ContextoSaaS({
    required this.uidUsuario,
    this.nomeUsuario = '',
    required this.emailUsuario,
    required this.perfil,
    this.clinicaId = '',
    required this.adminDonoId,
    this.pacienteId = '',
    this.vinculoPacienteConsistente = true,
    required this.superAdmin,
  });

  factory ContextoSaaS.fromUsuario({
    required String uidUsuario,
    required String emailUsuario,
    required Map<String, dynamic> dados,
    bool superAdminVerificado = false,
  }) {
    String texto(dynamic valor) => (valor ?? '').toString().trim();

    String normalizarPerfil(String perfil) {
      return switch (perfil.toLowerCase()) {
        'superadmin' || 'super_admin' => 'superAdmin',
        'admin' => 'admin',
        'enfermeira' => 'enfermeira',
        'obstetra' => 'obstetra',
        'profissional' => 'profissional',
        'gestante' || 'paciente' => 'gestante',
        _ => perfil,
      };
    }

    final tipo = texto(dados['tipo']);
    final tipoUsuario = texto(dados['tipoUsuario']);
    final perfilTipo = tipo.isEmpty ? '' : normalizarPerfil(tipo);
    final perfilTipoUsuario = tipoUsuario.isEmpty
        ? ''
        : normalizarPerfil(tipoUsuario);
    final perfisDivergentes =
        perfilTipo.isNotEmpty &&
        perfilTipoUsuario.isNotEmpty &&
        perfilTipo != perfilTipoUsuario;
    final perfilNormalizado = perfisDivergentes
        ? '__perfil_inconsistente__'
        : perfilTipo.isNotEmpty
        ? perfilTipo
        : perfilTipoUsuario;
    final pacienteIdCanonico = texto(dados['pacienteId']);
    final gestanteId = texto(dados['gestanteId']);
    final idGestante = texto(dados['idGestante']);
    final idsPaciente = <String>{pacienteIdCanonico, gestanteId, idGestante}
      ..remove('');
    final uidsPaciente = <String>{
      texto(dados['uidPaciente']),
      texto(dados['pacienteUid']),
      texto(dados['uidGestante']),
      texto(dados['gestanteUid']),
    }..remove('');
    final uidAutenticado = uidUsuario.trim();
    final vinculoPacienteConsistente =
        idsPaciente.length <= 1 &&
        uidsPaciente.length <= 1 &&
        (uidsPaciente.isEmpty || uidsPaciente.single == uidAutenticado);
    final pacienteId = pacienteIdCanonico.isNotEmpty
        ? pacienteIdCanonico
        : gestanteId.isNotEmpty
        ? gestanteId
        : idGestante;

    return ContextoSaaS(
      uidUsuario: uidUsuario.trim(),
      nomeUsuario: texto(dados['nome']),
      emailUsuario: emailUsuario.trim(),
      perfil: perfilNormalizado,
      clinicaId: texto(dados['clinicaId']),
      adminDonoId: texto(dados['adminDonoId']),
      pacienteId: pacienteId,
      vinculoPacienteConsistente: vinculoPacienteConsistente,
      superAdmin: perfilNormalizado == 'superAdmin' && superAdminVerificado,
    );
  }

  bool get podeVerTudo {
    return superAdmin && perfil == 'superAdmin';
  }

  bool get temAdminDono {
    return adminDonoId.trim().isNotEmpty;
  }

  bool get temClinica {
    return clinicaId.trim().isNotEmpty || adminDonoId.trim().isNotEmpty;
  }

  bool get vinculoClinicaConsistente {
    final clinica = clinicaId.trim();
    final admin = adminDonoId.trim();

    if (clinica.isEmpty || admin.isEmpty) return true;
    return clinica == admin;
  }

  Map<String, dynamic> toMap() {
    return {
      'uidUsuario': uidUsuario,
      'nomeUsuario': nomeUsuario,
      'emailUsuario': emailUsuario,
      'perfil': perfil,
      'clinicaId': clinicaId,
      'adminDonoId': adminDonoId,
      'pacienteId': pacienteId,
      'vinculoPacienteConsistente': vinculoPacienteConsistente,
      'superAdmin': superAdmin,
    };
  }
}
