import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_layout.dart';

class SuperAdminFirestoreList extends StatelessWidget {
  const SuperAdminFirestoreList({
    super.key,
    required this.collection,
    required this.emptyText,
    required this.itemBuilder,
  });

  final String collection;
  final String emptyText;
  final Widget Function(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  )
  itemBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('criadoEm', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SuperAdminStateMessage(
            mensagem: 'Não foi possível carregar os dados agora.',
            icone: Icons.cloud_off_rounded,
            erro: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return SuperAdminStateMessage(mensagem: emptyText);
        }

        return Column(
          children: docs.map((doc) => itemBuilder(context, doc)).toList(),
        );
      },
    );
  }
}

Widget superAdminListTile({
  required String titulo,
  required String subtitulo,
  required IconData icone,
  Widget? trailing,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final compacto = constraints.maxWidth < 760;
      final conteudo = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: superAdminVinho.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: superAdminVinho, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitulo,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(compacto ? 14 : 17),
        decoration: BoxDecoration(
          color: superAdminFundoCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: superAdminVinho.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: superAdminVinho.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: compacto
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  conteudo,
                  if (trailing != null) ...[
                    const SizedBox(height: 14),
                    Divider(color: superAdminVinho.withValues(alpha: 0.08)),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: trailing),
                  ],
                ],
              )
            : Row(
                children: [
                  Expanded(child: conteudo),
                  if (trailing != null) ...[
                    const SizedBox(width: 20),
                    Flexible(child: trailing),
                  ],
                ],
              ),
      );
    },
  );
}
