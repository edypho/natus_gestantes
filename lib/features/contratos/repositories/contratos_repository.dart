import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../pacientes/paciente_identidade.dart';
import '../../../saas/tenant_access_scope.dart';
import '../../../services/tenant_firestore_service.dart';
import '../models/contrato_registro.dart';

class ContratosRepository {
  ContratosRepository({
    required TenantAccessScope escopo,
    FirebaseFirestore? firestore,
  }) : _escopo = escopo,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final TenantAccessScope _escopo;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('contratos');

  TenantFirestoreService get _tenant =>
      TenantFirestoreService(firestore: _firestore, escopo: _escopo);

  void _exigirAcessoOperacional() {
    if (_escopo.acessoGlobal) {
      throw const TenantScopeException(
        'Super Admin não acessa contratos clínicos diretamente.',
      );
    }
  }

  void _exigirEscritaAdministrativa() {
    _exigirAcessoOperacional();
    if (_escopo.perfil != 'admin') {
      throw const TenantScopeException(
        'Somente o administrador da clínica pode alterar contratos.',
      );
    }
  }

  void _validarRegistro(Map<String, dynamic> dados) {
    _exigirAcessoOperacional();
    if (!_escopo.pertenceAoTenant(dados)) {
      throw const TenantScopeException('Contrato fora da clínica atual.');
    }

    if (_escopo.ehPaciente) {
      if (!registroPertenceAoPaciente(
        dados,
        pacienteId: _escopo.pacienteId,
        pacienteUid: _escopo.uidUsuario,
      )) {
        throw const TenantScopeException('Contrato de outro paciente.');
      }
    }
  }

  Future<String> criarSolicitacao({
    required String pacienteId,
    required String templateKey,
    required Map<String, dynamic> payload,
  }) async {
    _exigirEscritaAdministrativa();
    final agora = DateTime.now().toIso8601String();
    final pacienteUid = _escopo.ehPaciente
        ? _escopo.uidUsuario
        : pacienteUidDoRegistro(payload);
    final payloadCanonico = identidadePacienteCanonica(
      payload,
      pacienteId: pacienteId,
      pacienteUid: pacienteUid,
    );
    final doc = await _collection.add(
      _tenant.prepararCriacao(
        identidadePacienteCanonica(
          {
            'templateKey': templateKey,
            'status': 'pendente',
            'zapsignDocumentId': '',
            'zapsignSignerUrl': '',
            'payload': payloadCanonico,
            'criadoEm': agora,
            'atualizadoEm': agora,
          },
          pacienteId: pacienteId,
          pacienteUid: pacienteUid,
        ),
      ),
    );

    return doc.id;
  }

  Future<void> atualizarStatus({
    required String contratoId,
    required String status,
    String? zapsignDocumentId,
    String? zapsignSignerUrl,
    String? erro,
  }) async {
    _exigirEscritaAdministrativa();
    final atual = await _collection.doc(contratoId).get();
    if (!atual.exists) {
      throw StateError('Contrato não encontrado.');
    }
    _validarRegistro(atual.data()!);

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

    _validarRegistro(doc.data()!);

    return ContratoRegistro.fromMap({'id': doc.id, ...doc.data()!});
  }
}
