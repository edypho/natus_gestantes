import 'package:cloud_firestore/cloud_firestore.dart';

class SuperAdminFirestoreActions {
  final FirebaseFirestore firestore;

  SuperAdminFirestoreActions({required this.firestore});

  Future<void> criarClinicaBase({
    required String nome,
    required String emailAdmin,
    required String plano,
  }) async {
    await firestore.collection('clinicasSaaS').add({
      'nome': nome,
      'emailAdmin': emailAdmin,
      'plano': plano,
      'status': 'teste',
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> registrarAcaoSuperAdmin({
    required String acao,
    Map<String, dynamic>? dados,
  }) async {
    await firestore.collection('logsSuperAdmin').add({
      'acao': acao,
      'dados': dados ?? {},
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }
}
