class TenantFilterService {
  static bool deveFiltrarPorAdmin({
    required String perfil,
    required String adminDonoId,
    bool superAdminVerificado = false,
  }) {
    if (perfil == 'superAdmin' && superAdminVerificado) {
      return false;
    }

    // Um tenant ausente não pode transformar um perfil comum em acesso global.
    return true;
  }

  static bool pertenceAoAdmin({
    required String? itemAdminDonoId,
    required String adminDonoId,
    required String perfil,
    bool superAdminVerificado = false,
  }) {
    if (perfil == 'superAdmin' && superAdminVerificado) {
      return true;
    }

    final item = itemAdminDonoId?.trim() ?? '';
    final admin = adminDonoId.trim();

    if (item.isEmpty || admin.isEmpty) return false;
    return item == admin;
  }
}
