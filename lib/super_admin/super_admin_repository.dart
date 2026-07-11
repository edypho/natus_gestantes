import 'package:cloud_firestore/cloud_firestore.dart';

import 'super_admin_auth_config.dart';
import 'super_admin_auth_service.dart';

class SuperAdminRepository {
  final FirebaseFirestore firestore;

  SuperAdminRepository({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get clinicas {
    return firestore.collection('clinicasSaaS');
  }

  CollectionReference<Map<String, dynamic>> get usuariosSaaS {
    return firestore.collection('usuariosSaaS');
  }

  CollectionReference<Map<String, dynamic>> get usuariosApp {
    return firestore.collection('usuarios');
  }

  CollectionReference<Map<String, dynamic>> get assinaturas {
    return firestore.collection('assinaturasSaaS');
  }

  CollectionReference<Map<String, dynamic>> get logs {
    return firestore.collection('logsSuperAdmin');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamClinicas() {
    return clinicas.orderBy('criadoEm', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUsuarios() {
    return usuariosSaaS.orderBy('criadoEm', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAssinaturas() {
    return assinaturas.orderBy('criadoEm', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMensalidadesAtrasadas() {
    return assinaturas
        .where('status', whereIn: ['vencida', 'bloqueada'])
        .snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> criarClinicaComAdmin({
    required String nomeClinica,
    required String nomeAdmin,
    required String emailAdmin,
    required String plano,
    required double valorAssinatura,
    required String senhaTemporaria,
  }) async {
    final senhaSegura = senhaTemporaria.trim().isEmpty
        ? SuperAdminAuthConfig.senhaTemporariaPadrao
        : senhaTemporaria.trim();

    if (senhaSegura.length < SuperAdminAuthConfig.tamanhoMinimoSenha) {
      throw Exception(
        'A senha temporária precisa ter pelo menos '
        '${SuperAdminAuthConfig.tamanhoMinimoSenha} caracteres.',
      );
    }

    final authService = SuperAdminAuthService();

    final credencial = await authService.criarAdminClinicaAuth(
      email: emailAdmin,
      senhaTemporaria: senhaSegura,
    );

    final uidAuth = credencial.user?.uid ?? '';

    final batch = firestore.batch();

    final clinicaRef = clinicas.doc();
    final usuarioSaaSRef = usuariosSaaS.doc(uidAuth);
    final usuarioAppRef = usuariosApp.doc(uidAuth);
    final assinaturaRef = assinaturas.doc();
    final logRef = logs.doc();

    batch.set(clinicaRef, {
      'id': clinicaRef.id,
      'nome': nomeClinica,
      'emailAdmin': emailAdmin,
      'plano': plano,
      'status': 'teste',
      'adminDonoId': clinicaRef.id,
      'adminUid': uidAuth,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    final usuarioBase = {
      'id': uidAuth,
      'uid': uidAuth,
      'nome': nomeAdmin,
      'email': emailAdmin,
      'tipo': 'admin',
      'tipoUsuario': 'admin',
      'clinicaId': clinicaRef.id,
      'adminDonoId': clinicaRef.id,
      'status': 'ativo',
      'senhaTemporaria': senhaSegura,
      'primeiroLogin': SuperAdminAuthConfig.primeiroLoginObrigatorio,
      'authCriado': true,
      'criadoViaSuperAdmin': true,
      'criadoEm': FieldValue.serverTimestamp(),
    };

    batch.set(usuarioSaaSRef, usuarioBase);
    batch.set(usuarioAppRef, usuarioBase);

    batch.set(assinaturaRef, {
      'id': assinaturaRef.id,
      'clinicaId': clinicaRef.id,
      'clinicaNome': nomeClinica,
      'emailAdmin': emailAdmin,
      'plano': plano,
      'status': 'ativa',
      'valor': valorAssinatura,
      'vencimento': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'criadoEm': FieldValue.serverTimestamp(),
    });

    batch.set(logRef, {
      'acao': 'criar_clinica_com_admin_saas_auth_real',
      'dados': {
        'clinicaId': clinicaRef.id,
        'adminUid': uidAuth,
        'nomeClinica': nomeClinica,
        'nomeAdmin': nomeAdmin,
        'emailAdmin': emailAdmin,
        'plano': plano,
        'authCriado': true,
        'senhaTemporariaDefinida': true,
      },
      'criadoEm': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return clinicaRef;
  }

  Future<void> alterarStatusAssinatura({
    required String assinaturaId,
    required String status,
  }) async {
    await assinaturas.doc(assinaturaId).set({
      'status': status,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await registrarLog(
      acao: 'alterar_status_assinatura',
      dados: {
        'assinaturaId': assinaturaId,
        'status': status,
      },
    );
  }

  Future<void> alterarStatusClinica({
    required String clinicaId,
    required String status,
  }) async {
    final agora = FieldValue.serverTimestamp();

    final dados = <String, dynamic>{
      'status': status,
      'atualizadoEm': agora,
    };

    if (status == 'pausada') {
      dados['pausadaEm'] = agora;
    }

    if (status == 'bloqueada') {
      dados['bloqueadaEm'] = agora;
    }

    if (status == 'ativa') {
      dados['reativadaEm'] = agora;
    }

    await clinicas.doc(clinicaId).set(
          dados,
          SetOptions(merge: true),
        );

    await registrarLog(
      acao: 'alterar_status_clinica_saas',
      dados: {
        'clinicaId': clinicaId,
        'status': status,
      },
    );
  }

  Future<void> alterarStatusUsuarioSaaS({
    required String usuarioId,
    required String status,
  }) async {
    final agora = FieldValue.serverTimestamp();

    final dados = <String, dynamic>{
      'status': status,
      'atualizadoEm': agora,
    };

    if (status == 'bloqueado') {
      dados['bloqueadoEm'] = agora;
    }

    if (status == 'ativo') {
      dados['reativadoEm'] = agora;
    }

    await usuariosSaaS.doc(usuarioId).set(
          dados,
          SetOptions(merge: true),
        );

    await usuariosApp.doc(usuarioId).set(
          dados,
          SetOptions(merge: true),
        );

    await registrarLog(
      acao: 'alterar_status_usuario_saas',
      dados: {
        'usuarioId': usuarioId,
        'status': status,
      },
    );
  }

  Future<void> excluirClinicaLogicamente({
    required String clinicaId,
  }) async {
    final usuariosDaClinica = await usuariosSaaS
        .where('clinicaId', isEqualTo: clinicaId)
        .get();

    final usuariosAppDaClinica = await usuariosApp
        .where('clinicaId', isEqualTo: clinicaId)
        .get();

    final assinaturasDaClinica = await assinaturas
        .where('clinicaId', isEqualTo: clinicaId)
        .get();

    await registrarLog(
      acao: 'excluir_clinica_saas_fisicamente',
      dados: {
        'clinicaId': clinicaId,
        'usuariosSaaSExcluidos': usuariosDaClinica.docs.length,
        'usuariosAppExcluidos': usuariosAppDaClinica.docs.length,
        'assinaturasExcluidas': assinaturasDaClinica.docs.length,
      },
    );

    final batch = firestore.batch();

    for (final usuario in usuariosDaClinica.docs) {
      batch.delete(usuario.reference);
    }

    for (final usuario in usuariosAppDaClinica.docs) {
      batch.delete(usuario.reference);
    }

    for (final assinatura in assinaturasDaClinica.docs) {
      batch.delete(assinatura.reference);
    }

    batch.delete(clinicas.doc(clinicaId));

    await batch.commit();
  }

  Future<void> excluirUsuarioSaaSLogicamente({
    required String usuarioId,
  }) async {
    await registrarLog(
      acao: 'excluir_usuario_saas_fisicamente',
      dados: {
        'usuarioId': usuarioId,
      },
    );

    final batch = firestore.batch();

    batch.delete(usuariosSaaS.doc(usuarioId));
    batch.delete(usuariosApp.doc(usuarioId));

    await batch.commit();
  }

  Future<void> registrarLog({
    required String acao,
    Map<String, dynamic>? dados,
  }) async {
    await logs.add({
      'acao': acao,
      'dados': dados ?? {},
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }
}
