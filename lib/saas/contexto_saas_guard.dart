import 'contexto_saas.dart';
import 'tenant_access_scope.dart';

class ContextoSaaSGuard {
  static bool podeFiltrarPorAdmin(ContextoSaaS? contexto) {
    if (contexto == null) {
      throw const TenantScopeException('Contexto de acesso ausente.');
    }

    return !TenantAccessScope.fromContexto(contexto).acessoGlobal;
  }

  static String? adminFiltro(ContextoSaaS? contexto) {
    if (contexto == null) {
      throw const TenantScopeException('Contexto de acesso ausente.');
    }

    final escopo = TenantAccessScope.fromContexto(contexto);
    if (escopo.acessoGlobal) return null;

    return escopo.clinicaId;
  }
}
