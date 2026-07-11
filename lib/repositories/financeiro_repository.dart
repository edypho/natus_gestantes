import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parcela_model.dart';
import 'base_repository.dart';

class FinanceiroRepository extends BaseRepository {
  const FinanceiroRepository({
    required super.firestore,
  });

  CollectionReference<Map<String, dynamic>> get colecao {
    return firestore.collection('parcelasFinanceiras');
  }

  Future<List<ParcelaModel>> listarPorAdmin(String adminDonoId) async {
    final snapshot = await colecao
        .where('adminDonoId', isEqualTo: adminDonoId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return ParcelaModel.fromMap(data);
    }).toList();
  }
}
