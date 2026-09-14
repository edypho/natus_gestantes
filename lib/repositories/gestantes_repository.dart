import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gestante_model.dart';
import 'base_repository.dart';

class GestantesRepository extends BaseRepository {
  const GestantesRepository({required super.firestore});

  CollectionReference<Map<String, dynamic>> get colecao {
    return firestore.collection('gestantes');
  }

  Future<List<GestanteModel>> listarPorAdmin(String adminDonoId) async {
    final snapshot = await colecao
        .where('adminDonoId', isEqualTo: adminDonoId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return GestanteModel.fromMap(data);
    }).toList();
  }
}
