import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/firebase_globals.dart';
import '../saas/tenant_access_scope.dart';
import '../services/tenant_firestore_service.dart';
import '../shared/natus_app.dart';

class NatusPainelNotificacoesFlutuante extends StatelessWidget {
  final String tipoUsuario;
  final String uidUsuario;
  final TenantAccessScope escopoTenant;

  const NatusPainelNotificacoesFlutuante({
    super.key,
    required this.tipoUsuario,
    required this.uidUsuario,
    required this.escopoTenant,
  });

  String get tipoConsulta {
    if (tipoUsuario == 'superAdmin') {
      return 'admin';
    }

    return tipoUsuario;
  }

  Future<void> marcarComoLida(String idNotificacao) async {
    if (uidUsuario.trim().isEmpty) return;

    await firestore.collection('notificacoesCentral').doc(idNotificacao).set({
      'lidasPor': FieldValue.arrayUnion(<String>[uidUsuario]),
      'atualizadoEm': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> marcarTodasComoLidas(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (uidUsuario.trim().isEmpty || docs.isEmpty) return;

    final batch = firestore.batch();

    for (final doc in docs) {
      final dados = doc.data();
      final lidasPor = ((dados['lidasPor'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList();

      if (lidasPor.contains(uidUsuario)) {
        continue;
      }

      batch.set(doc.reference, {
        'lidasPor': FieldValue.arrayUnion(<String>[uidUsuario]),
        'atualizadoEm': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  IconData iconePorTipo(String tipo) {
    switch (tipo) {
      case 'alerta_contracao':
        return Icons.notifications_active_rounded;
      case 'novo_exame':
        return Icons.biotech_rounded;
      case 'contrato':
        return Icons.description_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color corPorTipo(String tipo) {
    switch (tipo) {
      case 'alerta_contracao':
        return const Color(0xFFC25B5B);
      case 'novo_exame':
        return const Color(0xFF5B7FC2);
      case 'contrato':
        return const Color(0xFF6A8C63);
      default:
        return NatusApp.vinho;
    }
  }

  String formatarDataHoraNotificacao(dynamic valor, dynamic valorIso) {
    if (valor is Timestamp) {
      return _formatarData(valor.toDate());
    }

    final texto = (valorIso ?? valor ?? '').toString().trim();
    final data = DateTime.tryParse(texto);

    if (data == null) {
      return 'Agora';
    }

    return _formatarData(data);
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes às $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final tenantFirestore = TenantFirestoreService(
      firestore: firestore,
      escopo: escopoTenant,
    );
    final stream = tenantFirestore
        .consultaClinica('notificacoesCentral')
        .where('destinatariosTipos', arrayContains: tipoConsulta)
        .orderBy('criadoEm', descending: true)
        .limit(20)
        .snapshots();

    return Container(
      width: 420,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            spreadRadius: -10,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: NatusApp.vinho.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: -14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _estruturaBase(
                  cabecalho: _cabecalho(0, const []),
                  conteudo: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erro ao carregar notificações.',
                        style: TextStyle(color: NatusApp.textoSuave),
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? const [];
              final naoLidas = docs.where((doc) {
                final dados = doc.data();
                final lidasPor = ((dados['lidasPor'] as List?) ?? const [])
                    .map((item) => item.toString())
                    .toList();
                return !lidasPor.contains(uidUsuario);
              }).length;

              return _estruturaBase(
                cabecalho: _cabecalho(naoLidas, docs),
                conteudo: docs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhuma notificação por aqui.',
                            style: TextStyle(color: NatusApp.textoSuave),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        children: docs.map((doc) {
                          final dados = doc.data();
                          final tipo = (dados['tipo'] ?? '').toString().trim();
                          final titulo = (dados['titulo'] ?? 'Notificação')
                              .toString()
                              .trim();
                          final mensagem = (dados['mensagem'] ?? '')
                              .toString()
                              .trim();
                          final gestante = (dados['gestante'] ?? '')
                              .toString()
                              .trim();
                          final intensidade = (dados['intensidade'] ?? '')
                              .toString()
                              .trim();
                          final duracao = (dados['duracao'] ?? '')
                              .toString()
                              .trim();
                          final lidasPor =
                              ((dados['lidasPor'] as List?) ?? const [])
                                  .map((item) => item.toString())
                                  .toList();
                          final lida = lidasPor.contains(uidUsuario);
                          final cor = corPorTipo(tipo);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: lida
                                    ? NatusApp.rose.withValues(alpha: 0.24)
                                    : cor.withValues(alpha: 0.34),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: cor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        iconePorTipo(tipo),
                                        color: cor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            titulo,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: NatusApp.vinho,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            mensagem,
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.35,
                                              color: NatusApp.texto,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _chipMeta(
                                      Icons.schedule_rounded,
                                      formatarDataHoraNotificacao(
                                        dados['criadoEm'],
                                        dados['criadoEmIso'],
                                      ),
                                    ),
                                    if (gestante.isNotEmpty)
                                      _chipMeta(Icons.person_rounded, gestante),
                                    if (intensidade.isNotEmpty)
                                      _chipMeta(
                                        Icons.favorite_rounded,
                                        intensidade,
                                      ),
                                    if (duracao.isNotEmpty)
                                      _chipMeta(Icons.timer_outlined, duracao),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: lida
                                            ? NatusApp.rose.withValues(
                                                alpha: 0.14,
                                              )
                                            : cor.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        lida ? 'Lida' : 'Nova',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: lida ? NatusApp.vinho : cor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!lida)
                                      TextButton(
                                        onPressed: () => marcarComoLida(doc.id),
                                        child: const Text('Marcar como lida'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _estruturaBase({required Widget cabecalho, required Widget conteudo}) {
    return Column(
      children: [
        cabecalho,
        Expanded(child: conteudo),
      ],
    );
  }

  Widget _cabecalho(
    int naoLidas,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        border: Border(
          bottom: BorderSide(color: NatusApp.rose.withValues(alpha: 0.28)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificações',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.vinho,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  naoLidas == 0
                      ? 'Tudo em dia por aqui.'
                      : '$naoLidas pendência(s) para revisar.',
                  style: TextStyle(fontSize: 12.5, color: NatusApp.textoSuave),
                ),
              ],
            ),
          ),
          if (docs.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => marcarTodasComoLidas(docs),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: NatusApp.rose.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Ler tudo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NatusApp.vinho,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipMeta(IconData icone, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 15, color: NatusApp.vinho),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: NatusApp.texto,
            ),
          ),
        ],
      ),
    );
  }
}
