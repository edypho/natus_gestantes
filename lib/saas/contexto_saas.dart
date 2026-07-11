class ContextoSaaS {
  final String uidUsuario;
  final String emailUsuario;
  final String perfil;
  final String adminDonoId;
  final bool superAdmin;

  const ContextoSaaS({
    required this.uidUsuario,
    required this.emailUsuario,
    required this.perfil,
    required this.adminDonoId,
    required this.superAdmin,
  });

  bool get podeVerTudo {
    return superAdmin || perfil == 'superAdmin';
  }

  bool get temAdminDono {
    return adminDonoId.trim().isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'uidUsuario': uidUsuario,
      'emailUsuario': emailUsuario,
      'perfil': perfil,
      'adminDonoId': adminDonoId,
      'superAdmin': superAdmin,
    };
  }
}
