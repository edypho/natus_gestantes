class SuperAdminService {
  static bool usuarioEhSuperAdmin(String tipoUsuario) {
    return tipoUsuario == 'superAdmin';
  }

  static bool usuarioEhClinica(String tipoUsuario) {
    return tipoUsuario == 'admin';
  }

  static bool usuarioEhEnfermeira(String tipoUsuario) {
    return tipoUsuario == 'enfermeira';
  }

  static bool usuarioEhProfissionalClinica(String tipoUsuario) {
    return tipoUsuario == 'enfermeira' || tipoUsuario == 'obstetra';
  }

  static bool usuarioEhGestante(String tipoUsuario) {
    return tipoUsuario == 'gestante';
  }
}
