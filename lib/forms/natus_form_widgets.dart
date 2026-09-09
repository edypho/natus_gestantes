import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget campoNatus(
  TextEditingController controller,
  String label, {
  dynamic mask,
  TextInputType? keyboardType,
  bool enabled = true,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: mask == null ? null : <TextInputFormatter>[mask],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
