import 'package:flutter/material.dart';

import 'super_admin_stats.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard SaaS',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B3A44),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Painel administrativo da plataforma Natus SaaS',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 28),
          const SuperAdminStatsGrid(),
        ],
      ),
    );
  }
}
