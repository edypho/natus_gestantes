import 'package:cloud_firestore/cloud_firestore.dart';

import '../saas/tenant_access_scope.dart';

class TenantFirestoreService {
  const TenantFirestoreService({
    required FirebaseFirestore firestore,
    required TenantAccessScope escopo,
  }) : _firestore = firestore,
       _escopo = escopo;

  final FirebaseFirestore _firestore;
  final TenantAccessScope _escopo;

  TenantAccessScope get escopo => _escopo;

  Query<Map<String, dynamic>> consultaClinica(String colecao) {
    final referencia = _firestore.collection(colecao);
    if (_escopo.acessoGlobal) return referencia;

    return referencia
        .where('adminDonoId', isEqualTo: _escopo.clinicaId)
        .where('clinicaId', isEqualTo: _escopo.clinicaId);
  }

  Query<Map<String, dynamic>> consultaDoPaciente(
    String colecao, {
    required String campoUid,
  }) {
    if (!_escopo.ehPaciente) return consultaClinica(colecao);

    return _firestore
        .collection(colecao)
        .where('adminDonoId', isEqualTo: _escopo.clinicaId)
        .where('clinicaId', isEqualTo: _escopo.clinicaId)
        .where(campoUid, isEqualTo: _escopo.uidUsuario);
  }

  Query<Map<String, dynamic>> consultaRegistrosDoPaciente(
    String colecao, {
    required String pacienteId,
    String campoId = 'idGestante',
    String campoUid = 'uidGestante',
  }) {
    if (_escopo.ehPaciente) {
      final id = pacienteId.trim();
      if (id.isNotEmpty && id != _escopo.pacienteId) {
        throw const TenantScopeException(
          'Cadastro de paciente fora do contexto autenticado.',
        );
      }
      return consultaDoPaciente(colecao, campoUid: campoUid);
    }

    final id = pacienteId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(pacienteId, 'pacienteId', 'ID vazio.');
    }

    return consultaClinica(colecao).where(campoId, isEqualTo: id);
  }

  Map<String, dynamic> prepararCriacao(Map<String, dynamic> dados) {
    return _escopo.aplicarEmDados({
      ...dados,
      'criadoPorUid': _escopo.uidUsuario,
    });
  }

  Map<String, String> prepararCriacaoTexto(Map<String, String> dados) {
    return _escopo.aplicarEmTextos({
      ...dados,
      'criadoPorUid': _escopo.uidUsuario,
    });
  }

  Map<String, dynamic> prepararAtualizacao(Map<String, dynamic> dados) {
    return <String, dynamic>{
      ..._escopo.protegerAtualizacao(dados),
      'atualizadoPorUid': _escopo.uidUsuario,
    };
  }

  Map<String, String> prepararAtualizacaoTexto(Map<String, String> dados) {
    return <String, String>{
      ..._escopo.protegerAtualizacaoTexto(dados),
      'atualizadoPorUid': _escopo.uidUsuario,
    };
  }

  String caminhoStorage(String caminhoRelativo) {
    return _escopo.caminhoStorage(caminhoRelativo);
  }
}
