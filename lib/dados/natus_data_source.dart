import '../core/firebase_globals.dart';

/// Fonte de dados do Natus — buscas no Firestore isoladas da UI.
///
/// Extraído do main.dart no Lote 2e. Cada função busca e mapeia os dados;
/// quem chama decide o que fazer com a lista (setState, cache etc.).
/// Isso permite testar a UI sem Firestore e reutilizar as buscas em
/// outros módulos (relatórios, app da gestante).

Future<List<Map<String, String>>> buscarContracoes() async {
  final resultado = await firestore.collection('contracoes').get();

  return resultado.docs.map((doc) {
    final dados = doc.data();

    return dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });
  }).toList();
}

Future<List<Map<String, dynamic>>> buscarPlanos() async {
  final resultado = await firestore
      .collection('planos')
      .orderBy('nomePlano')
      .get();

  return resultado.docs.map((doc) {
    final dados = doc.data();
    return {'id': doc.id, ...dados};
  }).toList();
}

Future<List<Map<String, String>>> buscarEnfermeiras() async {
  final resultado = await firestore.collection('enfermeiras').get();

  return resultado.docs.map((doc) {
    final dados = doc.data();

    final mapa = dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });

    mapa['id'] = doc.id;
    mapa['uidEnfermeira'] = dados['uidEnfermeira'] ?? '';

    return mapa;
  }).toList();
}

Future<List<Map<String, String>>> buscarObstetras() async {
  final resultado = await firestore.collection('obstetras').get();

  return resultado.docs.map((doc) {
    final dados = doc.data();

    final mapa = dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });

    mapa['id'] = doc.id;
    mapa['uidObstetra'] = dados['uidObstetra'] ?? '';

    return mapa;
  }).toList();
}

Future<List<Map<String, String>>> buscarBiblioteca() async {
  final resultado = await firestore.collection('biblioteca').get();

  final lista = resultado.docs.map((doc) {
    final dados = doc.data();

    final mapa = dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });

    mapa['id'] = doc.id;
    return mapa;
  }).toList();

  lista.sort((a, b) {
    final ordemA = int.tryParse(a['ordem'] ?? '0') ?? 0;
    final ordemB = int.tryParse(b['ordem'] ?? '0') ?? 0;

    return ordemA.compareTo(ordemB);
  });

  return lista;
}

Future<List<Map<String, String>>> buscarAtendimentos() async {
  final resultado = await firestore.collection('atendimentos').get();

  return resultado.docs.map((doc) {
    final dados = doc.data();

    return dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });
  }).toList();
}

Future<List<Map<String, String>>> buscarGestantes() async {
  final resultado = await firestore.collection('gestantes').get();

  return resultado.docs.map((doc) {
    final dados = doc.data();

    final mapa = dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });

    mapa['id'] = doc.id;
    mapa['uidGestante'] = dados['uidGestante'] ?? '';

    return mapa;
  }).toList();
}
