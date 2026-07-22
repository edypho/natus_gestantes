import '../core/firebase_globals.dart';
import '../saas/tenant_access_scope.dart';
import '../services/tenant_firestore_service.dart';

/// Fonte de dados do Natus — buscas no Firestore isoladas da UI.
///
/// Extraído do main.dart no Lote 2e. Cada função busca e mapeia os dados;
/// quem chama decide o que fazer com a lista (setState, cache etc.).
/// Isso permite testar a UI sem Firestore e reutilizar as buscas em
/// outros módulos (relatórios, app da gestante).

TenantFirestoreService _tenant(TenantAccessScope escopo) {
  return TenantFirestoreService(firestore: firestore, escopo: escopo);
}

Future<List<Map<String, String>>> buscarContracoes(
  TenantAccessScope escopo,
) async {
  final service = _tenant(escopo);
  final resultado = await service
      .consultaDoPaciente('contracoes', campoUid: 'uidGestante')
      .get();

  return resultado.docs.map((doc) {
    final dados = doc.data();

    return dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });
  }).toList();
}

Future<List<Map<String, dynamic>>> buscarPlanos(
  TenantAccessScope escopo,
) async {
  final resultado = await _tenant(escopo).consultaClinica('planos').get();

  final lista = resultado.docs.map((doc) {
    final dados = doc.data();
    return {'id': doc.id, ...dados};
  }).toList();

  lista.sort(
    (a, b) => (a['nomePlano'] ?? '').toString().compareTo(
      (b['nomePlano'] ?? '').toString(),
    ),
  );

  return lista;
}

Future<List<Map<String, String>>> buscarEnfermeiras(
  TenantAccessScope escopo,
) async {
  final resultado = await _tenant(escopo).consultaClinica('enfermeiras').get();

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

Future<List<Map<String, String>>> buscarObstetras(
  TenantAccessScope escopo,
) async {
  final resultado = await _tenant(escopo).consultaClinica('obstetras').get();

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

Future<List<Map<String, String>>> buscarBiblioteca(
  TenantAccessScope escopo,
) async {
  final resultado = await _tenant(escopo).consultaClinica('biblioteca').get();

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

Future<List<Map<String, String>>> buscarAtendimentos(
  TenantAccessScope escopo,
) async {
  if (escopo.ehPaciente) return const <Map<String, String>>[];

  final resultado = await _tenant(escopo).consultaClinica('atendimentos').get();

  return resultado.docs.map((doc) {
    final dados = doc.data();

    return dados.map((chave, valor) {
      return MapEntry(chave, valor.toString());
    });
  }).toList();
}

Future<List<Map<String, String>>> buscarGestantes(
  TenantAccessScope escopo,
) async {
  final resultado = await _tenant(
    escopo,
  ).consultaDoPaciente('gestantes', campoUid: 'uidGestante').get();

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
