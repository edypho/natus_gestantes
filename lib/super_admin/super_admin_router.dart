import 'package:flutter/material.dart';

import 'super_admin_dashboard.dart';
import 'super_admin_clinicas_page.dart';
import 'super_admin_usuarios_page.dart';
import 'super_admin_mensalidades_page.dart';
import 'super_admin_financeiro_page.dart';
import 'super_admin_criacao_page.dart';
import 'super_admin_crescimento_page.dart';

class SuperAdminRouter {
  static Widget tela(String telaAtual) {
    switch (telaAtual) {
      case 'Dashboard SaaS':
      case 'Dashboard':
        return const SuperAdminDashboard();

      case 'Clínicas cadastradas SaaS':
        return const SuperAdminClinicasPage();

      case 'Usuários/clientes SaaS':
        return const SuperAdminUsuariosPage();

      case 'Mensalidades atrasadas SaaS':
        return const SuperAdminMensalidadesPage();

      case 'Financeiro das assinaturas SaaS':
        return const SuperAdminFinanceiroPage();

      case 'Criação de clínica/admin/enfermeira SaaS':
        return const SuperAdminCriacaoPage();

      case 'Crescimento de usuários por período SaaS':
        return const SuperAdminCrescimentoPage();

      default:
        return const SuperAdminDashboard();
    }
  }
}
