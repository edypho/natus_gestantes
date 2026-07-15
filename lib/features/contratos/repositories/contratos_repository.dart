import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase_globals.dart';
import '../models/contrato_registro.dart';

class ContratosRepository {
  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('contratos');

  Future<String> criarSolicitacao({
    required String pacienteId,
    required String templateKey,
    required Map<String, dynamic> payload,
  }) async {
    final agora = DateTime.now().toIso8601String();
    final doc = await _collection.add({
      'pacienteId': pacienteId,
      'templateKey': templateKey,
      'status': 'pendente',
      'zapsignDocumentId': '',
      'zapsignSignerUrl': '',
      'payload': payload,
      'criadoEm': agora,
      'atualizadoEm': agora,
    });

    return doc.id;
  }

  Future<void> atualizarStatus({
    required String contratoId,
    required String status,
    String? zapsignDocumentId,
    String? zapsignSignerUrl,
    String? erro,
  }) async {
    await _collection.doc(contratoId).update({
      'status': status,
      'zapsignDocumentId': zapsignDocumentId ?? '',
      'zapsignSignerUrl': zapsignSignerUrl ?? '',
      'erro': erro ?? '',
      'atualizadoEm': DateTime.now().toIso8601String(),
    });
  }

  Future<ContratoRegistro?> buscarPorId(String contratoId) async {
    final doc = await _collection.doc(contratoId).get();
    if (!doc.exists) {
      return null;
    }

    return ContratoRegistro.fromMap({'id': doc.id, ...doc.data()!});
  }
}
