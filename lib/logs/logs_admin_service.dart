import 'package:cloud_firestore/cloud_firestore.dart';

class LogsAdminService {
  final FirebaseFirestore firestore;

  LogsAdminService({
    required this.firestore,
  });

  Future<void> registrarLog({
    required String acao,
    required String usuarioUid,
    required String usuarioEmail,
    String? adminDonoId,
    Map<String, dynamic>? dados,
  }) async {
    await firestore.collection('logsAdministrativos').add({
      'acao': acao,
      'usuarioUid': usuarioUid,
      'usuarioEmail': usuarioEmail,
      'adminDonoId': adminDonoId,
      'dados': dados ?? {},
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }
}
