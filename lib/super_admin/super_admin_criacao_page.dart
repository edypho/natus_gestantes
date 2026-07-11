import 'package:flutter/material.dart';

import 'super_admin_crud_dialogs.dart';
import 'super_admin_layout.dart';

class SuperAdminCriacaoPage extends StatelessWidget {
  const SuperAdminCriacaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminPageScaffold(
      titulo: 'Criação de clínica/admin SaaS',
      subtitulo: 'Fluxo único para criar clínica, admin responsável, plano e assinatura.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O SuperAdmin cria apenas a clínica e o admin responsável. '
            'Depois, o admin da clínica cria enfermeiras, gestantes e equipe interna.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => superAdminCriarClinicaComAdminDialog(
              context: context,
            ),
            icon: const Icon(Icons.add_business),
            label: const Text('Criar clínica + admin SaaS'),
          ),
        ],
      ),
    );
  }
}
