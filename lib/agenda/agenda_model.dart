import 'package:cloud_firestore/cloud_firestore.dart';

import '../pacientes/paciente_identidade.dart';

class AgendaEvento {
  final String id;
  final String titulo;
  final String tipo;
  final String gestanteId;
  final String gestanteUid;
  final String gestanteNome;
  final String enfermeiraId;
  final String enfermeiraNome;
  final String data;
  final String horaInicio;
  final String horaFim;
  final String local;
  final String observacoes;
  final String status;
  final DateTime? dataHoraInicio;
  final DateTime? dataHoraFim;

  const AgendaEvento({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.gestanteId,
    this.gestanteUid = '',
    required this.gestanteNome,
    required this.enfermeiraId,
    required this.enfermeiraNome,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.local,
    required this.observacoes,
    required this.status,
    required this.dataHoraInicio,
    required this.dataHoraFim,
  });

  factory AgendaEvento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dados = doc.data() ?? <String, dynamic>{};

    DateTime? lerTimestamp(dynamic valor) {
      if (valor is Timestamp) return valor.toDate();
      if (valor is DateTime) return valor;
      if (valor is String && valor.trim().isNotEmpty) {
        return DateTime.tryParse(valor.trim());
      }
      return null;
    }

    String texto(dynamic valor) => (valor ?? '').toString();

    return AgendaEvento(
      id: doc.id,
      titulo: texto(dados['titulo']),
      tipo: texto(dados['tipo']).isEmpty ? 'Outro' : texto(dados['tipo']),
      gestanteId: pacienteIdDoRegistro(dados),
      gestanteUid: pacienteUidDoRegistro(dados),
      gestanteNome: texto(dados['gestanteNome']),
      enfermeiraId: texto(dados['enfermeiraId']),
      enfermeiraNome: texto(dados['enfermeiraNome']),
      data: texto(dados['data']),
      horaInicio: texto(dados['horaInicio']),
      horaFim: texto(dados['horaFim']),
      local: texto(dados['local']),
      observacoes: texto(dados['observacoes']),
      status: texto(dados['status']).isEmpty
          ? 'Agendado'
          : texto(dados['status']),
      dataHoraInicio: lerTimestamp(dados['dataHoraInicio']),
      dataHoraFim: lerTimestamp(dados['dataHoraFim']),
    );
  }

  Map<String, dynamic> toFirestore({
    required String usuarioUid,
    bool incluirCriador = false,
  }) {
    final inicio = montarDataHora(data, horaInicio);
    final fim = montarDataHora(data, horaFim);

    final dados = identidadePacienteCanonica(
      <String, dynamic>{
        'titulo': titulo.trim(),
        'tipo': tipo.trim(),
        'gestanteNome': gestanteNome.trim(),
        'enfermeiraId': enfermeiraId.trim(),
        'enfermeiraNome': enfermeiraNome.trim(),
        'data': data.trim(),
        'horaInicio': horaInicio.trim(),
        'horaFim': horaFim.trim(),
        'local': local.trim(),
        'observacoes': observacoes.trim(),
        'status': status.trim(),
        'dataHoraInicio': inicio == null ? null : Timestamp.fromDate(inicio),
        'dataHoraFim': fim == null ? null : Timestamp.fromDate(fim),
        'atualizadoPorUid': usuarioUid,
        'atualizadoEm': FieldValue.serverTimestamp(),
      },
      pacienteId: gestanteId,
      pacienteUid: gestanteUid,
    );

    if (incluirCriador) {
      dados['criadoPorUid'] = usuarioUid;
    }

    return dados;
  }

  static DateTime? montarDataHora(String dataIso, String hora) {
    final data = DateTime.tryParse(dataIso.trim());
    if (data == null) return null;

    final partes = hora.trim().split(':');
    if (partes.length < 2) return data;

    final h = int.tryParse(partes[0]) ?? 0;
    final m = int.tryParse(partes[1]) ?? 0;

    return DateTime(data.year, data.month, data.day, h, m);
  }

  AgendaEvento copyWith({
    String? id,
    String? titulo,
    String? tipo,
    String? gestanteId,
    String? gestanteUid,
    String? gestanteNome,
    String? enfermeiraId,
    String? enfermeiraNome,
    String? data,
    String? horaInicio,
    String? horaFim,
    String? local,
    String? observacoes,
    String? status,
    DateTime? dataHoraInicio,
    DateTime? dataHoraFim,
  }) {
    return AgendaEvento(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      tipo: tipo ?? this.tipo,
      gestanteId: gestanteId ?? this.gestanteId,
      gestanteUid: gestanteUid ?? this.gestanteUid,
      gestanteNome: gestanteNome ?? this.gestanteNome,
      enfermeiraId: enfermeiraId ?? this.enfermeiraId,
      enfermeiraNome: enfermeiraNome ?? this.enfermeiraNome,
      data: data ?? this.data,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFim: horaFim ?? this.horaFim,
      local: local ?? this.local,
      observacoes: observacoes ?? this.observacoes,
      status: status ?? this.status,
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      dataHoraFim: dataHoraFim ?? this.dataHoraFim,
    );
  }
}
