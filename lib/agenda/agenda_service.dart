import 'package:cloud_firestore/cloud_firestore.dart';

import '../saas/tenant_access_scope.dart';
import '../services/tenant_firestore_service.dart';
import 'agenda_model.dart';

class AgendaService {
  AgendaService({
    FirebaseFirestore? firestore,
    required TenantAccessScope escopo,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _escopo = escopo;

  final FirebaseFirestore _firestore;
  final TenantAccessScope _escopo;

  CollectionReference<Map<String, dynamic>> get _colecao =>
      _firestore.collection('agenda');

  TenantFirestoreService get _tenant {
    return TenantFirestoreService(firestore: _firestore, escopo: _escopo);
  }

  Stream<List<AgendaEvento>> ouvirEventos() {
    return _tenant
        .consultaClinica('agenda')
        .orderBy('dataHoraInicio')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(AgendaEvento.fromFirestore).toList();
        });
  }

  Stream<List<AgendaEvento>> ouvirEventosDoPeriodo(
    DateTime inicio,
    DateTime fim,
  ) {
    final inicioSeguro = DateTime(inicio.year, inicio.month, inicio.day);
    final fimSeguro = DateTime(fim.year, fim.month, fim.day, 23, 59, 59);

    return _tenant
        .consultaClinica('agenda')
        .where(
          'dataHoraInicio',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicioSeguro),
        )
        .where(
          'dataHoraInicio',
          isLessThanOrEqualTo: Timestamp.fromDate(fimSeguro),
        )
        .orderBy('dataHoraInicio')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(AgendaEvento.fromFirestore).toList();
        });
  }

  Stream<List<AgendaEvento>> ouvirEventosDaPaciente() {
    final idSeguro = _escopo.pacienteId;
    final uidSeguro = _escopo.uidUsuario;

    if (!_escopo.ehPaciente || idSeguro.isEmpty || uidSeguro.isEmpty) {
      return Stream<List<AgendaEvento>>.value([]);
    }

    return _colecao
        .where('adminDonoId', isEqualTo: _escopo.clinicaId)
        .where('clinicaId', isEqualTo: _escopo.clinicaId)
        .where('gestanteUid', isEqualTo: uidSeguro)
        .snapshots()
        .map((snapshot) {
          final eventos = snapshot.docs
              .map(AgendaEvento.fromFirestore)
              .where((evento) => evento.gestanteId == idSeguro)
              .toList();
          eventos.sort(_compararEventosPorData);
          return eventos;
        });
  }

  int _compararEventosPorData(AgendaEvento a, AgendaEvento b) {
    final dataA =
        a.dataHoraInicio ?? DateTime.tryParse(a.data) ?? DateTime(2100);
    final dataB =
        b.dataHoraInicio ?? DateTime.tryParse(b.data) ?? DateTime(2100);
    return dataA.compareTo(dataB);
  }

  Future<void> criarEvento(
    AgendaEvento evento, {
    required String usuarioUid,
  }) async {
    final dados = evento.toFirestore(
      usuarioUid: usuarioUid,
      incluirCriador: true,
    );
    dados['criadoEm'] = FieldValue.serverTimestamp();

    await _colecao.add(_tenant.prepararCriacao(dados));
  }

  Future<void> atualizarEvento(
    AgendaEvento evento, {
    required String usuarioUid,
  }) async {
    await _colecao
        .doc(evento.id)
        .update(
          _tenant.prepararAtualizacao(
            evento.toFirestore(usuarioUid: usuarioUid),
          ),
        );
  }

  Future<void> excluirEvento(String id) async {
    await _colecao.doc(id).delete();
  }
}
