import 'package:flutter/material.dart';
import 'package:natus_gestantes/shared/natus_app.dart';
import 'package:natus_gestantes/shared/natus_premium_visual.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _NatusMenuItem {
  final String titulo;
  final IconData icone;

  const _NatusMenuItem(this.titulo, this.icone);
}

Widget menuLateralRealNatus({
  required BuildContext context,
  required String tipoUsuario,
  required String telaAtual,
  required Function(String) onSelecionarTela,
}) {
  final marsala = NatusApp.marsala;
  const menuText = Color(0xFFFFF8F2);

  List<_NatusMenuItem> itensDoMenu() {
    if (tipoUsuario == 'superAdmin') {
      return const [
        _NatusMenuItem('Dashboard SaaS', Icons.dashboard_rounded),
        _NatusMenuItem('Clínicas cadastradas SaaS', Icons.apartment_rounded),
        _NatusMenuItem('Usuários/clientes SaaS', Icons.people_alt_rounded),
        _NatusMenuItem(
          'Mensalidades atrasadas SaaS',
          Icons.warning_amber_rounded,
        ),
        _NatusMenuItem(
          'Financeiro das assinaturas SaaS',
          Icons.payments_rounded,
        ),
        _NatusMenuItem(
          'Criação de clínica/admin/enfermeira SaaS',
          Icons.add_business_rounded,
        ),
        _NatusMenuItem(
          'Crescimento de usuários por período SaaS',
          Icons.trending_up_rounded,
        ),
      ];
    }

    if (tipoUsuario == 'gestante') {
      return const [
        _NatusMenuItem('Área da gestante', Icons.favorite_rounded),
        _NatusMenuItem('Exames', Icons.medical_information_rounded),
        _NatusMenuItem('Documentos', Icons.folder_copy_rounded),
        _NatusMenuItem('Contrações', Icons.monitor_heart_rounded),
        _NatusMenuItem('Biblioteca', Icons.video_library_rounded),
        _NatusMenuItem('Calculadora de IG', Icons.calculate_rounded),
      ];
    }

    if (tipoUsuario == 'enfermeira' || tipoUsuario == 'obstetra') {
      return const [
        _NatusMenuItem('Dashboard', Icons.dashboard_rounded),
        _NatusMenuItem('Mapa', Icons.map_rounded),
        _NatusMenuItem('Gestantes', Icons.pregnant_woman_rounded),
        _NatusMenuItem('Prontuário', Icons.assignment_rounded),
        _NatusMenuItem('Calculadora de IG', Icons.calculate_rounded),
        _NatusMenuItem('Atendimentos', Icons.medical_services_rounded),
        _NatusMenuItem('Contrações', Icons.monitor_heart_rounded),
        _NatusMenuItem('Biblioteca', Icons.video_library_rounded),
        _NatusMenuItem('Documentos', Icons.folder_copy_rounded),
        _NatusMenuItem('Exames', Icons.medical_information_rounded),
      ];
    }

    return const [
      _NatusMenuItem('Dashboard', Icons.dashboard_rounded),
      _NatusMenuItem('Mapa', Icons.map_rounded),
      _NatusMenuItem('Cadastro', Icons.person_add_alt_1_rounded),
      _NatusMenuItem('Gestantes', Icons.pregnant_woman_rounded),
      _NatusMenuItem('Prontuário', Icons.assignment_rounded),
      _NatusMenuItem('Calculadora de IG', Icons.calculate_rounded),
      _NatusMenuItem('Atendimentos', Icons.medical_services_rounded),
      _NatusMenuItem('Contrações', Icons.monitor_heart_rounded),
      _NatusMenuItem('Financeiro', Icons.payments_rounded),
      _NatusMenuItem('Planos da Natus', Icons.workspace_premium_rounded),
      _NatusMenuItem('Almoxarifado', Icons.inventory_2_rounded),
      _NatusMenuItem('Centro de custo', Icons.account_balance_wallet_rounded),
      _NatusMenuItem('Biblioteca', Icons.video_library_rounded),
      _NatusMenuItem('Documentos', Icons.folder_copy_rounded),
      _NatusMenuItem('Exames', Icons.medical_information_rounded),
      _NatusMenuItem('Usuários', Icons.manage_accounts_rounded),
      _NatusMenuItem('Cadastrar EO', Icons.badge_rounded),
      _NatusMenuItem('Configurações', Icons.settings_rounded),
    ];
  }

  Widget itemMenu(_NatusMenuItem item) {
    final ativo =
        telaAtual == item.titulo ||
        (telaAtual == 'Dashboard' && item.titulo == 'Dashboard SaaS') ||
        (telaAtual == 'Dashboard SaaS' && item.titulo == 'Dashboard');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelecionarTela(item.titulo),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: ativo ? NatusApp.offWhite.withValues(alpha: 0.96) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: ativo
                ? Border.all(color: Colors.white.withValues(alpha: 0.42))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ativo
                      ? marsala.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icone,
                  size: 20,
                  color: ativo ? marsala : menuText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ativo ? marsala : menuText,
                    fontSize: 13.5,
                    fontWeight: ativo ? FontWeight.w800 : FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final itens = itensDoMenu();

  return Container(
    width: 294,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF8A4247),
          Color(0xFF6B3136),
          Color(0xFF351422),
        ],
        stops: [0.0, 0.58, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: NatusApp.vinhoProfundo.withValues(alpha: 0.28),
          blurRadius: 34,
          spreadRadius: -10,
          offset: const Offset(12, 0),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -0.95),
                  radius: 1.15,
                  colors: [
                    Colors.white.withValues(alpha: 0.105),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          right: -96,
          bottom: 36,
          child: Opacity(
            opacity: 0.18,
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: BotanicalNatusPainter(
                  color: Color(0xFFFFDACF),
                  mirror: true,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: SizedBox(
              height: 184,
              width: double.infinity,
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: itens.length,
              itemBuilder: (context, index) => itemMenu(itens[index]),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 14),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.13)),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.105),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Sair',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ],
    ),
  );
}

