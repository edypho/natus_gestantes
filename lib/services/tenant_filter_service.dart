class TenantFilterService {
  static bool deveFiltrarPorAdmin({
    required String perfil,
    required String adminDonoId,
  }) {
    if (perfil == 'superAdmin') {
      return false;
    }

    return adminDonoId.trim().isNotEmpty;
  }

  static bool pertenceAoAdmin({
    required String? itemAdminDonoId,
    required String adminDonoId,
    required String perfil,
  }) {
    if (perfil == 'superAdmin') {
      return true;
    }

    return itemAdminDonoId == adminDonoId;
  }
}
