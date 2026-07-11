class PermissoesService {
  static bool podeAcessarFinanceiro(String perfil) {
    return perfil == 'admin' ||
        perfil == 'superAdmin';
  }

  static bool podeEditarGestantes(String perfil) {
    return perfil == 'admin' ||
        perfil == 'superAdmin' ||
        perfil == 'enfermeira' ||
        perfil == 'obstetra';
  }

  static bool podeVerDashboard(String perfil) {
    return perfil != 'gestante';
  }

  static bool podeVerBiblioteca(String perfil) {
    return true;
  }

  static bool podeVerLogs(String perfil) {
    return perfil == 'superAdmin';
  }
}
