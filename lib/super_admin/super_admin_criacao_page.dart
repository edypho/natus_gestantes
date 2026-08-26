import 'package:flutter/material.dart';

import 'super_admin_crud_dialogs.dart';
import 'super_admin_layout.dart';

class SuperAdminCriacaoPage extends StatelessWidget {
  const SuperAdminCriacaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminPageScaffold(
      titulo: 'Cadastrar clínica',
      subtitulo:
          'Crie a operação comercial completa com clínica, administrador, plano e assinatura.',
      icone: Icons.add_business_rounded,
      child: SuperAdminActionCard(
        titulo: 'Nova clínica + administrador',
        descricao:
            'O administrador receberá um link seguro para definir a senha. Depois, ele poderá cadastrar profissionais, pacientes e equipe.',
        icone: Icons.add_business_rounded,
        onTap: () => superAdminCriarClinicaComAdminDialog(context: context),
      ),
    );
  }
}
