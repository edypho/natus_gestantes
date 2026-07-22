import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuperAdminRepository {
  final FirebaseFirestore firestore;

  SuperAdminRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

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

  Future<void> _validarUsuarioSaaSMutavel(String usuarioId) async {
    final uid = usuarioId.trim();
    if (uid.isEmpty) {
      throw ArgumentError('Usuário não identificado.');
    }
    if (FirebaseAuth.instance.currentUser?.uid == uid) {
      throw StateError('Você não pode alterar o próprio acesso Super Admin.');
    }

    final documentos = await Future.wait([
      usuariosApp.doc(uid).get(),
      usuariosSaaS.doc(uid).get(),
    ]);
    final dados = documentos.first.data() ?? documentos.last.data();
    if (dados == null) {
      throw StateError('Usuário não encontrado.');
    }

    String perfil(dynamic valor) =>
        (valor ?? '').toString().trim().replaceAll('_', '').toLowerCase();
    final tipo = perfil(dados['tipo']);
    final tipoUsuario = perfil(dados['tipoUsuario']);
    if (tipo == 'superadmin' || tipoUsuario == 'superadmin') {
      throw StateError(
        'Contas Super Admin exigem um fluxo administrativo externo.',
      );
    }
  }

  Future<bool> criarClinicaComAdmin({
    required String nomeClinica,
    required String nomeAdmin,
    required String emailAdmin,
    required String plano,
    required double valorAssinatura,
  }) async {
    final emailNormalizado = emailAdmin.trim().toLowerCase();
    final callable = FirebaseFunctions.instance.httpsCallable(
      'criarClinicaComAdminSaaS',
    );
    final resposta = await callable.call({
      'nomeClinica': nomeClinica.trim(),
      'nomeAdmin': nomeAdmin.trim(),
      'emailAdmin': emailNormalizado,
      'plano': plano.trim(),
      'valorAssinatura': valorAssinatura,
    });
    final resultado = Map<String, dynamic>.from(resposta.data as Map);
    if (resultado['sucesso'] != true) {
      throw StateError('O servidor não confirmou a criação da clínica.');
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailNormalizado,
      );
      return true;
    } catch (_) {
      return false;
    }
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
      dados: {'assinaturaId': assinaturaId, 'status': status},
    );
  }

  Future<void> alterarStatusClinica({
    required String clinicaId,
    required String status,
  }) async {
    if (clinicaId.trim().isEmpty) {
      throw ArgumentError('Clínica não identificada.');
    }
    if (!const {
      'ativa',
      'teste',
      'pausada',
      'bloqueada',
      'excluida',
    }.contains(status)) {
      throw ArgumentError('Status de clínica inválido.');
    }

    final agora = FieldValue.serverTimestamp();

    final dados = <String, dynamic>{
      'clinicaId': clinicaId,
      'adminDonoId': clinicaId,
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

    if (status == 'excluida') {
      dados['excluidaEm'] = agora;
    }

    final legadoRef = clinicas.doc(clinicaId);
    final canonicoRef = firestore.collection('clinicas').doc(clinicaId);
    final resultados = await Future.wait([legadoRef.get(), canonicoRef.get()]);
    final dadosLegados = resultados.first.data() ?? <String, dynamic>{};
    final dadosCanonicos = resultados.last.exists
        ? dados
        : <String, dynamic>{...dadosLegados, 'id': clinicaId, ...dados};

    final batch = firestore.batch();
    batch.set(legadoRef, dados, SetOptions(merge: true));
    batch.set(canonicoRef, dadosCanonicos, SetOptions(merge: true));
    await batch.commit();

    await registrarLog(
      acao: 'alterar_status_clinica_saas',
      dados: {'clinicaId': clinicaId, 'status': status},
    );
  }

  Future<void> alterarStatusUsuarioSaaS({
    required String usuarioId,
    required String status,
  }) async {
    await _validarUsuarioSaaSMutavel(usuarioId);
    if (!const {'ativo', 'inativo', 'bloqueado'}.contains(status)) {
      throw ArgumentError('Status de usuário inválido.');
    }

    final agora = FieldValue.serverTimestamp();

    final dados = <String, dynamic>{'status': status, 'atualizadoEm': agora};

    if (status == 'bloqueado') {
      dados['bloqueadoEm'] = agora;
    }

    if (status == 'ativo') {
      dados['reativadoEm'] = agora;
      dados['excluidoLogicamente'] = false;
      dados['excluidoEm'] = FieldValue.delete();
    }

    await usuariosSaaS.doc(usuarioId).set(dados, SetOptions(merge: true));

    await usuariosApp.doc(usuarioId).set(dados, SetOptions(merge: true));

    await registrarLog(
      acao: 'alterar_status_usuario_saas',
      dados: {'usuarioId': usuarioId, 'status': status},
    );
  }

  Future<void> excluirClinicaLogicamente({required String clinicaId}) async {
    await alterarStatusClinica(clinicaId: clinicaId, status: 'excluida');

    await registrarLog(
      acao: 'excluir_clinica_saas_logicamente',
      dados: {'clinicaId': clinicaId},
    );
  }

  Future<void> excluirUsuarioSaaSLogicamente({
    required String usuarioId,
  }) async {
    await alterarStatusUsuarioSaaS(usuarioId: usuarioId, status: 'bloqueado');

    final dadosExclusao = <String, dynamic>{
      'excluidoLogicamente': true,
      'excluidoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
    final batch = firestore.batch();
    batch.set(
      usuariosSaaS.doc(usuarioId),
      dadosExclusao,
      SetOptions(merge: true),
    );
    batch.set(
      usuariosApp.doc(usuarioId),
      dadosExclusao,
      SetOptions(merge: true),
    );
    await batch.commit();

    await registrarLog(
      acao: 'excluir_usuario_saas_logicamente',
      dados: {'usuarioId': usuarioId},
    );
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
