import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario_model.dart';
import 'base_repository.dart';

class UsuariosRepository extends BaseRepository {
  const UsuariosRepository({required super.firestore});

  CollectionReference<Map<String, dynamic>> get colecao {
    return firestore.collection('usuarios');
  }

  Future<UsuarioModel?> buscarPorUid(String uid) async {
    final doc = await colecao.doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UsuarioModel.fromMap(doc.data()!);
  }
}
