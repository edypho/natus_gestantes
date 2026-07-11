import 'package:cloud_firestore/cloud_firestore.dart';

class SuperAdminAccessGuard {
  static bool statusClinicaPermiteAcesso(String? status) {
    return status == 'ativa' || status == 'teste';
  }

  static bool statusUsuarioPermiteAcesso(String? status) {
    return status == 'ativo';
  }

  static Future<bool> usuarioPodeAcessar({
    required String uid,
  }) async {
    final usuarioDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    final usuario = usuarioDoc.data();

    if (usuario == null) {
      return false;
    }

    final statusUsuario = usuario['status']?.toString() ?? 'ativo';

    if (!statusUsuarioPermiteAcesso(statusUsuario)) {
      return false;
    }

    final adminDonoId = usuario['adminDonoId']?.toString() ?? '';

    if (adminDonoId.isEmpty) {
      return true;
    }

    final clinicaDoc = await FirebaseFirestore.instance
        .collection('clinicasSaaS')
        .doc(adminDonoId)
        .get();

    final clinica = clinicaDoc.data();

    if (clinica == null) {
      return true;
    }

    final statusClinica = clinica['status']?.toString() ?? 'ativa';

    return statusClinicaPermiteAcesso(statusClinica);
  }

  static const String mensagemAcessoBloqueado =
      'Acesso temporariamente indisponível. Entre em contato com a administração.';
}
