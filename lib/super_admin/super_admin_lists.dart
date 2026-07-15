import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SuperAdminFirestoreList extends StatelessWidget {
  final String collection;
  final String emptyText;
  final Widget Function(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  )
  itemBuilder;

  const SuperAdminFirestoreList({
    super.key,
    required this.collection,
    required this.emptyText,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('criadoEm', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(emptyText),
          );
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
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icone, color: const Color(0xFF7B3A44)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitulo),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
