import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/natus_breakpoints.dart';
import '../seguranca/log_seguro.dart';
import '../shared/natus_app.dart';
import '../saas/tenant_access_scope.dart';
import 'agenda_model.dart';
import 'agenda_service.dart';

class AgendaPage extends StatefulWidget {
  final List<Map<String, String>> gestantes;
  final List<Map<String, String>> enfermeiras;
  final String tipoUsuario;
  final TenantAccessScope escopoTenant;

  const AgendaPage({
    super.key,
    required this.gestantes,
    required this.enfermeiras,
    required this.tipoUsuario,
    required this.escopoTenant,
  });

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late final AgendaService _service;
  final TextEditingController _buscaController = TextEditingController();

  DateTime _mesExibido = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _dataSelecionada = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  String _filtroStatus = 'Todos';
  String _filtroTipo = 'Todos';
  String _filtroEnfermeira = 'Todas';

  static const List<String> tiposEvento = [
    'Consulta',
    'Visita domiciliar',
    'Plantão',
    'Acompanhamento de parto',
    'Retorno pós-parto',
    'Reunião',
    'DPP / Previsão de parto',
    'Outro',
  ];

  static const List<String> statusEvento = [
    'Agendado',
    'Concluído',
    'Cancelado',
  ];

  @override
  void initState() {
    super.initState();
    _service = AgendaService(escopo: widget.escopoTenant);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  bool get _usuarioGestante => widget.tipoUsuario == 'gestante';
  bool get _usuarioAdmin => widget.tipoUsuario == 'admin';

  bool get _usuarioAdminOuEnfermeira =>
      widget.tipoUsuario == 'admin' ||
      widget.tipoUsuario == 'enfermeira' ||
      widget.tipoUsuario == 'obstetra' ||
      widget.tipoUsuario == 'profissional';

  @override
  Widget build(BuildContext context) {
    if (!_usuarioAdminOuEnfermeira && !_usuarioGestante) {
      return _telaSemPermissao();
    }

    if (_usuarioGestante && _idGestante(_gestanteLogada()).isEmpty) {
      return _telaGestanteNaoIdentificada();
    }

    return StreamBuilder<List<AgendaEvento>>(
      stream: _streamEventosAgenda(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _erroAgenda(snapshot.error.toString());
        }

        final carregando =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final eventos = snapshot.data ?? [];
        final eventosFiltrados = _filtrarEventos(eventos);
        final dppsFiltradas = _dppsFiltradas();
        final eventosDoDia = eventosFiltrados.where((evento) {
          final data = _dataDoEvento(evento);
          return data != null && _mesmoDia(data, _dataSelecionada);
        }).toList();

        final dppsDoDia = dppsFiltradas.where((gestante) {
          final dpp = _dppDaGestante(gestante);
          return dpp != null && _mesmoDia(dpp, _dataSelecionada);
        }).toList();

        final padding = NatusBreakpoints.usarLayoutCompacto(context)
            ? 12.0
            : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cabecalhoAgenda(),
              if (carregando) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 3),
              ],
              const SizedBox(height: 20),
              _filtrosAgenda(),
              const SizedBox(height: 20),
              _calendario(eventosFiltrados, dppsFiltradas),
              const SizedBox(height: 20),
              _listaDoDia(eventosDoDia, dppsDoDia),
            ],
          ),
        );
      },
    );
  }

  Widget _telaSemPermissao() {
    return Center(
      child: Text(
        'Agenda indisponível para este perfil.',
        style: TextStyle(fontSize: 18, color: NatusApp.vinho),
      ),
    );
  }

  Widget _telaGestanteNaoIdentificada() {
    return Center(
      child: Text(
        'Não foi possível identificar seu cadastro de paciente para exibir a agenda.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: NatusApp.vinho,
        ),
      ),
    );
  }

  Widget _erroAgenda(String erro) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: NatusApp.rose.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: NatusApp.vinho, size: 38),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar a agenda.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: NatusApp.vinho,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              erro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalhoAgenda() {
    final subtitulo = _usuarioGestante
        ? 'Acompanhe seus compromissos, retornos e atendimentos cadastrados pela equipe Natus.'
        : 'Organize consultas, visitas, retornos, reuniões e demais compromissos da equipe.';
    final compacto = NatusBreakpoints.usarLayoutCompacto(context);

    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _usuarioGestante ? 'Minha agenda' : 'Agenda Natus',
          style: TextStyle(
            fontSize: compacto ? 24 : 30,
            fontWeight: FontWeight.bold,
            color: NatusApp.vinho,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitulo, style: const TextStyle(color: Colors.black54)),
      ],
    );

    final botaoNovo = !_usuarioGestante
        ? ElevatedButton.icon(
            onPressed: () => _abrirDialogEvento(),
            icon: const Icon(Icons.add),
            label: const Text('Novo compromisso'),
          )
        : null;

    if (compacto) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          textos,
          if (botaoNovo != null) ...[const SizedBox(height: 14), botaoNovo],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: textos),
        if (botaoNovo != null) ...[const SizedBox(width: 16), botaoNovo],
      ],
    );
  }

  Widget _filtrosAgenda() {
    final nomesEnfermeiras =
        widget.enfermeiras
            .map((e) => (e['nome'] ?? '').trim())
            .where((nome) => nome.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final compacto = NatusBreakpoints.usarLayoutCompacto(context);
    final larguraCampoBusca = compacto ? double.infinity : 320.0;
    final larguraStatus = compacto ? double.infinity : 190.0;
    final larguraTipo = compacto ? double.infinity : 230.0;
    final larguraEnfermeira = compacto ? double.infinity : 230.0;

    return Container(
      padding: EdgeInsets.all(compacto ? 12 : 16),
      decoration: BoxDecoration(
        color: NatusApp.offWhite.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: larguraCampoBusca,
            child: TextField(
              controller: _buscaController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar na agenda',
              ),
            ),
          ),
          _dropdownFiltro(
            largura: larguraStatus,
            label: 'Status',
            valor: _filtroStatus,
            itens: ['Todos', ...statusEvento],
            onChanged: (valor) => setState(() => _filtroStatus = valor),
          ),
          _dropdownFiltro(
            largura: larguraTipo,
            label: 'Tipo',
            valor: _filtroTipo,
            itens: ['Todos', ...tiposEvento],
            onChanged: (valor) => setState(() => _filtroTipo = valor),
          ),
          if (!_usuarioGestante)
            _dropdownFiltro(
              largura: larguraEnfermeira,
              label: 'Profissional',
              valor: _filtroEnfermeira,
              itens: ['Todas', ...nomesEnfermeiras],
              onChanged: (valor) => setState(() => _filtroEnfermeira = valor),
            ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _buscaController.clear();
                _filtroStatus = 'Todos';
                _filtroTipo = 'Todos';
                _filtroEnfermeira = 'Todas';
              });
            },
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Limpar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _dropdownFiltro({
    required double largura,
    required String label,
    required String valor,
    required List<String> itens,
    required ValueChanged<String> onChanged,
  }) {
    final itensUnicos = itens.toSet().toList();
    final valorSeguro = itensUnicos.contains(valor) ? valor : itensUnicos.first;

    return SizedBox(
      width: largura,
      child: DropdownButtonFormField<String>(
        initialValue: valorSeguro,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: itensUnicos
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
      ),
    );
  }

  Widget _calendario(
    List<AgendaEvento> eventosFiltrados,
    List<Map<String, String>> dppsFiltradas,
  ) {
    final primeiroDia = DateTime(_mesExibido.year, _mesExibido.month, 1);
    final diasNoMes = DateTime(_mesExibido.year, _mesExibido.month + 1, 0).day;
    final espacosAntes = primeiroDia.weekday - 1;
    final totalCelulas = espacosAntes + diasNoMes;
    final compacto = NatusBreakpoints.usarLayoutCompacto(context);

    return Container(
      padding: EdgeInsets.all(compacto ? 10 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinho.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: () => setState(() {
                  _mesExibido = DateTime(
                    _mesExibido.year,
                    _mesExibido.month - 1,
                  );
                  _dataSelecionada = DateTime(
                    _mesExibido.year,
                    _mesExibido.month,
                    1,
                  );
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_nomeMes(_mesExibido.month)} de ${_mesExibido.year}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.vinho,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: () => setState(() {
                  _mesExibido = DateTime(
                    _mesExibido.year,
                    _mesExibido.month + 1,
                  );
                  _dataSelecionada = DateTime(
                    _mesExibido.year,
                    _mesExibido.month,
                    1,
                  );
                }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
                .map(
                  (dia) => Expanded(
                    child: Center(
                      child: Text(
                        dia,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: NatusApp.textoSuave,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCelulas,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: compacto ? 5 : 8,
              crossAxisSpacing: compacto ? 5 : 8,
              childAspectRatio: compacto ? 0.86 : 1.18,
            ),
            itemBuilder: (context, index) {
              if (index < espacosAntes) return const SizedBox.shrink();

              final dia = index - espacosAntes + 1;
              final data = DateTime(_mesExibido.year, _mesExibido.month, dia);
              final selecionado = _mesmoDia(data, _dataSelecionada);
              final hoje = _mesmoDia(data, DateTime.now());
              final quantidade = _contarItensDoDia(
                data,
                eventosFiltrados,
                dppsFiltradas,
              );

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _dataSelecionada = data),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.all(compacto ? 5 : 8),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? NatusApp.vinho
                        : hoje
                        ? NatusApp.rose.withValues(alpha: 0.18)
                        : NatusApp.creme.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selecionado
                          ? NatusApp.vinho
                          : NatusApp.rose.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dia',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selecionado ? Colors.white : NatusApp.texto,
                        ),
                      ),
                      const Spacer(),
                      if (quantidade > 0)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: selecionado
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : NatusApp.marsala.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$quantidade',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: selecionado
                                    ? Colors.white
                                    : NatusApp.vinho,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _listaDoDia(
    List<AgendaEvento> eventos,
    List<Map<String, String>> dpps,
  ) {
    final dataFormatada = _formatarDataBr(_dataSelecionada);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NatusApp.offWhite.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compromissos de $dataFormatada',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.vinho,
                  ),
                ),
              ),
              if (!_usuarioGestante)
                TextButton.icon(
                  onPressed: () =>
                      _abrirDialogEvento(dataInicial: _dataSelecionada),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar neste dia'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (eventos.isEmpty && dpps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nenhum compromisso para este dia.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ...dpps.map(_cardDpp),
          ...eventos.map(_cardEvento),
        ],
      ),
    );
  }

  Widget _cardEvento(AgendaEvento evento) {
    final cor = _corStatus(evento.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cor.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(_iconeTipo(evento.tipo), color: cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      evento.titulo.isEmpty ? evento.tipo : evento.titulo,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: NatusApp.texto,
                      ),
                    ),
                    _chip(evento.status, cor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${evento.horaInicio} às ${evento.horaFim} • ${evento.tipo}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: NatusApp.vinho,
                  ),
                ),
                if (evento.gestanteNome.trim().isNotEmpty)
                  Text('Paciente: ${evento.gestanteNome}'),
                if (evento.enfermeiraNome.trim().isNotEmpty)
                  Text('Profissional: ${evento.enfermeiraNome}'),
                if (evento.local.trim().isNotEmpty)
                  Text('Local: ${evento.local}'),
                if (evento.observacoes.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    evento.observacoes,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          if (!_usuarioGestante)
            PopupMenuButton<String>(
              onSelected: (acao) {
                if (acao == 'editar') {
                  _abrirDialogEvento(evento: evento);
                }
                if (acao == 'excluir') {
                  _confirmarExclusao(evento);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                if (_usuarioAdmin)
                  const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cardDpp(Map<String, String> gestante) {
    final nome = gestante['nomeGestante'] ?? 'Paciente sem nome';
    final telefone = gestante['telefoneGestante'] ?? '';
    final hospital = gestante['hospitalGestante'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NatusApp.rose.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: NatusApp.vinho.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.child_friendly_rounded, color: NatusApp.vinho),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'DPP prevista • $nome',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: NatusApp.texto,
                      ),
                    ),
                    _chip('DPP', NatusApp.vinho),
                  ],
                ),
                if (telefone.isNotEmpty) Text('Telefone: $telefone'),
                if (hospital.isNotEmpty) Text('Hospital: $hospital'),
                const SizedBox(height: 4),
                const Text(
                  'Evento automático gerado pela DPP do módulo obstétrico do prontuário da paciente.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cor),
      ),
    );
  }

  Future<void> _abrirDialogEvento({
    AgendaEvento? evento,
    DateTime? dataInicial,
  }) async {
    if (_usuarioGestante) {
      _mensagem('A agenda do paciente é somente para visualização.');
      return;
    }

    final editando = evento != null;
    final tituloController = TextEditingController(text: evento?.titulo ?? '');
    final localController = TextEditingController(text: evento?.local ?? '');
    final observacoesController = TextEditingController(
      text: evento?.observacoes ?? '',
    );

    DateTime dataSelecionada = evento == null
        ? (dataInicial ?? _dataSelecionada)
        : (_dataDoEvento(evento) ?? _dataSelecionada);

    String tipo = tiposEvento.contains(evento?.tipo)
        ? evento!.tipo
        : 'Consulta';
    String status = statusEvento.contains(evento?.status)
        ? evento!.status
        : 'Agendado';
    String horaInicio = evento?.horaInicio.trim().isNotEmpty == true
        ? evento!.horaInicio
        : '08:00';
    String horaFim = evento?.horaFim.trim().isNotEmpty == true
        ? evento!.horaFim
        : '09:00';

    final gestantesDisponiveis = _gestantesDisponiveisParaAgenda();
    final pacienteDoEventoId = (evento?.gestanteId ?? '').trim();
    if (editando &&
        pacienteDoEventoId.isNotEmpty &&
        !gestantesDisponiveis.any(
          (gestante) => _idGestante(gestante) == pacienteDoEventoId,
        )) {
      final pacienteCadastrada = widget.gestantes.firstWhere(
        (gestante) => _idGestante(gestante) == pacienteDoEventoId,
        orElse: () => <String, String>{},
      );
      gestantesDisponiveis.add(
        pacienteCadastrada.isNotEmpty
            ? pacienteCadastrada
            : <String, String>{
                'id': pacienteDoEventoId,
                'uidGestante': evento.gestanteUid,
                'nomeGestante': evento.gestanteNome.isEmpty
                    ? 'Paciente vinculada'
                    : evento.gestanteNome,
              },
      );
    }
    final enfermeirasDisponiveis = widget.enfermeiras
        .where((e) => (e['nome'] ?? '').trim().isNotEmpty)
        .toList();

    String gestanteSelecionadaId = evento?.gestanteId ?? '';
    String enfermeiraSelecionadaId = evento?.enfermeiraId ?? '';

    if (gestanteSelecionadaId.isEmpty && gestantesDisponiveis.isNotEmpty) {
      gestanteSelecionadaId = _idGestante(gestantesDisponiveis.first);
    }

    if (enfermeiraSelecionadaId.isEmpty && enfermeirasDisponiveis.isNotEmpty) {
      enfermeiraSelecionadaId = _idEnfermeira(enfermeirasDisponiveis.first);
    }

    await showDialog(
      context: context,
      builder: (contextDialog) {
        return StatefulBuilder(
          builder: (contextDialog, setStateDialog) {
            return AlertDialog(
              title: Text(editando ? 'Editar compromisso' : 'Novo compromisso'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: tituloController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: tipo,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                              ),
                              items: tiposEvento
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setStateDialog(() => tipo = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                              ),
                              items: statusEvento
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setStateDialog(() => status = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _valorDropdownSeguro(
                          gestanteSelecionadaId,
                          gestantesDisponiveis.map(_idGestante).toList(),
                        ),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Paciente vinculado',
                        ),
                        items: gestantesDisponiveis.map((g) {
                          final id = _idGestante(g);
                          final nome = g['nomeGestante'] ?? 'Paciente sem nome';
                          return DropdownMenuItem(value: id, child: Text(nome));
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setStateDialog(() => gestanteSelecionadaId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _valorDropdownSeguro(
                          enfermeiraSelecionadaId,
                          enfermeirasDisponiveis.map(_idEnfermeira).toList(),
                        ),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Profissional responsável',
                        ),
                        items: enfermeirasDisponiveis.map((e) {
                          final id = _idEnfermeira(e);
                          final nome = e['nome'] ?? 'Profissional';
                          return DropdownMenuItem(value: id, child: Text(nome));
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setStateDialog(() => enfermeiraSelecionadaId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final escolhida = await showDatePicker(
                                  context: contextDialog,
                                  initialDate: dataSelecionada,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );

                                if (escolhida == null) return;
                                setStateDialog(
                                  () => dataSelecionada = escolhida,
                                );
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_formatarDataBr(dataSelecionada)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final horario = await _selecionarHora(
                                  contextDialog,
                                  horaInicio,
                                );
                                if (horario == null) return;
                                setStateDialog(() => horaInicio = horario);
                              },
                              icon: const Icon(Icons.schedule),
                              label: Text('Início: $horaInicio'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final horario = await _selecionarHora(
                                  contextDialog,
                                  horaFim,
                                );
                                if (horario == null) return;
                                setStateDialog(() => horaFim = horario);
                              },
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text('Fim: $horaFim'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: localController,
                        decoration: const InputDecoration(labelText: 'Local'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: observacoesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(contextDialog),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final titulo = tituloController.text.trim();
                    if (titulo.isEmpty) {
                      _mensagem('Informe o título do compromisso.');
                      return;
                    }

                    final gestante = gestantesDisponiveis.firstWhere(
                      (g) => _idGestante(g) == gestanteSelecionadaId,
                      orElse: () => {},
                    );
                    final enfermeira = enfermeirasDisponiveis.firstWhere(
                      (e) => _idEnfermeira(e) == enfermeiraSelecionadaId,
                      orElse: () => {},
                    );
                    final gestanteUid =
                        (gestante['uidGestante'] ?? '').trim().isNotEmpty
                        ? (gestante['uidGestante'] ?? '').trim()
                        : evento?.gestanteUid ?? '';
                    final gestanteNome =
                        (gestante['nomeGestante'] ?? '').trim().isNotEmpty
                        ? (gestante['nomeGestante'] ?? '').trim()
                        : evento?.gestanteNome ?? '';

                    final eventoSalvar = AgendaEvento(
                      id: evento?.id ?? '',
                      titulo: titulo,
                      tipo: tipo,
                      gestanteId: gestanteSelecionadaId,
                      gestanteUid: gestanteUid,
                      gestanteNome: gestanteNome,
                      enfermeiraId: enfermeiraSelecionadaId,
                      enfermeiraNome: enfermeira['nome'] ?? '',
                      data: _formatarDataIso(dataSelecionada),
                      horaInicio: horaInicio,
                      horaFim: horaFim,
                      local: localController.text.trim(),
                      observacoes: observacoesController.text.trim(),
                      status: status,
                      dataHoraInicio: AgendaEvento.montarDataHora(
                        _formatarDataIso(dataSelecionada),
                        horaInicio,
                      ),
                      dataHoraFim: AgendaEvento.montarDataHora(
                        _formatarDataIso(dataSelecionada),
                        horaFim,
                      ),
                    );

                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      if (editando) {
                        await _service.atualizarEvento(
                          eventoSalvar,
                          usuarioUid: uid,
                        );
                      } else {
                        await _service.criarEvento(
                          eventoSalvar,
                          usuarioUid: uid,
                        );
                      }

                      if (!mounted || !contextDialog.mounted) return;
                      Navigator.pop(contextDialog);
                      _mensagem(
                        editando
                            ? 'Compromisso atualizado.'
                            : 'Compromisso criado.',
                      );
                    } catch (e) {
                      logErroSeguro('Erro ao salvar compromisso.', e);
                      _mensagem('Não foi possível salvar o compromisso.');
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    tituloController.dispose();
    localController.dispose();
    observacoesController.dispose();
  }

  Future<String?> _selecionarHora(
    BuildContext context,
    String valorAtual,
  ) async {
    final partes = valorAtual.split(':');
    final hora = int.tryParse(partes.first) ?? 8;
    final minuto = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;

    final escolhido = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hora, minute: minuto),
    );

    if (escolhido == null) return null;

    return '${escolhido.hour.toString().padLeft(2, '0')}:${escolhido.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmarExclusao(AgendaEvento evento) async {
    if (!_usuarioAdmin) {
      _mensagem('Somente o administrador pode excluir compromissos.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          title: const Text('Excluir compromisso'),
          content: Text(
            'Deseja excluir "${evento.titulo.isEmpty ? evento.tipo : evento.titulo}" da agenda?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialog, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(contextDialog, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await _service.excluirEvento(evento.id);
      _mensagem('Compromisso excluído.');
    } catch (e) {
      logErroSeguro('Erro ao excluir compromisso.', e);
      _mensagem('Não foi possível excluir o compromisso.');
    }
  }

  Stream<List<AgendaEvento>> _streamEventosAgenda() {
    final inicioMes = DateTime(_mesExibido.year, _mesExibido.month, 1);
    final fimMes = DateTime(_mesExibido.year, _mesExibido.month + 1, 0);

    // Margem pequena para não perder eventos próximos quando o calendário vira
    // o mês no mobile, mas sem carregar a coleção inteira da agenda.
    final inicioBusca = inicioMes.subtract(const Duration(days: 7));
    final fimBusca = fimMes.add(const Duration(days: 7));

    if (!_usuarioGestante) {
      return _service.ouvirEventosDoPeriodo(inicioBusca, fimBusca);
    }

    // A identidade da paciente vem do escopo autenticado, não de um valor
    // livre recebido pela interface.
    return _service.ouvirEventosDaPaciente();
  }

  Map<String, String> _gestanteLogada() {
    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

    return widget.gestantes.firstWhere(
      (g) => (g['uidGestante'] ?? '').trim() == uidLogado,
      orElse: () => {},
    );
  }

  bool _gestanteEhALogada(Map<String, String> gestante) {
    if (!_usuarioGestante) return true;

    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';
    final uidGestante = (gestante['uidGestante'] ?? '').trim();

    if (uidLogado.isNotEmpty && uidGestante == uidLogado) {
      return true;
    }

    final idLogado = _idGestante(_gestanteLogada());
    final idGestante = _idGestante(gestante);

    return idLogado.isNotEmpty && idGestante == idLogado;
  }

  bool _eventoPertenceGestanteLogada(AgendaEvento evento) {
    if (!_usuarioGestante) return true;

    final idLogado = _idGestante(_gestanteLogada());
    final eventoGestanteId = evento.gestanteId.trim();

    if (idLogado.isNotEmpty && eventoGestanteId == idLogado) {
      return true;
    }

    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';
    return uidLogado.isNotEmpty && eventoGestanteId == uidLogado;
  }

  List<AgendaEvento> _filtrarEventos(List<AgendaEvento> eventos) {
    final busca = _normalizar(_buscaController.text);

    return eventos.where((evento) {
      if (_usuarioGestante && !_eventoPertenceGestanteLogada(evento)) {
        return false;
      }

      if (_filtroStatus != 'Todos' && evento.status != _filtroStatus) {
        return false;
      }

      if (_filtroTipo != 'Todos' && evento.tipo != _filtroTipo) {
        return false;
      }

      if (_filtroEnfermeira != 'Todas' &&
          evento.enfermeiraNome != _filtroEnfermeira) {
        return false;
      }

      if (busca.isEmpty) return true;

      final texto = _normalizar(
        [
          evento.titulo,
          evento.tipo,
          evento.gestanteNome,
          evento.enfermeiraNome,
          evento.local,
          evento.observacoes,
          evento.status,
        ].join(' '),
      );

      return texto.contains(busca);
    }).toList();
  }

  int _contarItensDoDia(
    DateTime data,
    List<AgendaEvento> eventos,
    List<Map<String, String>> dppsFiltradas,
  ) {
    final eventosDoDia = eventos.where((evento) {
      final dataEvento = _dataDoEvento(evento);
      return dataEvento != null && _mesmoDia(dataEvento, data);
    }).length;

    final dpps = dppsFiltradas.where((gestante) {
      final dpp = _dppDaGestante(gestante);
      return dpp != null && _mesmoDia(dpp, data);
    }).length;

    return eventosDoDia + dpps;
  }

  List<Map<String, String>> _dppsFiltradas() {
    final busca = _normalizar(_buscaController.text);

    return widget.gestantes.where((g) {
      if (_usuarioGestante && !_gestanteEhALogada(g)) return false;
      if (_filtroStatus != 'Todos') return false;
      if (_filtroEnfermeira != 'Todas') return false;
      if (_filtroTipo != 'Todos' && _filtroTipo != 'DPP / Previsão de parto') {
        return false;
      }
      if (!_gestanteAtivaOuPuerpera(g)) return false;

      final dpp = _dppDaGestante(g);
      if (dpp == null) return false;

      // A agenda exibe somente o mês aberto no calendário. Isso reduz bastante
      // trabalho de renderização em celular.
      if (dpp.year != _mesExibido.year || dpp.month != _mesExibido.month) {
        return false;
      }

      if (busca.isEmpty) return true;

      final texto = _normalizar(
        [
          'DPP',
          g['nomeGestante'],
          g['telefoneGestante'],
          g['hospitalGestante'],
          g['obstetraGestante'],
        ].join(' '),
      );

      return texto.contains(busca);
    }).toList();
  }

  DateTime? _dppDaGestante(Map<String, String> gestante) {
    return _converterDataGestante(gestante['dpp'] ?? gestante['DPP'] ?? '');
  }

  List<Map<String, String>> _gestantesDisponiveisParaAgenda() {
    return widget.gestantes.where(_gestanteAtivaOuPuerpera).toList()
      ..sort((a, b) {
        final nomeA = (a['nomeGestante'] ?? '').toLowerCase();
        final nomeB = (b['nomeGestante'] ?? '').toLowerCase();
        return nomeA.compareTo(nomeB);
      });
  }

  bool _gestanteAtivaOuPuerpera(Map<String, String> g) {
    final historico = (g['historico'] ?? '').trim().toLowerCase();
    if (historico == 'true' || historico == 'sim' || historico == '1') {
      return false;
    }

    final status = _normalizar(g['statusGestante'] ?? 'Gestante');

    if (status.contains('encerrada') || status.contains('encerrado')) {
      return false;
    }

    if (status.contains('historico') || status.contains('histórico')) {
      return false;
    }

    return status.contains('gestante') ||
        status == 'ativa' ||
        status == 'ativo' ||
        status.contains('puerpera') ||
        status.contains('puérpera');
  }

  DateTime? _dataDoEvento(AgendaEvento evento) {
    return evento.dataHoraInicio ?? DateTime.tryParse(evento.data);
  }

  DateTime? _converterDataGestante(String valor) {
    final texto = valor.trim();
    if (texto.isEmpty) return null;

    final iso = DateTime.tryParse(texto);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final partes = texto.split('/');
    if (partes.length == 3) {
      final dia = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final ano = int.tryParse(partes[2]);

      if (dia != null && mes != null && ano != null) {
        return DateTime(ano, mes, dia);
      }
    }

    return null;
  }

  bool _mesmoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatarDataIso(DateTime data) {
    return '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
  }

  String _formatarDataBr(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String _nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    if (mes < 1 || mes > 12) return '';
    return meses[mes - 1];
  }

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  String _idGestante(Map<String, String> g) {
    final id = (g['id'] ?? '').trim();
    if (id.isNotEmpty) return id;

    final uid = (g['uidGestante'] ?? '').trim();
    if (uid.isNotEmpty) return uid;

    return (g['nomeGestante'] ?? '').trim();
  }

  String _idEnfermeira(Map<String, String> e) {
    final id = (e['id'] ?? '').trim();
    if (id.isNotEmpty) return id;

    final uid = (e['uidEnfermeira'] ?? '').trim();
    if (uid.isNotEmpty) return uid;

    return (e['nome'] ?? '').trim();
  }

  String? _valorDropdownSeguro(String valor, List<String> opcoes) {
    if (opcoes.isEmpty) return null;
    if (opcoes.contains(valor)) return valor;
    return opcoes.first;
  }

  IconData _iconeTipo(String tipo) {
    switch (tipo) {
      case 'Consulta':
        return Icons.medical_services_rounded;
      case 'Visita domiciliar':
        return Icons.home_work_rounded;
      case 'Plantão':
        return Icons.health_and_safety_rounded;
      case 'Acompanhamento de parto':
        return Icons.child_care_rounded;
      case 'Retorno pós-parto':
        return Icons.volunteer_activism_rounded;
      case 'Reunião':
        return Icons.groups_rounded;
      case 'DPP / Previsão de parto':
        return Icons.child_friendly_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'Concluído':
        return Colors.green;
      case 'Cancelado':
        return Colors.red;
      default:
        return NatusApp.vinho;
    }
  }

  void _mensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}
