import 'package:cloud_firestore/cloud_firestore.dart';

import 'clinica_saas.dart';

class ClinicasService {
  final FirebaseFirestore firestore;

  ClinicasService({
    required this.firestore,
  });

  CollectionReference<Map<String, dynamic>> get colecao {
    return firestore.collection('clinicasSaaS');
  }

  Future<void> salvarClinica(ClinicaSaaS clinica) async {
    await colecao.doc(clinica.id).set(
          clinica.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<ClinicaSaaS?> buscarClinica(String id) async {
    final doc = await colecao.doc(id).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return ClinicaSaaS.fromMap(doc.data()!);
  }
}
