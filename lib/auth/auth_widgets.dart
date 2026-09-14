import 'package:flutter/material.dart';

Widget authCampoLogin({
  required TextEditingController controller,
  required String label,
  bool obscure = false,
  TextInputAction? textInputAction,
  VoidCallback? onSubmitted,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: (_) {
        if (onSubmitted != null) {
          onSubmitted();
        }
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

Widget authBotaoPrincipal({
  required String texto,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

String normalizarPerfilUsuario(String? perfil) {
  final valor = (perfil ?? '').trim();

  if (valor.isEmpty) {
    return 'gestante';
  }

  if (valor == 'superadmin') {
    return 'superAdmin';
  }

  if (valor == 'admin') {
    return 'admin';
  }

  if (valor == 'enfermeira') {
    return 'enfermeira';
  }

  if (valor == 'obstetra') {
    return 'obstetra';
  }

  if (valor == 'gestante') {
    return 'gestante';
  }

  return valor;
}

bool perfilEhAdminOuSuperior(String? perfil) {
  final normalizado = normalizarPerfilUsuario(perfil);
  return normalizado == 'admin' || normalizado == 'superAdmin';
}
