import 'contexto_saas.dart';

class ContextoSaaSGuard {
  static bool podeFiltrarPorAdmin(ContextoSaaS? contexto) {
    if (contexto == null) {
      return false;
    }

    if (contexto.podeVerTudo) {
      return false;
    }

    return contexto.temAdminDono;
  }

  static String? adminFiltro(ContextoSaaS? contexto) {
    if (!podeFiltrarPorAdmin(contexto)) {
      return null;
    }

    return contexto!.adminDonoId;
  }
}
