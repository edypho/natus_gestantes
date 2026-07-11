import 'package:flutter/material.dart';

Widget uploadAreaPremium({
  required String titulo,
  required VoidCallback onUpload,
}) {
  return InkWell(
    onTap: onUpload,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_rounded,
            size: 54,
          ),
          const SizedBox(height: 14),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Clique para selecionar um arquivo',
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    ),
  );
}
