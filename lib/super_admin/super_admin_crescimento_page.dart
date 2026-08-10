import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';

class SuperAdminCrescimentoPage extends StatelessWidget {
  const SuperAdminCrescimentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminPageScaffold(
      titulo: 'Crescimento de usuários por período SaaS',
      subtitulo: 'Análise de crescimento da plataforma por período.',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuariosSaaS')
            .snapshots(),
        builder: (context, snapshot) {
          final total = snapshot.data?.docs.length ?? 0;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              '$total usuários SaaS cadastrados',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7B3A44),
              ),
            ),
          );
        },
      ),
    );
  }
}
