import 'package:cloud_firestore/cloud_firestore.dart';
import 'agenda_model.dart';

class AgendaService {
  AgendaService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _colecao =>
      _firestore.collection('agenda');

  Stream<List<AgendaEvento>> ouvirEventos() {
    return _colecao.orderBy('dataHoraInicio').snapshots().map((snapshot) {
      return snapshot.docs.map(AgendaEvento.fromFirestore).toList();
    });
  }

  Stream<List<AgendaEvento>> ouvirEventosDoPeriodo(DateTime inicio, DateTime fim) {
    final inicioSeguro = DateTime(inicio.year, inicio.month, inicio.day);
    final fimSeguro = DateTime(fim.year, fim.month, fim.day, 23, 59, 59);

    return _colecao
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

  Stream<List<AgendaEvento>> ouvirEventosDaGestante(String gestanteId) {
    final idSeguro = gestanteId.trim();

    if (idSeguro.isEmpty) {
      return Stream<List<AgendaEvento>>.value([]);
    }

    return _colecao
        .where('gestanteId', isEqualTo: idSeguro)
        .snapshots()
        .map((snapshot) {
      final eventos = snapshot.docs.map(AgendaEvento.fromFirestore).toList();
      eventos.sort(_compararEventosPorData);
      return eventos;
    });
  }

  int _compararEventosPorData(AgendaEvento a, AgendaEvento b) {
    final dataA = a.dataHoraInicio ?? DateTime.tryParse(a.data) ?? DateTime(2100);
    final dataB = b.dataHoraInicio ?? DateTime.tryParse(b.data) ?? DateTime(2100);
    return dataA.compareTo(dataB);
  }

  Future<void> criarEvento(
    AgendaEvento evento, {
    required String usuarioUid,
  }) async {
    final dados = evento.toFirestore(usuarioUid: usuarioUid);
    dados['criadoEm'] = FieldValue.serverTimestamp();

    await _colecao.add(dados);
  }

  Future<void> atualizarEvento(
    AgendaEvento evento, {
    required String usuarioUid,
  }) async {
    await _colecao.doc(evento.id).update(
      evento.toFirestore(usuarioUid: usuarioUid),
    );
  }

  Future<void> excluirEvento(String id) async {
    await _colecao.doc(id).delete();
  }
}
