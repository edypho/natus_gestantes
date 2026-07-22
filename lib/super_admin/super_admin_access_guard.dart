import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/usuario_tipos.dart';

class SuperAdminAccessGuard {
  static const Set<String> _perfisClinicaPermitidos = {
    'admin',
    'enfermeira',
    'obstetra',
    'profissional',
    'gestante',
  };

  static bool statusClinicaPermiteAcesso(String? status) {
    final statusNormalizado = status?.trim().toLowerCase() ?? '';
    return statusNormalizado == 'ativa' || statusNormalizado == 'teste';
  }

  static bool statusUsuarioPermiteAcesso(String? status) {
    return status?.trim().toLowerCase() == 'ativo';
  }

  static bool clinicaCorrespondeAoTenant(
    Map<String, dynamic> clinica,
    String tenantId,
  ) {
    final tenantNormalizado = tenantId.trim();
    return tenantNormalizado.isNotEmpty &&
        _tenantId(clinica) == tenantNormalizado;
  }

  static Future<bool> usuarioPodeAcessar({
    required String uid,
    bool? superAdminVerificado,
  }) async {
    final uidNormalizado = uid.trim();
    if (uidNormalizado.isEmpty) {
      return false;
    }

    try {
      final usuarioDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidNormalizado)
          .get();
      final usuario = usuarioDoc.data();

      if (usuario == null ||
          !statusUsuarioPermiteAcesso(usuario['status']?.toString())) {
        return false;
      }

      final perfil = _perfilNormalizado(usuario);
      if (perfil == null) {
        return false;
      }

      if (perfil == 'superAdmin') {
        if (superAdminVerificado != null) {
          return superAdminVerificado;
        }

        final usuarioAuth = FirebaseAuth.instance.currentUser;
        if (usuarioAuth == null || usuarioAuth.uid != uidNormalizado) {
          return false;
        }

        final token = await usuarioAuth.getIdTokenResult(true);
        return token.claims?['superAdmin'] == true;
      }

      final tenantId = _tenantId(usuario);
      if (tenantId.isEmpty) {
        return false;
      }

      final clinicas = await Future.wait([
        FirebaseFirestore.instance.collection('clinicas').doc(tenantId).get(),
        FirebaseFirestore.instance
            .collection('clinicasSaaS')
            .doc(tenantId)
            .get(),
      ]);
      final clinica = clinicas.first.exists
          ? clinicas.first.data()
          : clinicas.last.data();

      if (clinica == null) {
        return false;
      }

      return clinicaCorrespondeAoTenant(clinica, tenantId) &&
          statusClinicaPermiteAcesso(clinica['status']?.toString());
    } catch (_) {
      return false;
    }
  }

  static String? _perfilNormalizado(Map<String, dynamic> usuario) {
    final tipo = usuario['tipo']?.toString().trim() ?? '';
    final tipoUsuario = usuario['tipoUsuario']?.toString().trim() ?? '';

    if (tipo.isEmpty && tipoUsuario.isEmpty) {
      return null;
    }

    final perfilTipo = tipo.isEmpty ? '' : normalizarTipoUsuarioNatus(tipo);
    final perfilTipoUsuario = tipoUsuario.isEmpty
        ? ''
        : normalizarTipoUsuarioNatus(tipoUsuario);

    if (perfilTipo.isNotEmpty &&
        perfilTipoUsuario.isNotEmpty &&
        perfilTipo != perfilTipoUsuario) {
      return null;
    }

    final perfil = perfilTipo.isNotEmpty ? perfilTipo : perfilTipoUsuario;
    if (perfil == 'superAdmin' || _perfisClinicaPermitidos.contains(perfil)) {
      return perfil;
    }

    return null;
  }

  static String _tenantId(Map<String, dynamic> usuario) {
    final adminDonoId = usuario['adminDonoId']?.toString().trim() ?? '';
    final clinicaId = usuario['clinicaId']?.toString().trim() ?? '';

    if (adminDonoId.isNotEmpty &&
        clinicaId.isNotEmpty &&
        adminDonoId != clinicaId) {
      return '';
    }

    if (adminDonoId.isNotEmpty) {
      return adminDonoId;
    }

    return clinicaId;
  }

  static const String mensagemAcessoBloqueado =
      'Acesso temporariamente indisponível. Entre em contato com a administração.';
}
