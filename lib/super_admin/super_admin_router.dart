import 'package:flutter/material.dart';

import 'super_admin_dashboard.dart';
import 'super_admin_clinicas_page.dart';
import 'super_admin_usuarios_page.dart';
import 'super_admin_mensalidades_page.dart';
import 'super_admin_financeiro_page.dart';
import 'super_admin_criacao_page.dart';
import 'super_admin_crescimento_page.dart';
import 'super_admin_navigation.dart';

class SuperAdminRouter {
  static Widget tela(String telaAtual) {
    switch (SuperAdminNavigation.resolver(telaAtual).id) {
      case 'visao-geral':
        return const SuperAdminDashboard();

      case 'clinicas':
        return const SuperAdminClinicasPage();

      case 'usuarios':
        return const SuperAdminUsuariosPage();

      case 'mensalidades':
        return const SuperAdminMensalidadesPage();

      case 'assinaturas':
        return const SuperAdminFinanceiroPage();

      case 'nova-clinica':
        return const SuperAdminCriacaoPage();

      case 'crescimento':
        return const SuperAdminCrescimentoPage();

      default:
        return const SuperAdminDashboard();
    }
  }
}
