import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared/natus_app.dart';
import 'shared/natus_logo.dart';
import 'shared/natus_premium_visual.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as excel;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'super_admin/super_admin_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'agenda/agenda_page.dart';
import 'core/firebase_globals.dart';
import 'financeiro/financeiro_calculos.dart' as fincalc;
import 'gestantes/gestantes_regras.dart' as gregras;
import 'gestantes/maternidades_regras.dart' as mregras;
import 'kpis/kpis_calculos.dart' as kpis;
import 'dashboard/dashboard_cards_natus.dart';
import 'dashboard/dashboard_destino_filtros.dart';
import 'dados/natus_data_source.dart' as dados;
import 'gestantes/card_gestante_lista.dart';
import 'financeiro/parcela_item.dart';
import 'auth/tela_login.dart';

export 'core/firebase_globals.dart';
export 'core/usuario_tipos.dart';
export 'auth/tela_login.dart';
import 'core/usuario_tipos.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const NatusApp(home: AuthGate()));
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          return FutureBuilder<DocumentSnapshot>(
            future: firestore.collection('usuarios').doc(user.uid).get(),
            builder: (context, snapshotUser) {
              if (snapshotUser.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshotUser.hasData || !snapshotUser.data!.exists) {
                return const Scaffold(
                  body: Center(
                    child: Text('Usuário não configurado no sistema'),
                  ),
                );
              }

              final dados = snapshotUser.data!.data() as Map<String, dynamic>;
              final tipo = normalizarTipoUsuarioNatus(
                dados['tipo']?.toString() ??
                    dados['tipoUsuario']?.toString() ??
                    'gestante',
              );

              return TelaPrincipal(
                tipoUsuario: tipo,
                nomeUsuario: dados['nome']?.toString() ?? '',
              );
            },
          );
        }

        return const TelaLogin();
      },
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  final String tipoUsuario;
  final String nomeUsuario;

  const TelaPrincipal({
    super.key,
    required this.tipoUsuario,
    this.nomeUsuario = '',
  });

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  Future<void> alterarTipoUsuario(String uid, String tipoAtual) async {
    String novoTipo = tipoAtual;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Alterar tipo de usuário'),
          content: DropdownButtonFormField<String>(
            initialValue: tipoAtual,
            items: ['admin', 'enfermeira', 'obstetra', 'gestante']
                .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                .toList(),
            onChanged: (value) {
              novoTipo = value!;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await firestore.collection('usuarios').doc(uid).update({
                  'tipo': novoTipo,
                });

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                mostrarMensagem('Tipo de usuário atualizado.');
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> carregarContracoesFirestore() async {
    try {
      final listaFirebase = await dados.buscarContracoes();

      setState(() {
        contracoes.clear();
        contracoes.addAll(listaFirebase);
      });

      debugPrint('✅ Contrações carregadas do Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao carregar contrações: $e');
      mostrarMensagem('Erro ao carregar contrações');
    }
  }

  Future<void> salvarEO() async {
    if (eoNomeController.text.trim().isEmpty) {
      mostrarMensagem('Informe o nome da enfermeira.');
      return;
    }

    try {
      await firestore.collection('enfermeiras').add({
        'nome': eoNomeController.text.trim(),
        'telefone': eoTelefoneController.text.trim(),
        'email': eoEmailController.text.trim(),
        'coren': eoCorenController.text.trim(),
        'especialidade': eoEspecialidadeController.text.trim(),
        'uidEnfermeira': '',
        'criadoEm': DateTime.now().toIso8601String(),
      });

      eoNomeController.clear();
      eoTelefoneController.clear();
      eoEmailController.clear();
      eoCorenController.clear();
      eoEspecialidadeController.clear();

      await carregarEnfermeirasFirestore();

      mostrarMensagem('Enfermeira cadastrada com sucesso!');
    } catch (e) {
      mostrarMensagem('Erro ao salvar enfermeira: $e');
    }
  }

  Future<void> salvarObstetra() async {
    if (obNomeController.text.trim().isEmpty) {
      mostrarMensagem('Informe o nome do obstetra.');
      return;
    }

    try {
      await firestore.collection('obstetras').add({
        'nome': obNomeController.text.trim(),
        'telefone': obTelefoneController.text.trim(),
        'email': obEmailController.text.trim(),
        'crm': obCrmController.text.trim(),
        'especialidade': obEspecialidadeController.text.trim(),
        'uidObstetra': '',
        'criadoEm': DateTime.now().toIso8601String(),
      });

      obNomeController.clear();
      obTelefoneController.clear();
      obEmailController.clear();
      obCrmController.clear();
      obEspecialidadeController.clear();

      await carregarObstetrasFirestore();

      mostrarMensagem('Obstetra cadastrado com sucesso!');
    } catch (e) {
      mostrarMensagem('Erro ao salvar obstetra: $e');
    }
  }

  Future<void> salvarNascimento(
    Map<String, String> gestante,
    String nomeBebe,
    String dataNascimento,
    String sexo,
    String viaNascimento,
    String igAoNascer,
    String pesoBebe,
    String goldenHour,
    String amamentacao,
    String observacoes,
  ) async {
    try {
      final idGestante = gestante['id'];

      if (idGestante == null || idGestante.isEmpty) {
        mostrarMensagem('Erro: gestante sem ID do Firebase.');
        return;
      }

      final dataNascimentoFormatada = formatarDataNascimentoDigitada(
        dataNascimento,
      );

      await firestore.collection('gestantes').doc(idGestante).update({
        'nomeBebe': nomeBebe,
        'dataNascimento': dataNascimentoFormatada,
        'dataNascimentoBebe': dataNascimentoFormatada,
        'sexo': sexo,
        'viaNascimento': viaNascimento,
        'igAoNascer': igAoNascer,
        'pesoBebe': pesoBebe,
        'goldenHour': goldenHour,
        'amamentacao': amamentacao,
        'observacoesBebe': observacoes,
        'statusGestante': 'Puérpera',
      });

      await carregarGestantesFirestore();

      mostrarMensagem('Dados do nascimento salvos com sucesso!');
    } catch (e) {
      mostrarMensagem('Erro ao salvar nascimento: $e');
    }
  }

  bool usuarioEhAdmin() {
    return widget.tipoUsuario == 'admin';
  }

  String nomeEoLogada() {
    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

    final eo = enfermeiras.firstWhere(
      (e) => e['uidEnfermeira'] == uidLogado,
      orElse: () => {},
    );

    final nomeEo = eo['nome'] ?? '';
    if (nomeEo.isNotEmpty) return nomeEo;

    final ob = obstetras.firstWhere(
      (o) => o['uidObstetra'] == uidLogado,
      orElse: () => {},
    );

    final nomeOb = ob['nome'] ?? '';
    if (nomeOb.isNotEmpty) return nomeOb;

    if (widget.nomeUsuario.trim().isNotEmpty) {
      return widget.nomeUsuario;
    }

    return eoResponsavelProntuario;
  }

  @override
  void initState() {
    super.initState();

    NatusTema.atual.addListener(aoMudarTema);

    if (widget.tipoUsuario == 'superAdmin') {
      telaAtual = 'Dashboard SaaS';
    } else if (widget.tipoUsuario == 'gestante') {
      telaAtual = 'Área da gestante';
    }

    carregarGestantesFirestore();
    carregarAtendimentosFirestore();
    carregarMateriaisFirestore();
    carregarDocumentosFirestore();
    carregarParcelasFirestore();
    carregarEnfermeirasFirestore();
    carregarObstetrasFirestore();
    carregarTemaUsuario();
    carregarContracoesFirestore();
    carregarBibliotecaFirestore();
    carregarPlanosFirestore();
  }

  void aoMudarTema() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    NatusTema.atual.removeListener(aoMudarTema);
    super.dispose();
  }

  double converterValorDinamico(dynamic valor) =>
      fincalc.converterValorDinamico(valor);

  double valorPlanoAtual() {
    final planoEncontrado = planosCadastrados.firstWhere(
      (p) => (p['id'] ?? '').toString() == planoIdSelecionado,
      orElse: () => {},
    );

    return converterValorDinamico(planoEncontrado['valor']);
  }

  Map<String, dynamic> planoSelecionadoMap() {
    return planosCadastrados.firstWhere(
      (p) => (p['id'] ?? '').toString() == planoIdSelecionado,
      orElse: () => {},
    );
  }

  Future<void> carregarPlanosFirestore() async {
    try {
      final lista = await dados.buscarPlanos();

      setState(() {
        planosCadastrados
          ..clear()
          ..addAll(lista);

        final ativos = planosCadastrados
            .where((p) => p['ativo'] != false)
            .toList();
        if (planoIdSelecionado.isEmpty && ativos.isNotEmpty) {
          final primeiro = ativos.first;
          planoIdSelecionado = (primeiro['id'] ?? '').toString();
          plano = (primeiro['nomePlano'] ?? '').toString();
          parcelas = (primeiro['parcelas'] ?? '1').toString();
          descricaoNfsePlano = (primeiro['descricaoNfse'] ?? '').toString();
        }
      });
    } catch (e) {
      mostrarMensagem('Erro ao carregar planos: $e');
    }
  }

  void aplicarPlanoSelecionado(String idPlano) {
    final planoEncontrado = planosCadastrados.firstWhere(
      (p) => (p['id'] ?? '').toString() == idPlano,
      orElse: () => {},
    );

    setState(() {
      planoIdSelecionado = idPlano;
      plano = (planoEncontrado['nomePlano'] ?? '').toString();
      parcelas = (planoEncontrado['parcelas'] ?? '1').toString();
      descricaoNfsePlano = (planoEncontrado['descricaoNfse'] ?? '').toString();
    });
  }

  Future<void> salvarPlanoNatus() async {
    final nome = planoNomeController.text.trim();
    final valor = converterValor(planoValorController.text);
    final qtdParcelas = int.tryParse(planoParcelasController.text.trim()) ?? 0;

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome do plano.');
      return;
    }

    if (valor <= 0) {
      mostrarMensagem('Informe um valor válido para o plano.');
      return;
    }

    if (qtdParcelas <= 0) {
      mostrarMensagem('Informe a quantidade de parcelas.');
      return;
    }

    try {
      await firestore.collection('planos').add({
        'nomePlano': nome,
        'valor': valor,
        'valorFormatado': formatarMoeda(valor),
        'parcelas': qtdParcelas.toString(),
        'descricaoComercial': planoDescricaoComercialController.text.trim(),
        'descricaoNfse': planoDescricaoNfseController.text.trim(),
        'ativo': true,
        'criadoEm': DateTime.now().toIso8601String(),
        'atualizadoEm': DateTime.now().toIso8601String(),
      });

      planoNomeController.clear();
      planoValorController.clear();
      planoParcelasController.text = '1';
      planoDescricaoComercialController.clear();
      planoDescricaoNfseController.clear();

      await carregarPlanosFirestore();
      mostrarMensagem('Plano cadastrado com sucesso!');
    } catch (e) {
      mostrarMensagem('Erro ao salvar plano: $e');
    }
  }

  Future<void> alterarStatusPlano(Map<String, dynamic> planoDados) async {
    final id = (planoDados['id'] ?? '').toString();
    if (id.isEmpty) return;

    final ativoAtual = planoDados['ativo'] != false;

    try {
      await firestore.collection('planos').doc(id).update({
        'ativo': !ativoAtual,
        'atualizadoEm': DateTime.now().toIso8601String(),
      });
      await carregarPlanosFirestore();
      mostrarMensagem(ativoAtual ? 'Plano inativado.' : 'Plano ativado.');
    } catch (e) {
      mostrarMensagem('Erro ao atualizar plano: $e');
    }
  }

  Future<void> editarPlanoNatus(Map<String, dynamic> planoDados) async {
    final id = (planoDados['id'] ?? '').toString();
    if (id.isEmpty) return;

    final nomeController = TextEditingController(
      text: (planoDados['nomePlano'] ?? '').toString(),
    );
    final valorController = TextEditingController(
      text: formatarMoeda(converterValorDinamico(planoDados['valor'])),
    );
    final parcelasController = TextEditingController(
      text: (planoDados['parcelas'] ?? '1').toString(),
    );
    final descricaoComercialController = TextEditingController(
      text: (planoDados['descricaoComercial'] ?? '').toString(),
    );
    final descricaoNfseController = TextEditingController(
      text: (planoDados['descricaoNfse'] ?? '').toString(),
    );

    final salvou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar plano'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                campoFull(nomeController, 'Nome do plano'),
                const SizedBox(height: 12),
                campoFull(valorController, 'Valor total'),
                const SizedBox(height: 12),
                campoFull(parcelasController, 'Parcelas'),
                const SizedBox(height: 12),
                campoFull(descricaoComercialController, 'Descrição comercial'),
                const SizedBox(height: 12),
                campoFull(descricaoNfseController, 'Descrição NFS-e'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NatusApp.vinho,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
              ),
            ),
          ],
        );
      },
    );

    if (salvou != true) return;

    final nome = nomeController.text.trim();
    final valor = converterValor(valorController.text);
    final qtdParcelas = int.tryParse(parcelasController.text.trim()) ?? 0;

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome do plano.');
      return;
    }

    if (valor <= 0) {
      mostrarMensagem('Informe um valor válido para o plano.');
      return;
    }

    if (qtdParcelas <= 0) {
      mostrarMensagem('Informe a quantidade de parcelas.');
      return;
    }

    try {
      await firestore.collection('planos').doc(id).update({
        'nomePlano': nome,
        'valor': valor,
        'valorFormatado': formatarMoeda(valor),
        'parcelas': qtdParcelas.toString(),
        'descricaoComercial': descricaoComercialController.text.trim(),
        'descricaoNfse': descricaoNfseController.text.trim(),
        'atualizadoEm': DateTime.now().toIso8601String(),
      });
      await carregarPlanosFirestore();
      mostrarMensagem('Plano atualizado com sucesso!');
    } catch (e) {
      mostrarMensagem('Erro ao editar plano: $e');
    }
  }

  Future<void> abrirArquivo(String url) async {
    if (url.trim().isEmpty) {
      mostrarMensagem('Link do material não encontrado.');
      return;
    }

    final uri = Uri.parse(url.trim());

    try {
      final abriu = await launchUrl(uri, mode: LaunchMode.platformDefault);

      if (!abriu) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      mostrarMensagem('Não foi possível abrir o material.');
    }
  }

  Future<void> carregarEnfermeirasFirestore() async {
    try {
      final listaFirebase = await dados.buscarEnfermeiras();

      setState(() {
        enfermeiras.clear();
        enfermeiras.addAll(listaFirebase);
      });
    } catch (e) {
      mostrarMensagem('Erro ao carregar enfermeiras.');
    }
  }

  Future<void> carregarObstetrasFirestore() async {
    try {
      final listaFirebase = await dados.buscarObstetras();

      setState(() {
        obstetras.clear();
        obstetras.addAll(listaFirebase);
      });
    } catch (e) {
      mostrarMensagem('Erro ao carregar obstetras.');
    }
  }

  Future<void> carregarBibliotecaFirestore() async {
    try {
      final listaFirebase = await dados.buscarBiblioteca();

      setState(() {
        biblioteca.clear();
        biblioteca.addAll(listaFirebase);
      });

      debugPrint(
        '✅ Biblioteca carregada do Firebase: ${listaFirebase.length} itens',
      );
    } catch (e) {
      debugPrint('❌ Erro ao carregar biblioteca: $e');
      mostrarMensagem('Erro ao carregar biblioteca');
    }
  }

  Future<void> salvarItemBibliotecaFirestore(
    Map<String, String> material,
  ) async {
    try {
      final docRef = await firestore.collection('biblioteca').add(material);
      material['id'] = docRef.id;

      await carregarBibliotecaFirestore();
      mostrarMensagem('Material adicionado à biblioteca.');
    } catch (e) {
      debugPrint('❌ Erro ao salvar material da biblioteca: $e');
      mostrarMensagem('Erro ao adicionar material à biblioteca.');
    }
  }

  Future<void> carregarAtendimentosFirestore() async {
    try {
      final listaFirebase = await dados.buscarAtendimentos();

      setState(() {
        atendimentos.clear();
        atendimentos.addAll(listaFirebase);
      });

      debugPrint('✅ Atendimentos carregados do Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao carregar atendimentos: $e');
      mostrarMensagem('Erro ao carregar atendimentos');
    }
  }

  Future<void> testarImportacaoGestantes2025() async {
    await importarGestantesDaPlanilha(
      anoPadrao: '2025',
      abaPreferida: 'Gestantes 2025',
      origem: 'importacao_xls_inteligente_2025',
      gerarFinanceiro: false,
      forcarHistorico: true,
    );
  }

  Future<void> importarGestantes2026() async {
    await importarGestantesDaPlanilha(
      anoPadrao: '2026',
      abaPreferida: 'Gestantes 2026',
      origem: 'importacao_xls_inteligente_2026',
      gerarFinanceiro: true,
      forcarHistorico: false,
    );
  }

  Future<void> importarGestantesDaPlanilha({
    required String anoPadrao,
    required String abaPreferida,
    required String origem,
    required bool gerarFinanceiro,
    required bool forcarHistorico,
  }) async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );

      if (resultado == null) {
        mostrarMensagem('Nenhum arquivo selecionado.');
        return;
      }

      final arquivoSelecionado = resultado.files.first;
      final bytes = arquivoSelecionado.bytes;
      final nomeArquivo = arquivoSelecionado.name.toLowerCase();

      if (bytes == null) {
        mostrarMensagem('Erro ao ler o arquivo selecionado.');
        return;
      }

      List<List<String>> lerCsvSimples(String conteudo) {
        final linhas = <List<String>>[];
        var linhaAtual = <String>[];
        final celulaAtual = StringBuffer();
        var dentroDeAspas = false;

        void finalizarCelula() {
          linhaAtual.add(celulaAtual.toString().trim());
          celulaAtual.clear();
        }

        void finalizarLinha() {
          finalizarCelula();
          final temConteudo = linhaAtual.any(
            (celula) => celula.trim().isNotEmpty,
          );
          if (temConteudo) {
            linhas.add(linhaAtual);
          }
          linhaAtual = <String>[];
        }

        for (int i = 0; i < conteudo.length; i++) {
          final caractere = conteudo[i];

          if (caractere == '"') {
            final proximoTambemAspas =
                dentroDeAspas &&
                i + 1 < conteudo.length &&
                conteudo[i + 1] == '"';

            if (proximoTambemAspas) {
              celulaAtual.write('"');
              i++;
            } else {
              dentroDeAspas = !dentroDeAspas;
            }
          } else if ((caractere == ';' || caractere == ',') && !dentroDeAspas) {
            finalizarCelula();
          } else if ((caractere == '\n' || caractere == '\r') &&
              !dentroDeAspas) {
            if (caractere == '\r' &&
                i + 1 < conteudo.length &&
                conteudo[i + 1] == '\n') {
              i++;
            }
            finalizarLinha();
          } else {
            celulaAtual.write(caractere);
          }
        }

        if (celulaAtual.isNotEmpty || linhaAtual.isNotEmpty) {
          finalizarLinha();
        }

        return linhas;
      }

      late final String nomeAbaSelecionada;
      late final List<List<String>> linhasPlanilha;

      if (nomeArquivo.endsWith('.csv')) {
        nomeAbaSelecionada = 'CSV';
        final conteudoCsv = utf8
            .decode(bytes, allowMalformed: true)
            .replaceFirst('\uFEFF', '');
        linhasPlanilha = lerCsvSimples(conteudoCsv);
      } else {
        try {
          final arquivoExcel = excel.Excel.decodeBytes(bytes);

          if (arquivoExcel.tables.isEmpty) {
            mostrarMensagem('A planilha não possui abas.');
            return;
          }

          nomeAbaSelecionada = arquivoExcel.tables.containsKey(abaPreferida)
              ? abaPreferida
              : arquivoExcel.tables.keys.first;

          final aba = arquivoExcel.tables.containsKey(abaPreferida)
              ? arquivoExcel[abaPreferida]
              : arquivoExcel.tables.values.first;

          linhasPlanilha = aba.rows.map((linha) {
            return linha
                .map((celula) => celula?.value?.toString() ?? '')
                .toList();
          }).toList();
        } catch (erroExcel) {
          debugPrint('❌ Erro ao ler XLSX. Tente importar como CSV: $erroExcel');
          mostrarMensagem(
            'Não consegui ler este XLSX. Salve a planilha como CSV e importe novamente.',
          );
          return;
        }
      }

      if (linhasPlanilha.isEmpty) {
        mostrarMensagem('A planilha está vazia.');
        return;
      }

      String normalizarCabecalho(String texto) {
        return texto
            .toLowerCase()
            .trim()
            .replaceAll('ã', 'a')
            .replaceAll('á', 'a')
            .replaceAll('à', 'a')
            .replaceAll('â', 'a')
            .replaceAll('ä', 'a')
            .replaceAll('é', 'e')
            .replaceAll('ê', 'e')
            .replaceAll('è', 'e')
            .replaceAll('ë', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ì', 'i')
            .replaceAll('î', 'i')
            .replaceAll('ï', 'i')
            .replaceAll('ó', 'o')
            .replaceAll('ô', 'o')
            .replaceAll('õ', 'o')
            .replaceAll('ò', 'o')
            .replaceAll('ö', 'o')
            .replaceAll('ú', 'u')
            .replaceAll('ù', 'u')
            .replaceAll('û', 'u')
            .replaceAll('ü', 'u')
            .replaceAll('ç', 'c')
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      bool cabecalhoCombina(String cabecalho, String esperado) {
        if (cabecalho == esperado) return true;
        if (esperado.length >= 5 && cabecalho.contains(esperado)) return true;
        if (cabecalho.length >= 5 && esperado.contains(cabecalho)) return true;
        return false;
      }

      final aliasesPorCampo = <String, List<String>>{
        'nomeGestante': [
          'nomeGestante',
          'Nome da Mãe',
          'Nome da Mae',
          'Mãe',
          'Mae',
          'Gestante',
          'Paciente',
          'Cliente',
          'Nome Gestante',
          'Nome da Gestante',
        ],
        'cpfGestante': [
          'cpfGestante',
          'CPF',
          'Cpf',
          'CPF Gestante',
          'CPF da Gestante',
          'CPF da Mãe',
          'CPF da Mae',
        ],
        'telefoneGestante': [
          'telefoneGestante',
          'Contato',
          'Telefone',
          'Celular',
          'WhatsApp',
          'Telefone da mãe',
          'Telefone da mae',
          'Telefone Gestante',
        ],
        'emailGestante': [
          'emailGestante',
          'E-mail',
          'Email',
          'Email Gestante',
          'E-mail Gestante',
        ],
        'nomePai': ['nomePai', 'Nome do Pai', 'Pai', 'Acompanhante'],
        'cpfPai': [
          'cpfPai',
          'CPF do Pai',
          'CPF Pai',
          'CPF do responsável',
          'CPF Responsável',
          'CPF Responsavel',
        ],
        'nomeBebe': [
          'nomeBebe',
          'Nome do Bebê',
          'Nome do Bebe',
          'Bebê',
          'Bebe',
          'RN',
          'Nome RN',
        ],
        'sexo': ['sexo', 'Sexo', 'Sexo do Bebê', 'Sexo do Bebe'],
        'dpp': [
          'dpp',
          'DPP',
          'Data Provável do Parto',
          'Data Provavel do Parto',
        ],
        'dataNascimento': [
          'dataNascimento',
          'dataNascimentoBebe',
          'Data de Nascimento',
          'Data Nascimento',
          'Nascimento',
          'Nascimento Bebê',
          'Nascimento Bebe',
          'Data do Parto',
          'Parto Data',
        ],
        'hospitalGestante': [
          'hospitalGestante',
          'Maternidade',
          'Hospital',
          'Hospital Gestante',
          'Local do Parto',
        ],
        'convenioGestante': [
          'convenioGestante',
          'Convênio',
          'Convenio',
          'Plano de Saúde',
          'Plano de Saude',
        ],
        'obstetraGestante': [
          'obstetraGestante',
          'Obstetra',
          'Médico',
          'Medico',
          'Médica',
          'Medica',
        ],
        'viaNascimento': [
          'viaNascimento',
          'Via de Parto',
          'Via de nascimento',
          'Parto',
          'Tipo de Parto',
        ],
        'igAoNascer': [
          'igAoNascer',
          'IG',
          'IG ao Nascer',
          'Idade Gestacional ao Nascer',
        ],
        'pesoBebe': ['pesoBebe', 'Peso Bebê', 'Peso Bebe', 'Peso RN', 'Peso'],
        'goldenHour': ['goldenHour', 'Golden Hour', 'Hora Dourada'],
        'amamentacao': [
          'amamentacao',
          'Amamentação',
          'Amamentacao',
          'Aleitamento',
        ],
        'observacoesBebe': [
          'observacoesBebe',
          'Observação',
          'Observacao',
          'Observações',
          'Observacoes',
          'Observações Bebê',
          'Observacoes Bebe',
          'Obs',
        ],
        'plano': ['plano', 'Plano', 'Serviço', 'Servico', 'Pacote'],
        'valorPlano': [
          'valorPlano',
          'Valor Plano',
          'Valor do Plano',
          'Valor Total',
        ],
        'entrada': ['entrada', 'Entrada', 'Valor Entrada'],
        'parcelas': [
          'parcelas',
          'Parcelas',
          'Quantidade de Parcelas',
          'Qtd Parcelas',
        ],
        'parcelasPagas': [
          'parcelasPagas',
          'Parcelas Pagas',
          'Parcelas já pagas',
          'Parcelas ja pagas',
        ],
        'formaPagamento': [
          'formaPagamento',
          'Forma Pagamento',
          'Forma de Pagamento',
          'Pagamento',
        ],
        'statusGestante': ['statusGestante', 'Status', 'Situação', 'Situacao'],
        'mesReferencia': [
          'Mês',
          'Mes',
          'Mês Referência',
          'Mes Referencia',
          'Mês Nascimento',
          'Mes Nascimento',
        ],
        'emAtendimento': [
          'Em Atendimento',
          'EmAtendimento',
          'Atendimento Ativo',
        ],
        'nascido': ['Nascido', 'Nasceu', 'Bebê nasceu', 'Bebe nasceu'],
        'analgesiaParto': [
          'Analgesia de parto',
          'Analgesia',
          'Com Analgesia',
          'Analgesia Parto',
        ],
        'observacoesBebe2': [
          'Observação2',
          'Observacao2',
          'Observação 2',
          'Observacao 2',
          'Obs2',
          'Obs 2',
        ],
        'ano': ['ano', 'Ano', 'Ano Atendimento', 'Ano Nascimento'],
      };

      final aliasesNormalizados = aliasesPorCampo.values
          .expand((nomes) => nomes)
          .map(normalizarCabecalho)
          .where((chave) => chave.isNotEmpty)
          .toSet();

      Map<String, int> localizarCabecalhosDaLinha(List<String> linha) {
        final encontrados = <String, int>{};

        for (int i = 0; i < linha.length; i++) {
          final texto = linha[i].toString();
          final chave = normalizarCabecalho(texto);

          if (chave.isEmpty) continue;

          final reconhecido = aliasesNormalizados.any(
            (alias) => cabecalhoCombina(chave, alias),
          );

          if (reconhecido) {
            encontrados[chave] = i;
          }
        }

        return encontrados;
      }

      int linhaCabecalhoIndex = -1;
      Map<String, int> cabecalhos = {};
      int melhorPontuacao = 0;

      final limiteBusca = linhasPlanilha.length < 30
          ? linhasPlanilha.length
          : 30;

      for (int i = 0; i < limiteBusca; i++) {
        final encontrados = localizarCabecalhosDaLinha(linhasPlanilha[i]);
        final pontuacao = encontrados.length;

        if (pontuacao > melhorPontuacao) {
          melhorPontuacao = pontuacao;
          linhaCabecalhoIndex = i;
          cabecalhos = encontrados;
        }
      }

      if (linhaCabecalhoIndex == -1 || melhorPontuacao == 0) {
        mostrarMensagem(
          'Não encontrei cabeçalhos reconhecíveis na planilha. Verifique se existe uma linha com nomes como Gestante, Telefone, DPP ou Nascimento.',
        );
        return;
      }

      String lerCampo(List<String> linha, List<String> nomesPossiveis) {
        for (final nome in nomesPossiveis) {
          final esperado = normalizarCabecalho(nome);

          for (final entrada in cabecalhos.entries) {
            if (cabecalhoCombina(entrada.key, esperado)) {
              final index = entrada.value;

              if (index < linha.length) {
                return linha[index].toString().trim();
              }
            }
          }
        }

        return '';
      }

      String lerCampoPorChave(List<String> linha, String chaveCampo) {
        return lerCampo(linha, aliasesPorCampo[chaveCampo] ?? [chaveCampo]);
      }

      String formatarDataImportada(String valor) {
        final texto = valor.trim();
        if (texto.isEmpty) return '';

        final dataBrasileira = RegExp(
          r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$',
        ).firstMatch(texto);

        if (dataBrasileira != null) {
          final dia = int.tryParse(dataBrasileira.group(1) ?? '');
          final mes = int.tryParse(dataBrasileira.group(2) ?? '');
          var ano = int.tryParse(dataBrasileira.group(3) ?? '');

          if (dia != null && mes != null && ano != null) {
            if (ano < 100) ano += 2000;
            return '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$ano';
          }
        }

        try {
          final data = DateTime.parse(texto);
          final dia = data.day.toString().padLeft(2, '0');
          final mes = data.month.toString().padLeft(2, '0');
          final ano = data.year.toString();
          return '$dia/$mes/$ano';
        } catch (_) {}

        final numeroExcel = double.tryParse(texto.replaceAll(',', '.'));

        if (numeroExcel != null && numeroExcel > 20000 && numeroExcel < 80000) {
          final data = DateTime(
            1899,
            12,
            30,
          ).add(Duration(days: numeroExcel.floor()));

          final dia = data.day.toString().padLeft(2, '0');
          final mes = data.month.toString().padLeft(2, '0');
          final ano = data.year.toString();
          return '$dia/$mes/$ano';
        }

        return texto;
      }

      String normalizarStatus(String valor) {
        final status = valor.trim().toLowerCase();

        if (status.contains('gestante')) return 'Gestante';
        if (status.contains('puerpera') || status.contains('puérpera')) {
          return 'Puérpera';
        }
        if (status.contains('encerrada') || status.contains('encerrado')) {
          return 'Histórico';
        }
        if (status.contains('historico') || status.contains('histórico')) {
          return 'Histórico';
        }

        return forcarHistorico ? 'Histórico' : 'Histórico';
      }

      bool valorSim(String valor) {
        final texto = valor.trim().toLowerCase();
        return texto == 'sim' ||
            texto == 's' ||
            texto == 'x' ||
            texto == '1' ||
            texto == 'true';
      }

      int? numeroMesImportacao(String valor) {
        final texto = normalizarCabecalho(valor);

        if (texto.isEmpty) return null;

        const meses = {
          'janeiro': 1,
          'jan': 1,
          'fevereiro': 2,
          'fev': 2,
          'marco': 3,
          'mar': 3,
          'abril': 4,
          'abr': 4,
          'maio': 5,
          'mai': 5,
          'junho': 6,
          'jun': 6,
          'julho': 7,
          'jul': 7,
          'agosto': 8,
          'ago': 8,
          'setembro': 9,
          'set': 9,
          'outubro': 10,
          'out': 10,
          'novembro': 11,
          'nov': 11,
          'dezembro': 12,
          'dez': 12,
        };

        final mesTexto = meses[texto];
        if (mesTexto != null) return mesTexto;

        final numero = int.tryParse(texto);
        if (numero != null && numero >= 1 && numero <= 12) {
          return numero;
        }

        return null;
      }

      String corrigirDataNascimentoPeloMesReferencia({
        required String data,
        required String mesReferencia,
      }) {
        final mesRef = numeroMesImportacao(mesReferencia);

        if (mesRef == null || data.trim().isEmpty) {
          return data;
        }

        final partes = RegExp(
          r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$',
        ).firstMatch(data.trim());

        if (partes == null) {
          return data;
        }

        final dia = int.tryParse(partes.group(1) ?? '');
        final mes = int.tryParse(partes.group(2) ?? '');
        final ano = int.tryParse(partes.group(3) ?? '');

        if (dia == null || mes == null || ano == null) {
          return data;
        }

        // Se o mês já bate com a coluna "Mês", mantém como está.
        if (mes == mesRef) {
          return data;
        }

        // Correção para datas ambíguas que o Excel importou no padrão americano.
        // Exemplo: coluna Mês = Janeiro e data importada = 01/08/2025.
        // O correto provável é 08/01/2025.
        if (dia == mesRef) {
          final novoDia = mes;
          final novoMes = dia;

          try {
            final corrigida = DateTime(ano, novoMes, novoDia);

            if (corrigida.year == ano &&
                corrigida.month == novoMes &&
                corrigida.day == novoDia) {
              final diaFormatado = corrigida.day.toString().padLeft(2, '0');
              final mesFormatado = corrigida.month.toString().padLeft(2, '0');
              final anoFormatado = corrigida.year.toString();

              return '$diaFormatado/$mesFormatado/$anoFormatado';
            }
          } catch (_) {}
        }

        return data;
      }

      String inferirAno({
        required String anoImportado,
        required String dataNascimento,
        required String dpp,
      }) {
        final anoDireto = RegExp(r'(20\d{2})').firstMatch(anoImportado);
        if (anoDireto != null) return anoDireto.group(1)!;

        final anoNascimento = RegExp(r'(20\d{2})').firstMatch(dataNascimento);
        if (anoNascimento != null) return anoNascimento.group(1)!;

        final anoDpp = RegExp(r'(20\d{2})').firstMatch(dpp);
        if (anoDpp != null) return anoDpp.group(1)!;

        final anoAba = RegExp(r'(20\d{2})').firstMatch(nomeAbaSelecionada);
        if (anoAba != null) return anoAba.group(1)!;

        return anoPadrao;
      }

      int importadas = 0;
      int ignoradas = 0;
      int parcelasCriadas = 0;

      for (var linha in linhasPlanilha.skip(linhaCabecalhoIndex + 1)) {
        final nomeGestante = lerCampoPorChave(linha, 'nomeGestante');

        if (nomeGestante.isEmpty) {
          ignoradas++;
          continue;
        }

        final telefoneGestante = lerCampoPorChave(linha, 'telefoneGestante');
        final emailGestante = lerCampoPorChave(linha, 'emailGestante');
        final nomePai = lerCampoPorChave(linha, 'nomePai');
        final cpfPai = lerCampoPorChave(linha, 'cpfPai');
        final nomeBebe = lerCampoPorChave(linha, 'nomeBebe');
        final sexoBebe = lerCampoPorChave(linha, 'sexo');
        final mesReferencia = lerCampoPorChave(linha, 'mesReferencia');
        final dpp = formatarDataImportada(lerCampoPorChave(linha, 'dpp'));
        final dataNascimentoOriginal = formatarDataImportada(
          lerCampoPorChave(linha, 'dataNascimento'),
        );
        final dataNascimento = corrigirDataNascimentoPeloMesReferencia(
          data: dataNascimentoOriginal,
          mesReferencia: mesReferencia,
        );
        final hospitalGestante = lerCampoPorChave(linha, 'hospitalGestante');
        final convenioGestante = lerCampoPorChave(linha, 'convenioGestante');
        final obstetraGestante = lerCampoPorChave(linha, 'obstetraGestante');
        final viaNascimento = lerCampoPorChave(linha, 'viaNascimento');
        final igAoNascer = lerCampoPorChave(linha, 'igAoNascer');
        final pesoBebe = lerCampoPorChave(linha, 'pesoBebe');
        final goldenHour = lerCampoPorChave(linha, 'goldenHour');
        final amamentacao = lerCampoPorChave(linha, 'amamentacao');
        final observacaoPrincipal = lerCampoPorChave(linha, 'observacoesBebe');
        final observacaoSecundaria = lerCampoPorChave(
          linha,
          'observacoesBebe2',
        );
        final observacoesBebe = [
          observacaoPrincipal,
          observacaoSecundaria,
        ].where((texto) => texto.trim().isNotEmpty).join(' | ');
        final analgesiaParto = lerCampoPorChave(linha, 'analgesiaParto');
        final planoImportado = lerCampoPorChave(linha, 'plano');
        final valorPlanoImportado = lerCampoPorChave(linha, 'valorPlano');
        final entradaImportada = lerCampoPorChave(linha, 'entrada');
        final parcelasImportadas = lerCampoPorChave(linha, 'parcelas');
        final parcelasPagasImportadas = lerCampoPorChave(
          linha,
          'parcelasPagas',
        );
        final formaPagamentoImportada = lerCampoPorChave(
          linha,
          'formaPagamento',
        );
        final statusImportado = lerCampoPorChave(linha, 'statusGestante');
        final emAtendimento = lerCampoPorChave(linha, 'emAtendimento');
        final nascido = lerCampoPorChave(linha, 'nascido');

        String statusFinal;

        if (forcarHistorico) {
          statusFinal = 'Histórico';
        } else if (statusImportado.trim().isNotEmpty) {
          statusFinal = normalizarStatus(statusImportado);
        } else if (valorSim(emAtendimento)) {
          statusFinal = 'Puérpera';
        } else if (valorSim(nascido)) {
          statusFinal = 'Histórico';
        } else {
          statusFinal = 'Histórico';
        }

        final historicoFinal = statusFinal == 'Histórico' ? 'true' : 'false';
        final anoFinal = inferirAno(
          anoImportado: lerCampoPorChave(linha, 'ano'),
          dataNascimento: dataNascimento,
          dpp: dpp,
        );

        final novaGestante = {
          'nomeGestante': nomeGestante,
          'cpfGestante': lerCampoPorChave(linha, 'cpfGestante'),
          'telefoneGestante': telefoneGestante,
          'emailGestante': emailGestante,

          'nomePai': nomePai,
          'cpfPai': cpfPai,
          'telefonePai': '',
          'emailPai': '',

          'nomeBebe': nomeBebe,
          'sexo': sexoBebe.isEmpty ? 'Não informado' : sexoBebe,
          'dpp': dpp,
          'dataNascimento': dataNascimento,
          'dataNascimentoBebe': dataNascimento,
          'viaNascimento': viaNascimento,
          'igAoNascer': igAoNascer,
          'pesoBebe': pesoBebe,
          'goldenHour': goldenHour.isEmpty ? 'Não informado' : goldenHour,
          'amamentacao': amamentacao.isEmpty ? 'Não informado' : amamentacao,
          'analgesiaParto': analgesiaParto,
          'observacoesBebe': observacoesBebe,
          'mesReferenciaImportacao': mesReferencia,
          'dataNascimentoOriginalImportacao': dataNascimentoOriginal,

          'hospitalGestante': hospitalGestante,
          'obstetraGestante': obstetraGestante,
          'convenioGestante': convenioGestante,

          'enderecoGestante': '',
          'numeroGestante': '',
          'complementoGestante': '',
          'bairroGestante': '',
          'cidadeGestante': '',
          'estadoGestante': '',
          'cepGestante': '',

          'plano': planoImportado,
          'valorPlano': valorPlanoImportado,
          'entrada': entradaImportada,
          'parcelas': parcelasImportadas.isEmpty ? '1' : parcelasImportadas,
          'parcelasPagas': parcelasPagasImportadas.isEmpty
              ? '0'
              : parcelasPagasImportadas,
          'formaPagamento': formaPagamentoImportada,
          'valorParcela': '',

          'uidGestante': '',
          'statusGestante': statusFinal,
          'historico': historicoFinal,
          'ano': anoFinal,
          'origem': origem,
          'criadoEm': DateTime.now().toIso8601String(),
        };

        final docRef = await firestore
            .collection('gestantes')
            .add(novaGestante);
        novaGestante['id'] = docRef.id;

        if (gerarFinanceiro &&
            (novaGestante['valorPlano'] ?? '').isNotEmpty &&
            (novaGestante['parcelas'] ?? '').isNotEmpty) {
          await gerarParcelasDaGestante(novaGestante);
          parcelasCriadas++;
        }

        importadas++;
      }

      await carregarGestantesFirestore();

      if (gerarFinanceiro) {
        await carregarParcelasFirestore();
      }

      final mensagemFinanceiro = gerarFinanceiro
          ? ' e parcelas de $parcelasCriadas gestantes geradas'
          : '';

      mostrarMensagem(
        'Importação concluída: $importadas importadas, $ignoradas ignoradas$mensagemFinanceiro. Cabeçalho encontrado na linha ${linhaCabecalhoIndex + 1}.',
      );
    } catch (e) {
      debugPrint('❌ Erro ao importar gestantes: $e');
      mostrarMensagem('Erro ao importar gestantes.');
    }
  }

  String telaAtual = 'Dashboard';

  String filtroStatusGestante = 'Ativas';
  String filtroMaternidade = 'Todas';
  FiltroDashboardPacientes? filtroDashboardPacientes;
  final buscaGestantesController = TextEditingController();

  final List<Map<String, String>> gestantes = [
    {
      'nomeGestante': 'Maressa Teste',
      'cpfGestante': '',
      'telefoneGestante': '(41) 99999-9999',
      'emailGestante': 'teste@natus.com',
      'enderecoGestante': 'Rua Teste, 123',
      'bairroGestante': 'Centro',
      'cidadeGestante': 'Curitiba',
      'cepGestante': '80000-000',
      'hospitalGestante': 'Hospital Teste',
      'obstetraGestante': 'Dra. Teste',
      'convenioGestante': 'Particular',

      'nomePai': 'Pai Teste',
      'cpfPai': '',
      'telefonePai': '(41) 98888-8888',
      'emailPai': 'pai@natus.com',

      'nomeBebe': 'Bebê Teste',
      'sexo': 'Não informado',
      'dpp': '19/09/2026',
      'dataNascimento': '',
      'viaNascimento': 'Não informado',
      'igAoNascer': '',
      'pesoBebe': '',
      'goldenHour': 'Não informado',
      'amamentacao': 'Não informado',
      'observacoesBebe': '',

      'plano': 'Acompanhamento integral',
      'valorPlano': 'R\$ 4000,00',
      'descontoPercentual': '0%',
      'valorDesconto': 'R\$ 0,00',
      'entrada': 'R\$ 0,00',
      'parcelas': '1',
      'formaPagamento': 'Pix',
      'valorParcela': 'R\$ 4000,00',
      'consultorio': 'Não',
    },
  ];

  final List<Map<String, String>> documentos = [];
  final List<Map<String, String>> biblioteca = [];
  final List<Map<String, String>> observacoesProntuario = [];

  final observacaoProntuarioController = TextEditingController();
  String nomeArquivoSelecionado = '';
  String eoResponsavelProntuario = 'Maressa';
  String tipoObservacaoProntuario = 'Evolução';
  String secaoProntuarioSelecionada = 'Evolução';

  final anamneseQueixaController = TextEditingController();
  final anamneseHistoricoObstetricoController = TextEditingController();
  final anamneseHistoricoSaudeController = TextEditingController();
  final anamneseAlergiasController = TextEditingController();
  final anamneseMedicamentosController = TextEditingController();
  final anamneseHabitosController = TextEditingController();
  final anamneseEmocionalController = TextEditingController();
  final anamnesePartoController = TextEditingController();
  final anamneseAmamentacaoController = TextEditingController();

  final examePaController = TextEditingController();
  final exameFcController = TextEditingController();
  final exameTemperaturaController = TextEditingController();
  final examePesoController = TextEditingController();
  final exameAlturaController = TextEditingController();
  final exameImcController = TextEditingController();
  final exameAlturaUterinaController = TextEditingController();
  final exameBcfController = TextEditingController();
  final exameEdemaController = TextEditingController();
  final exameMamasController = TextEditingController();
  final exameAbdomeController = TextEditingController();
  final exameObservacoesController = TextEditingController();

  final planoCondutasController = TextEditingController();
  final planoOrientacoesController = TextEditingController();
  final planoEncaminhamentosController = TextEditingController();
  final planoRetornoController = TextEditingController();
  final planoObservacoesController = TextEditingController();

  final documentoNomeController = TextEditingController();
  final documentoTipoController = TextEditingController();

  final novoNomeController = TextEditingController();
  final novoEmailController = TextEditingController();
  final novaSenhaController = TextEditingController();

  String novoTipoUsuario = 'gestante';
  String? gestanteSelecionadaLogin;
  String? enfermeiraSelecionadaLogin;
  String? obstetraSelecionadoLogin;

  final List<Map<String, String>> enfermeiras = [];

  final List<Map<String, String>> obstetras = [];

  String documentoGestanteSelecionada = '';
  String documentoTipoSelecionado = 'Exame';

  final List<Map<String, String>> atendimentos = [];
  final List<Map<String, String>> materiais = [];
  final List<Map<String, String>> parcelasFinanceiras = [];
  final List<Map<String, String>> materiaisUsadosNoAtendimento = [];

  String materialSelecionadoAtendimento = 'Selecione';
  final quantidadeMaterialUsadoController = TextEditingController();

  final materialNomeController = TextEditingController();
  final materialQuantidadeController = TextEditingController();
  final materialCustoController = TextEditingController();
  final materialMinimoController = TextEditingController();
  String filtroAlmoxarifado = 'Todos';
  final buscaAlmoxarifadoController = TextEditingController();

  Map<String, String>? gestanteSelecionada;
  Set<Marker> marcadores = {};

  bool carregandoMapa = false;
  bool mapaJaCarregado = false;

  Map<String, String>? gestanteProntuarioSelecionada;

  final nomeGestante = TextEditingController();
  final cpfGestante = TextEditingController();
  final telefoneGestante = TextEditingController();
  final emailGestante = TextEditingController();
  final enderecoGestante = TextEditingController();
  final numeroGestante = TextEditingController();
  final complementoGestante = TextEditingController();
  final bairroGestante = TextEditingController();
  final cidadeGestante = TextEditingController();
  final estadoGestante = TextEditingController();
  final cepGestante = TextEditingController();
  final hospitalGestante = TextEditingController();
  final obstetraGestante = TextEditingController();
  final convenioGestante = TextEditingController();

  final eoNomeController = TextEditingController();
  final eoTelefoneController = TextEditingController();
  final eoEmailController = TextEditingController();
  final eoCorenController = TextEditingController();
  final eoEspecialidadeController = TextEditingController();

  final obNomeController = TextEditingController();
  final obTelefoneController = TextEditingController();
  final obEmailController = TextEditingController();
  final obCrmController = TextEditingController();
  final obEspecialidadeController = TextEditingController();

  final nomePai = TextEditingController();
  final cpfPai = TextEditingController();
  final telefonePai = TextEditingController();
  final emailPai = TextEditingController();

  final dppController = TextEditingController();
  final dppCalculadoraController = TextEditingController();

  final nomeBebe = TextEditingController();
  final dataNascimento = TextEditingController();
  final igAoNascer = TextEditingController();
  final pesoBebe = TextEditingController();
  final observacoesBebe = TextEditingController();

  final entradaController = TextEditingController();
  final parcelasPagasController = TextEditingController();

  final atendimentoKmController = TextEditingController();
  final atendimentoValorKmController = TextEditingController();
  final atendimentoObservacaoController = TextEditingController();

  String sexo = 'Não informado';
  String viaNascimento = 'Não informado';
  String goldenHour = 'Não informado';
  String amamentacao = 'Não informado';

  String plano = '';
  String planoIdSelecionado = '';
  String descricaoNfsePlano = '';
  String descontoPercentual = '0%';
  String parcelas = '1';
  String consultorio = 'Não';
  String formaPagamento = 'Pix';

  final listaHospitais = [
    'Selecione',
    'Maternidade Santa Brígida',
    'Maternidade Curitiba',
    'Hospital Santa Cruz',
    'Hospital Nossa Senhora das Graças',
    'Hospital e Maternidade São José',
    'Outro',
  ];

  final listaObstetras = ['Selecione', 'Dra. Maressa', 'Dra. Tuane', 'Outro'];

  final listaConvenios = [
    'Selecione',
    'Particular',
    'Unimed',
    'Bradesco Saúde',
    'SulAmérica',
    'Amil',
    'Outro',
  ];

  int mesSelecionado = DateTime.now().month;
  int anoSelecionado = DateTime.now().year;

  String filtroFinanceiro = 'Todos';

  String atendimentoGestante = 'Selecione';
  String atendimentoTipo = 'Pré-natal';

  String contracaoGestanteSelecionada = 'Selecione';
  final buscaContracoesController = TextEditingController();
  String intensidadeContracao = 'Moderada';

  DateTime? inicioContracao;
  DateTime? fimUltimaContracao;

  final List<Map<String, String>> contracoes = [];

  final observacaoContracaoController = TextEditingController();

  final List<Map<String, dynamic>> planosCadastrados = [];

  final planoNomeController = TextEditingController();
  final planoValorController = TextEditingController();
  final planoParcelasController = TextEditingController(text: '1');
  final planoDescricaoComercialController = TextEditingController();
  final planoDescricaoNfseController = TextEditingController();

  final telefoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final dataMask = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final cepMask = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // ── Lote 2c: regras movidas para lib/gestantes/gestantes_regras.dart ──

  String statusGestanteNormalizado(Map<String, String> g) =>
      gregras.statusGestanteNormalizado(g);

  bool gestanteEstaAtiva(Map<String, String> g) => gregras.gestanteEstaAtiva(g);

  bool gestanteApareceNaBusca(Map<String, String> g, String busca) =>
      gregras.gestanteApareceNaBusca(g, busca);

  List<Map<String, String>> gestantesAtivasParaDocumentos() =>
      gregras.gestantesAtivas(gestantes);

  bool gestanteAtivaParaContracoes(Map<String, String> g) =>
      gregras.gestanteAtivaParaContracoes(g);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return PremiumNatusBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: isMobile
            ? Drawer(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                child: menuLateral(),
              )
            : null,
        body: isMobile
            ? Builder(
                builder: (context) {
                  return Stack(
                    children: [
                      telaConteudo(),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: Material(
                            color: NatusApp.offWhite.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Scaffold.of(context).openDrawer(),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: NatusApp.offWhite.withValues(
                                      alpha: 0.84,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.menu_rounded,
                                  color: NatusApp.vinho,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Row(
                children: [
                  menuLateral(),
                  Expanded(child: telaConteudo()),
                ],
              ),
      ),
    );
  }

  Widget cardProgressoGestacional({
    required int semanas,
    required double progresso,
  }) {
    final percentual = (progresso * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: NatusApp.rose,
                child: Icon(Icons.favorite, color: NatusApp.vinho),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresso da gestação',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: NatusApp.vinho,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      semanas > 0
                          ? '$semanas de 40 semanas completas'
                          : 'DPP ainda não informada',
                      style: TextStyle(
                        fontSize: 14,
                        color: NatusApp.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$percentual%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 18,
              backgroundColor: const Color(0xFFFFEFEA),
              valueColor: AlwaysStoppedAnimation<Color>(NatusApp.vinho),
            ),
          ),
        ],
      ),
    );
  }

  Widget menuLateral() {
    final menusPermitidos = {
      'superAdmin': [
        'Dashboard SaaS',
        'Clínicas cadastradas SaaS',
        'Usuários/clientes SaaS',
        'Mensalidades atrasadas SaaS',
        'Financeiro das assinaturas SaaS',
        'Criação de clínica/admin/enfermeira SaaS',
        'Crescimento de usuários por período SaaS',
      ],
      'admin': [
        'Dashboard',
        'Agenda',
        'Mapa',
        'Cadastro',
        'Gestantes',
        'Prontuário',
        'Calculadora de IG',
        'Contrações',
        'Financeiro',
        'Planos da Natus',
        'Almoxarifado',
        'Biblioteca',
        'Documentos',
        'Exames',
        'Usuários',
        'Cadastrar EO',
        'Cadastrar Obstetra',
        'Configurações',
      ],
      'enfermeira': [
        'Dashboard',
        'Agenda',
        'Mapa',
        'Gestantes',
        'Prontuário',
        'Calculadora de IG',
        'Contrações',
        'Biblioteca',
        'Exames',
      ],
      'gestante': [
        'Área da gestante',
        'Agenda',
        'Biblioteca',
        'Exames',
        'Documentos',
        'Contrações',
      ],
    };

    // Obstetra compartilha o mesmo menu operacional da enfermeira.
    final chaveMenus = tipoEhProfissionalClinica(widget.tipoUsuario)
        ? 'enfermeira'
        : widget.tipoUsuario;

    final menusDoUsuario = menusPermitidos[chaveMenus] ?? [];

    Widget logoutFixo() {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            NatusTema.restaurarPadrao();
            await FirebaseAuth.instance.signOut();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sair',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final itensVisiveis = <Widget>[
      if (menusDoUsuario.contains('Dashboard SaaS'))
        itemMenu(Icons.dashboard_rounded, 'Dashboard SaaS'),
      if (menusDoUsuario.contains('Clínicas cadastradas SaaS'))
        itemMenu(Icons.apartment_rounded, 'Clínicas cadastradas SaaS'),
      if (menusDoUsuario.contains('Usuários/clientes SaaS'))
        itemMenu(Icons.people_alt_rounded, 'Usuários/clientes SaaS'),
      if (menusDoUsuario.contains('Mensalidades atrasadas SaaS'))
        itemMenu(Icons.warning_amber_rounded, 'Mensalidades atrasadas SaaS'),
      if (menusDoUsuario.contains('Financeiro das assinaturas SaaS'))
        itemMenu(Icons.payments_rounded, 'Financeiro das assinaturas SaaS'),
      if (menusDoUsuario.contains('Criação de clínica/admin/enfermeira SaaS'))
        itemMenu(
          Icons.add_business_rounded,
          'Criação de clínica/admin/enfermeira SaaS',
        ),
      if (menusDoUsuario.contains('Crescimento de usuários por período SaaS'))
        itemMenu(
          Icons.trending_up_rounded,
          'Crescimento de usuários por período SaaS',
        ),
      if (menusDoUsuario.contains('Dashboard'))
        itemMenu(Icons.dashboard, 'Dashboard'),
      if (menusDoUsuario.contains('Agenda'))
        itemMenu(Icons.calendar_month_rounded, 'Agenda'),
      if (menusDoUsuario.contains('Mapa')) itemMenu(Icons.map, 'Mapa'),
      if (menusDoUsuario.contains('Cadastro'))
        itemMenu(Icons.person_add_alt_1, 'Cadastro'),
      if (menusDoUsuario.contains('Gestantes'))
        itemMenu(Icons.pregnant_woman, 'Gestantes'),
      if (menusDoUsuario.contains('Calculadora de IG'))
        itemMenu(Icons.calculate, 'Calculadora de IG'),
      if (menusDoUsuario.contains('Atendimentos'))
        itemMenu(Icons.medical_services, 'Atendimentos'),
      if (menusDoUsuario.contains('Contrações'))
        itemMenu(Icons.timer, 'Contrações'),
      if (menusDoUsuario.contains('Financeiro'))
        itemMenu(Icons.payments, 'Financeiro'),
      if (menusDoUsuario.contains('Planos da Natus'))
        itemMenu(Icons.workspace_premium_rounded, 'Planos da Natus'),
      if (menusDoUsuario.contains('NFS-e'))
        itemMenu(Icons.receipt_long_rounded, 'NFS-e'),
      if (menusDoUsuario.contains('Histórico Fiscal'))
        itemMenu(Icons.history_edu_rounded, 'Histórico Fiscal'),
      if (menusDoUsuario.contains('Almoxarifado'))
        itemMenu(Icons.inventory, 'Almoxarifado'),
      if (menusDoUsuario.contains('Centro de custo'))
        itemMenu(Icons.account_balance_wallet, 'Centro de custo'),
      if (menusDoUsuario.contains('Biblioteca'))
        itemMenu(Icons.menu_book, 'Biblioteca'),
      if (menusDoUsuario.contains('Prontuário'))
        itemMenu(Icons.assignment, 'Prontuário'),
      if (menusDoUsuario.contains('Documentos'))
        itemMenu(Icons.description, 'Documentos'),
      if (menusDoUsuario.contains('Exames')) itemMenu(Icons.biotech, 'Exames'),
      if (menusDoUsuario.contains('Cadastrar EO'))
        itemMenu(Icons.medical_information, 'Cadastrar EO'),
      if (menusDoUsuario.contains('Cadastrar Obstetra'))
        itemMenu(Icons.medical_services, 'Cadastrar Obstetra'),
      if (menusDoUsuario.contains('Usuários'))
        itemMenu(Icons.people, 'Usuários'),
      if (menusDoUsuario.contains('Área da gestante'))
        itemMenu(Icons.person, 'Área da gestante'),
      if (menusDoUsuario.contains('Configurações'))
        itemMenu(Icons.settings, 'Configurações'),
    ];

    return Container(
      width: 292,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NatusApp.menuTopo, NatusApp.menuMeio, NatusApp.menuBase],
          stops: [0.0, 0.48, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -94,
            top: -8,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.branchHero,
              width: 285,
              opacity: 0.28,
            ),
          ),
          const Positioned(
            left: -98,
            top: 230,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.branchTall,
              width: 270,
              opacity: 0.20,
              rotation: -0.10,
            ),
          ),
          const Positioned(
            right: -104,
            top: 392,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.branchAccent,
              width: 260,
              opacity: 0.18,
              rotation: 0.18,
            ),
          ),
          const Positioned(
            left: -82,
            bottom: 110,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.branchCornerLeft,
              width: 270,
              opacity: 0.22,
            ),
          ),
          const Positioned(
            right: -72,
            bottom: 12,
            child: NatusBotanicalAsset(
              asset: NatusBotanicalAssets.branchFine,
              width: 210,
              opacity: 0.16,
            ),
          ),
          Positioned(
            left: -110,
            top: 150,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NatusApp.olivaSeco.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: -120,
            bottom: 245,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NatusApp.douradoSuave.withValues(alpha: 0.10),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 30, 8, 22),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: NatusLogo(
                      color: NatusApp.sobreMarca,
                      fit: BoxFit.fitHeight,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: itensVisiveis,
                  ),
                ),
                logoutFixo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget itemMenu(IconData icone, String titulo) {
    final ativo = telaAtual == titulo;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            final isMobile = MediaQuery.of(context).size.width < 700;

            if (isMobile) {
              Navigator.pop(context);
            }

            setState(() {
              telaAtual = titulo;
              gestanteSelecionada = null;
              if (titulo == 'Gestantes') {
                filtroDashboardPacientes = null;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: ativo
                  ? NatusApp.offWhite.withValues(alpha: 0.96)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ativo
                    ? Colors.white.withValues(alpha: 0.42)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ativo
                        ? NatusApp.marsala.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icone,
                    size: 20,
                    color: ativo ? NatusApp.marsala : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
                      color: ativo
                          ? NatusApp.marsala
                          : Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget telaCadastrarEO() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cadastrar EO',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Cadastre enfermeiras obstétricas que fazem parte da equipe Natus.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          bloco('Dados da enfermeira obstétrica', [
            campo(eoNomeController, 'Nome'),

            const SizedBox(height: 16),

            campo(eoTelefoneController, 'Telefone'),

            const SizedBox(height: 16),

            campo(eoEmailController, 'E-mail'),

            const SizedBox(height: 16),

            campo(eoCorenController, 'COREN'),

            const SizedBox(height: 16),

            campo(eoEspecialidadeController, 'Especialidade'),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: salvarEO,
              icon: const Icon(Icons.save),
              label: const Text('Salvar enfermeira'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NatusApp.vinho,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget telaCadastrarObstetra() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cadastrar Obstetra',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Cadastre os obstetras que acompanham as gestantes da clínica.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          bloco('Dados do obstetra', [
            campo(obNomeController, 'Nome'),

            const SizedBox(height: 16),

            campo(obTelefoneController, 'Telefone'),

            const SizedBox(height: 16),

            campo(obEmailController, 'E-mail'),

            const SizedBox(height: 16),

            campo(obCrmController, 'CRM'),

            const SizedBox(height: 16),

            campo(obEspecialidadeController, 'Especialidade'),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: salvarObstetra,
              icon: const Icon(Icons.save),
              label: const Text('Salvar obstetra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NatusApp.vinho,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget telaConteudo() {
    switch (telaAtual) {
      case 'Dashboard SaaS':
      case 'Clínicas cadastradas SaaS':
      case 'Usuários/clientes SaaS':
      case 'Mensalidades atrasadas SaaS':
      case 'Financeiro das assinaturas SaaS':
      case 'Criação de clínica/admin/enfermeira SaaS':
      case 'Crescimento de usuários por período SaaS':
        return SuperAdminRouter.tela(telaAtual);

      case 'Dashboard':
        return telaDashboard();

      case 'Agenda':
        return AgendaPage(
          gestantes: gestantes,
          enfermeiras: enfermeiras,
          tipoUsuario: widget.tipoUsuario,
        );

      case 'Mapa':
        return telaMapa();

      case 'Calculadora de IG':
        return telaCalculadoraIg();

      case 'Cadastro':
        return telaCadastroGestante();

      case 'Gestantes':
        if (gestanteSelecionada != null) {
          return telaFichaGestanteTempoReal(gestanteSelecionada!);
        }
        return telaGestantes();

      case 'Atendimentos':
        return telaAtendimentos();

      case 'Contrações':
        return telaContracoes();

      case 'Financeiro':
        return telaFinanceiro();

      case 'Planos da Natus':
        return telaPlanosNatus();

      case 'NFS-e':
        return telaCentralNfse();

      case 'Histórico Fiscal':
        return telaHistoricoFiscalNfse();

      case 'Almoxarifado':
        return telaAlmoxarifado();

      case 'Centro de custo':
        return telaCentroDeCusto();

      case 'Biblioteca':
        return telaBiblioteca();

      case 'Prontuário':
        return telaProntuario();

      case 'Documentos':
        return telaDocumentos();

      case 'Exames':
        return telaExamesGestante();

      case 'Usuários':
        return telaUsuarios();

      case 'Cadastrar EO':
        return telaCadastrarEO();

      case 'Cadastrar Obstetra':
        return telaCadastrarObstetra();

      case 'Área da gestante':
        return telaAreaGestante();

      case 'Configurações':
        return telaConfiguracoes();

      default:
        return telaSimples('Tela não encontrada');
    }
  }

  Widget telaExamesGestante() {
    final usuarioGestante = widget.tipoUsuario == 'gestante';

    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

    final gestante = gestantes.firstWhere(
      (g) => g['uidGestante'] == uidLogado,
      orElse: () => {},
    );

    final idGestante = gestante['id'];

    if (usuarioGestante && (idGestante == null || idGestante.isEmpty)) {
      return telaSimples('Gestante não identificada para exibir exames.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            usuarioGestante ? 'Exames' : 'Central de exames',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            usuarioGestante
                ? 'Envie e acompanhe seus exames.'
                : 'Visualize os exames enviados pelas gestantes.',
            style: TextStyle(color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          if (usuarioGestante)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: NatusApp.offWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: NatusApp.rose.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: NatusApp.vinhoProfundo.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: NatusApp.rose,
                    child: Icon(Icons.upload_file, color: NatusApp.vinho),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enviar novo exame',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: NatusApp.vinho,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Arquivos armazenados com segurança.',
                          style: TextStyle(color: NatusApp.textoSuave),
                        ),
                      ],
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: () => selecionarArquivoExame(idGestante),
                    icon: const Icon(Icons.add),
                    label: const Text('Enviar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NatusApp.vinho,
                      foregroundColor: (NatusApp.escuro
                          ? NatusApp.fundo
                          : NatusApp.offWhite),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          StreamBuilder<QuerySnapshot>(
            stream: usuarioGestante
                ? firestore
                      .collection('exames')
                      .where('idGestante', isEqualTo: idGestante)
                      .snapshots()
                : firestore.collection('exames').snapshots(),

            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final exames = snapshot.data!.docs;

              if (exames.isEmpty) {
                return blocoFicha(
                  usuarioGestante ? 'Meus exames' : 'Exames das gestantes',
                  [const Text('Nenhum exame encontrado.')],
                );
              }

              Map<String, List<QueryDocumentSnapshot>> examesAgrupados = {};

              for (var exame in exames) {
                final dados = exame.data() as Map<String, dynamic>;

                final nomeGestante =
                    dados['nomeGestante'] ?? 'Gestante não identificada';

                examesAgrupados.putIfAbsent(nomeGestante, () => []);

                examesAgrupados[nomeGestante]!.add(exame);
              }

              return blocoFicha(
                usuarioGestante
                    ? 'Meus exames (${exames.length})'
                    : 'Exames das gestantes (${exames.length})',
                [
                  ...examesAgrupados.entries.map((grupo) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!usuarioGestante)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 10),
                            child: Text(
                              grupo.key,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: NatusApp.vinho,
                              ),
                            ),
                          ),

                        ...grupo.value.map((doc) {
                          final dados = doc.data() as Map<String, dynamic>;

                          final nomeArquivo = dados['nomeArquivo'] ?? 'Exame';

                          final url = dados['url'] ?? '';

                          final criadoEm = dados['criadoEm'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: NatusApp.fundo,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: NatusApp.rose.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: NatusApp.offWhite,
                                  child: Icon(
                                    Icons.description,
                                    color: NatusApp.vinho,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nomeArquivo,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: NatusApp.vinho,
                                        ),
                                      ),

                                      if (criadoEm.toString().isNotEmpty)
                                        Text(
                                          'Enviado em: ${criadoEm.toString().substring(0, 10)}',
                                          style: TextStyle(
                                            color: NatusApp.textoSuave,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                IconButton(
                                  tooltip: 'Abrir exame',
                                  icon: Icon(
                                    Icons.open_in_new,
                                    color: NatusApp.vinho,
                                  ),
                                  onPressed: () => abrirArquivo(url),
                                ),

                                if (!usuarioGestante)
                                  IconButton(
                                    tooltip: 'Excluir exame',
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await excluirExame(doc.id, url);
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> excluirExame(String idExame, String urlArquivo) async {
    try {
      if (urlArquivo.isNotEmpty) {
        final ref = storage.refFromURL(urlArquivo);
        await ref.delete();
      }

      await firestore.collection('exames').doc(idExame).delete();

      setState(() {});

      mostrarMensagem('Exame excluído com sucesso.');
    } catch (e) {
      mostrarMensagem('Erro ao excluir exame: $e');
    }
  }

  Future<void> selecionarArquivoExame(String? idGestante) async {
    if (idGestante == null) {
      mostrarMensagem('Erro: gestante não identificada.');
      return;
    }

    final resultado = await FilePicker.platform.pickFiles();

    if (resultado == null) return;

    final arquivo = resultado.files.first;

    final nomeArquivo = arquivo.name;
    final bytes = arquivo.bytes;

    if (bytes == null) {
      mostrarMensagem('Erro ao ler arquivo.');
      return;
    }

    try {
      final nomeFinal = '${DateTime.now().millisecondsSinceEpoch}_$nomeArquivo';

      final ref = storage.ref().child('exames/$idGestante/$nomeFinal');

      await ref.putData(bytes);

      final url = await ref.getDownloadURL();

      await firestore.collection('exames').add({
        'idGestante': idGestante,
        'nomeArquivo': nomeArquivo,
        'url': url,
        'criadoEm': DateTime.now().toIso8601String(),
      });

      mostrarMensagem('Exame enviado com sucesso!');
    } catch (e) {
      mostrarMensagem('Erro ao enviar exame: $e');
    }
  }

  Widget cardKPI(String titulo, String valor, IconData icone) =>
      NatusCardKpi(titulo, valor, icone);

  // ── Lote 2c: lógica movida para gestantes_regras.dart e kpis_calculos.dart ──

  DateTime? converterDataDashboard(String? valor) =>
      gregras.converterDataDashboard(valor);

  String primeiraDataPreenchida(
    Map<String, String> dados,
    List<String> campos,
  ) => gregras.primeiraDataPreenchida(dados, campos);

  int contarBebesPorAno(String ano) => kpis.contarBebesPorAno(gestantes, ano);

  Map<int, int> contarBebesPorMes(String ano) =>
      kpis.contarBebesPorMes(gestantes, ano);

  kpis.CrescimentoNascimentosKpis calcularCrescimentoNascimentos() =>
      kpis.calcularCrescimentoNascimentos(gestantes);

  kpis.ObstetraMetricasCompletas metricasDoObstetraLogado() =>
      kpis.calcularMetricasObstetra(gestantes, nomeEoLogada());

  List<kpis.ObstetraMetricasCompletas> metricasDeTodosObstetras() =>
      kpis.calcularMetricasTodosObstetras(gestantes, obstetras);

  int contarBebesNoPeriodoSelecionado() => kpis.contarBebesNoPeriodoSelecionado(
    gestantes,
    mesSelecionado,
    anoSelecionado,
  );

  int contarEncerradasOuHistoricoNoPeriodoDpp() =>
      kpis.contarEncerradasOuHistoricoNoPeriodoDpp(
        gestantes,
        mesSelecionado,
        anoSelecionado,
      );

  Map<int, int> contarGestantesPorMes(String ano) =>
      kpis.contarGestantesPorMes(gestantes, ano);

  int contarGestantesPorStatus(String status) =>
      kpis.contarGestantesPorStatus(gestantes, status);

  bool gestanteEhDoPeriodoSelecionadoPelaDpp(Map<String, String> g) => kpis
      .gestanteEhDoPeriodoSelecionadoPelaDpp(g, mesSelecionado, anoSelecionado);

  int contarGestantesPorStatusNoPeriodoDpp(String status) =>
      kpis.contarGestantesPorStatusNoPeriodoDpp(
        gestantes,
        status,
        mesSelecionado,
        anoSelecionado,
      );

  int contarGestantesProximasDpp() =>
      kpis.contarGestantesProximasDpp(gestantes);

  int diasParaDpp(String dpp) => gregras.diasParaDpp(dpp);

  Widget alertaDpp(Map<String, String> g) => NatusAlertaDpp(g);

  int contarMateriaisBaixo() {
    int total = 0;

    for (var m in materiais) {
      final quantidade = int.tryParse(m['quantidade'] ?? '0') ?? 0;
      final minimo = int.tryParse(m['minimo'] ?? '0') ?? 0;

      if (quantidade <= minimo) {
        total++;
      }
    }

    return total;
  }

  // ── Lote 2b: lógica movida para lib/financeiro/financeiro_calculos.dart.
  // Wrappers finos preservam os call sites; serão removidos no Lote 2f
  // quando as telas chamarem o módulo diretamente. ──

  double calcularSaldoAReceber() => fincalc.calcularSaldoAReceber(gestantes);

  double calcularValorRecebido() => fincalc.calcularValorRecebido(gestantes);

  double calcularValorAReceberReal() => fincalc.calcularValorAReceberReal(
    parcelasFinanceiras,
    mesSelecionado,
    anoSelecionado,
  );

  bool parcelaEhDoMesAtual(Map<String, String> parcela) =>
      fincalc.parcelaEhDoMesAtual(parcela);

  bool parcelaEhDoMesSelecionado(Map<String, String> parcela) => fincalc
      .parcelaEhDoMesSelecionado(parcela, mesSelecionado, anoSelecionado);

  bool parcelaEstaAtrasada(Map<String, String> parcela) =>
      fincalc.parcelaEstaAtrasada(parcela);

  double calcularValorRecebidoMesAtual() =>
      fincalc.calcularValorRecebidoMesAtual(
        parcelasFinanceiras,
        mesSelecionado,
        anoSelecionado,
      );

  double calcularValorAtrasadoMesAtual() =>
      fincalc.calcularValorAtrasadoMesAtual(
        parcelasFinanceiras,
        mesSelecionado,
        anoSelecionado,
      );

  int contarParcelasAtrasadasMesSelecionado() =>
      fincalc.contarParcelasAtrasadasMesSelecionado(
        parcelasFinanceiras,
        mesSelecionado,
        anoSelecionado,
      );

  double calcularTotalPrevistoMesSelecionado() =>
      fincalc.calcularTotalPrevistoMesSelecionado(
        parcelasFinanceiras,
        mesSelecionado,
        anoSelecionado,
      );

  double calcularPercentualInadimplencia() =>
      fincalc.calcularPercentualInadimplencia(
        parcelasFinanceiras,
        mesSelecionado,
        anoSelecionado,
      );

  Color corInadimplencia(double valor) => fincalc.corInadimplencia(valor);

  String formatarDataFinanceira(DateTime data) =>
      fincalc.formatarDataFinanceira(data);

  String gerarVencimentoEntrada() => fincalc.gerarVencimentoEntrada();

  String gerarVencimentoParcela(int numeroParcela) =>
      fincalc.gerarVencimentoParcela(numeroParcela);

  String gerarVencimentoParcelaHistorico(
    int numeroParcela,
    int parcelasPagas,
  ) => fincalc.gerarVencimentoParcelaHistorico(numeroParcela, parcelasPagas);

  DateTime calcularQuintoDiaUtil(int ano, int mes) =>
      fincalc.calcularQuintoDiaUtil(ano, mes);

  Map<String, int> contarAmamentacao() {
    Map<String, int> dados = {'AME': 0, 'Mista': 0, 'Fórmula': 0};

    for (var g in gestantes) {
      String tipo = g['amamentacao'] ?? '';

      tipo = tipo.trim().toLowerCase();

      if (tipo.isEmpty) continue;

      if (tipo.contains('ame') ||
          tipo.contains('exclusiva') ||
          tipo.contains('aleitamento materno exclusivo')) {
        dados['AME'] = dados['AME']! + 1;
      } else if (tipo.contains('mista') ||
          tipo.contains('mist') ||
          tipo.contains('complemento') ||
          tipo.contains('complementar')) {
        dados['Mista'] = dados['Mista']! + 1;
      } else if (tipo.contains('formula') ||
          tipo.contains('fórmula') ||
          tipo.contains('leite artificial') ||
          tipo.contains('artificial')) {
        dados['Fórmula'] = dados['Fórmula']! + 1;
      }
    }

    return dados;
  }

  Map<String, int> contarCampoGestantes(String campo) {
    Map<String, int> dados = {};

    for (var g in gestantes) {
      String valor = g[campo] ?? '';

      valor = valor.trim();

      if (valor.isEmpty) continue;
      if (valor.toLowerCase() == 'selecione') continue;
      if (valor.toLowerCase() == 'não informado') continue;
      if (valor.toLowerCase() == 'nao informado') continue;

      valor = valor.replaceAll(RegExp(r'\s+'), ' ');

      final chaveNormalizada = valor.toLowerCase();

      final chaveExistente = dados.keys.firstWhere(
        (k) => k.toLowerCase() == chaveNormalizada,
        orElse: () => valor,
      );

      dados[chaveExistente] = (dados[chaveExistente] ?? 0) + 1;
    }

    return dados;
  }

  Map<String, int> contarViaNascimento() {
    final dados = {
      'Normal': 0,
      'Cesárea': 0,
      'Domiciliar': 0,
      'Não informado': 0,
    };

    for (var g in gestantes) {
      final via = normalizarViaNascimentoDashboard(g['viaNascimento']);
      dados[via] = (dados[via] ?? 0) + 1;
    }

    return dados;
  }

  Map<String, int> contarRiscoGestacional() {
    final dados = {'Habitual': 0, 'Intermediário': 0, 'Alto Risco': 0};

    for (var g in gregras.gestantesAtivas(gestantes)) {
      final risco = (g['riscoGestacional'] ?? '').trim().toLowerCase();

      if (risco.contains('alto')) {
        dados['Alto Risco'] = dados['Alto Risco']! + 1;
      } else if (risco.contains('inter')) {
        dados['Intermediário'] = dados['Intermediário']! + 1;
      } else if (risco.contains('habit')) {
        dados['Habitual'] = dados['Habitual']! + 1;
      }
    }

    return dados;
  }

  Map<String, int> contarDiabetesGestacional() {
    final dados = {'Sim': 0, 'Não': 0};

    for (var g in gregras.gestantesAtivas(gestantes)) {
      final dg = (g['diabetesGestacional'] ?? '').trim().toLowerCase();

      if (dg.startsWith('sim')) {
        dados['Sim'] = dados['Sim']! + 1;
      } else if (dg.startsWith('não') || dg.startsWith('nao')) {
        dados['Não'] = dados['Não']! + 1;
      }
    }

    return dados;
  }

  List<Map<String, String>> materiaisComEstoqueBaixo() {
    return materiais.where((m) {
      final quantidade = int.tryParse(m['quantidade'] ?? '0') ?? 0;
      final minimo = int.tryParse(m['minimo'] ?? '0') ?? 0;

      return quantidade <= minimo;
    }).toList();
  }

  Widget cardAlertaDashboard(
    String titulo,
    String valor,
    IconData icone,
    Color cor, {
    VoidCallback? onTap,
  }) => NatusCardAlertaDashboard(titulo, valor, icone, cor, onTap: onTap);

  Widget cardFinanceiroResumo(
    String titulo,
    double valor,
    Color cor,
    IconData icone, {
    String sufixo = '',
    VoidCallback? onTap,
  }) => NatusCardFinanceiroResumo(
    titulo,
    valor,
    cor,
    icone,
    sufixo: sufixo,
    onTap: onTap,
  );

  Widget cardContagemResumo(
    String titulo,
    int valor,
    Color cor,
    IconData icone, {
    VoidCallback? onTap,
  }) => NatusCardContagemResumo(titulo, valor, cor, icone, onTap: onTap);

  void abrirPacientesDoDashboard(FiltroDashboardPacientes filtro) {
    setState(() {
      filtroDashboardPacientes = filtro;
      filtroStatusGestante = 'Todas';
      buscaGestantesController.clear();
      gestanteSelecionada = null;
      telaAtual = 'Gestantes';
    });
  }

  void limparFiltroDashboardPacientes() {
    setState(() {
      filtroDashboardPacientes = null;
    });
  }

  void abrirFinanceiroDoDashboard(String filtro) {
    setState(() {
      filtroFinanceiro = filtro;
      gestanteSelecionada = null;
      telaAtual = 'Financeiro';
    });
  }

  Widget cardResumo(
    String titulo,
    String valor,
    IconData icone, {
    Color? cor,
  }) => NatusCardResumo(titulo, valor, icone, cor: cor);

  Widget blocoDashboard(String titulo, List<Widget> filhos) =>
      NatusBlocoDashboard(titulo, filhos);

  Widget alertaDashboardFinanceiro() =>
      NatusAlertaDashboardFinanceiro(contarParcelasAtrasadasMesSelecionado());

  Widget cardIndicadorAmamentacao(
    String titulo,
    int valor,
    int total,
    Color cor,
  ) => NatusCardIndicadorAmamentacao(titulo, valor, total, cor);

  Widget cardMaternidadeRanking(String nome, int total) {
    return GestureDetector(
      onTap: () {
        setState(() {
          filtroMaternidade = nome;
          telaAtual = 'Gestantes';
          gestanteSelecionada = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Colors.blueGrey.withValues(alpha: 0.14),
              child: const Icon(
                Icons.local_hospital,
                size: 18,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nome,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              total.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: NatusApp.vinho,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget itemRanking(String nome, int total) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(nome, style: const TextStyle(fontSize: 16))),
          if (total > 0)
            Text(
              total.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: NatusApp.vinho,
              ),
            ),
        ],
      ),
    );
  }

  Widget cardRankingTop5({
    required int posicao,
    required String nome,
    required int total,
    required IconData icone,
    required Color cor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: cor.withValues(alpha: 0.15),
            child: Text(
              posicao.toString(),
              style: TextStyle(color: cor, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 12),

          Icon(icone, color: cor, size: 20),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$total',
              style: TextStyle(fontWeight: FontWeight.bold, color: cor),
            ),
          ),
        ],
      ),
    );
  }

  Widget podiumTop5({
    required List<MapEntry<String, int>> dados,
    required IconData icone,
    required Color cor,
    String rotulo = 'atendimentos',
    ValueChanged<String>? onSelecionar,
  }) {
    if (dados.isEmpty) {
      return const Text('Nenhum dado encontrado.');
    }

    final primeiro = dados[0];
    final segundo = dados.length > 1 ? dados[1] : null;
    final terceiro = dados.length > 2 ? dados[2] : null;
    final quarto = dados.length > 3 ? dados[3] : null;
    final quinto = dados.length > 4 ? dados[4] : null;

    final maximo = primeiro.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (segundo != null) ...[
                  podiumCard(
                    posicao: 2,
                    nome: segundo.key,
                    total: segundo.value,
                    icone: icone,
                    isMobile: isMobile,
                    rotulo: rotulo,
                    onTap: onSelecionar == null
                        ? null
                        : () => onSelecionar(segundo.key),
                  ),
                  SizedBox(width: isMobile ? 8 : 18),
                ],

                podiumCard(
                  posicao: 1,
                  nome: primeiro.key,
                  total: primeiro.value,
                  icone: icone,
                  isMobile: isMobile,
                  rotulo: rotulo,
                  onTap: onSelecionar == null
                      ? null
                      : () => onSelecionar(primeiro.key),
                ),

                if (terceiro != null) ...[
                  SizedBox(width: isMobile ? 8 : 18),
                  podiumCard(
                    posicao: 3,
                    nome: terceiro.key,
                    total: terceiro.value,
                    icone: icone,
                    isMobile: isMobile,
                    rotulo: rotulo,
                    onTap: onSelecionar == null
                        ? null
                        : () => onSelecionar(terceiro.key),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                if (quarto != null)
                  Expanded(
                    child: miniRankingCard(
                      posicao: '4º',
                      nome: quarto.key,
                      total: quarto.value,
                      maximo: maximo,
                      cor: cor,
                      onTap: onSelecionar == null
                          ? null
                          : () => onSelecionar(quarto.key),
                    ),
                  ),

                if (quarto != null && quinto != null) const SizedBox(width: 12),

                if (quinto != null)
                  Expanded(
                    child: miniRankingCard(
                      posicao: '5º',
                      nome: quinto.key,
                      total: quinto.value,
                      maximo: maximo,
                      cor: cor,
                      onTap: onSelecionar == null
                          ? null
                          : () => onSelecionar(quinto.key),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget podiumCard({
    required int posicao,
    required String nome,
    required int total,
    required IconData icone,
    required bool isMobile,
    String rotulo = 'atendimentos',
    VoidCallback? onTap,
  }) {
    final ouro = posicao == 1;

    // Ouro, prata e bronze traduzidos para a paleta ativa.
    final cor = switch (posicao) {
      1 => NatusApp.douradoEscuro,
      2 => NatusApp.textoSuave,
      _ => NatusApp.rose,
    };

    final alturaDegrau = switch (posicao) {
      1 => isMobile ? 54.0 : 72.0,
      2 => isMobile ? 36.0 : 48.0,
      _ => isMobile ? 26.0 : 34.0,
    };

    final largura = ouro
        ? (isMobile ? 116.0 : 190.0)
        : (isMobile ? 100.0 : 174.0);

    final card = SizedBox(
      width: largura,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ouro) ...[
            Icon(Icons.workspace_premium, color: NatusApp.dourado, size: 30),
            const SizedBox(height: 4),
          ],

          // Card de conteúdo: altura livre — nunca estoura.
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 14,
              vertical: isMobile ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border.all(
                color: cor.withValues(alpha: ouro ? 0.9 : 0.45),
                width: ouro ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cor.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: ouro ? 20 : 16,
                  backgroundColor: cor.withValues(alpha: 0.14),
                  child: Icon(icone, color: cor, size: ouro ? 20 : 16),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  height: isMobile ? 42 : 50,
                  child: Center(
                    child: Tooltip(
                      message: nome,
                      child: Text(
                        nome,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile
                              ? (ouro ? 11.5 : 10.5)
                              : (ouro ? 14 : 13),
                          color: NatusApp.texto,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '$total',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: ouro ? 22 : 17,
                    color: cor,
                  ),
                ),

                Text(
                  rotulo,
                  style: TextStyle(fontSize: 10.5, color: NatusApp.textoSuave),
                ),
              ],
            ),
          ),

          // Degrau do pódio: a altura conta a história do ranking.
          Container(
            width: double.infinity,
            height: alturaDegrau,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cor.withValues(alpha: ouro ? 0.85 : 0.55),
                  cor.withValues(alpha: ouro ? 0.6 : 0.35),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$posicaoº',
              style: TextStyle(
                color: NatusApp.offWhite,
                fontWeight: FontWeight.w800,
                fontSize: ouro ? 18 : 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }

  Widget miniRankingCard({
    required String posicao,
    required String nome,
    required int total,
    required int maximo,
    required Color cor,
    VoidCallback? onTap,
  }) {
    final proporcao = maximo <= 0 ? 0.0 : (total / maximo).clamp(0.0, 1.0);

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cor.withValues(alpha: 0.12),
            child: Text(
              posicao,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: nome,
                        child: Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NatusApp.texto,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      '$total',
                      style: TextStyle(
                        color: cor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: proporcao,
                    minHeight: 6,
                    backgroundColor: NatusApp.bege,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      cor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }

  Widget barraGrafico(String titulo, int valor, int total) {
    double largura = total == 0 ? 0 : valor / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$titulo: $valor'),
          const SizedBox(height: 4),
          Container(
            height: 18,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFEA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: largura,
              child: Container(
                decoration: BoxDecoration(
                  color: NatusApp.vinho,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget barraFinanceiraBonita(
    String titulo,
    double valor,
    double total,
    Color cor,
    IconData icone,
  ) {
    final percentual = total == 0 ? 0.0 : valor / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: cor.withValues(alpha: 0.15),
                child: Icon(icone, size: 18, color: cor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formatarMoeda(valor),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: percentual,
              minHeight: 18,
              backgroundColor: const Color(0xFFFFEFEA),
              valueColor: AlwaysStoppedAnimation<Color>(cor),
            ),
          ),
        ],
      ),
    );
  }

  Widget graficoPizzaAmamentacao() {
    final dados = contarAmamentacao();
    final isMobile = MediaQuery.of(context).size.width < 700;

    final ame = (dados['AME'] ?? 0).toDouble();
    final mista = (dados['Mista'] ?? 0).toDouble();
    final formula = (dados['Fórmula'] ?? 0).toDouble();

    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 34,
          sections: [
            PieChartSectionData(
              value: ame == 0 ? 1 : ame,
              title: isMobile ? '' : 'AME',
              radius: 54,
              color: Colors.green,
              titleStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: NatusApp.offWhite,
              ),
            ),
            PieChartSectionData(
              value: mista == 0 ? 1 : mista,
              title: isMobile ? '' : 'Mista',
              radius: 54,
              color: Colors.orange,
              titleStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: NatusApp.offWhite,
              ),
            ),
            PieChartSectionData(
              value: formula == 0 ? 1 : formula,
              title: isMobile ? '' : 'Fórmula',
              radius: 54,
              color: Colors.red,
              titleStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: NatusApp.offWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget graficoLinhaBebes() {
    return graficoLinhaCrescimento(
      dados2026: contarBebesPorMes('2026'),
      dados2025: contarBebesPorMes('2025'),
    );
  }

  Widget graficoLinhaGestantes() {
    return graficoLinhaCrescimento(
      dados2026: contarGestantesPorMes('2026'),
      dados2025: contarGestantesPorMes('2025'),
    );
  }

  Widget graficoLinhaCrescimento({
    required Map<int, int> dados2026,
    required Map<int, int> dados2025,
  }) {
    final spots2026 = List.generate(12, (i) {
      final mes = i + 1;
      return FlSpot(mes.toDouble(), (dados2026[mes] ?? 0).toDouble());
    });

    final spots2025 = List.generate(12, (i) {
      final mes = i + 1;
      return FlSpot(mes.toDouble(), (dados2025[mes] ?? 0).toDouble());
    });

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: 12,
          minY: 0,
          gridData: FlGridData(show: true),

          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  const meses = [
                    'Jan',
                    'Fev',
                    'Mar',
                    'Abr',
                    'Mai',
                    'Jun',
                    'Jul',
                    'Ago',
                    'Set',
                    'Out',
                    'Nov',
                    'Dez',
                  ];

                  if (value.toInt() < 1 || value.toInt() > 12) {
                    return const SizedBox();
                  }

                  return Text(
                    meses[value.toInt() - 1],
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 1,
              ),
            ),
          ),

          borderData: FlBorderData(show: false),

          lineBarsData: [
            LineChartBarData(
              spots: spots2026,
              isCurved: true,
              color: NatusApp.vinho,
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
            LineChartBarData(
              spots: spots2025,
              isCurved: true,
              color: Colors.grey,
              barWidth: 2,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget legendaGrafico(String texto, Color cor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String mensagemGestacional(int semanas) {
    if (semanas <= 12) {
      return 'Uma fase de descobertas e transformações incríveis 💫';
    } else if (semanas <= 24) {
      return 'Seu bebê já está se desenvolvendo rapidamente 🧡';
    } else if (semanas <= 36) {
      return 'Cada semana agora é um passo mais perto do grande encontro 🤍';
    } else {
      return 'O momento mais esperado está chegando... prepare o coração ✨';
    }
  }

  Map<String, String> conteudoSemanaGestacional(int semanas) {
    // 🎯 SEMANAS ESPECÍFICAS
    if (semanas == 8) {
      return {
        'fase': 'Desenvolvimento inicial',
        'bebe':
            'Seu bebê já possui batimentos cardíacos e começa a formar braços e pernas.',
        'mamae': 'Enjoos, cansaço e sensibilidade são comuns nessa fase.',
        'dica': 'Alimente-se em pequenas porções e mantenha-se hidratada.',
      };
    }

    if (semanas == 12) {
      return {
        'fase': 'Fim do primeiro trimestre',
        'bebe':
            'Os órgãos principais já estão formados e o bebê começa a se movimentar.',
        'mamae':
            'Os enjoos tendem a diminuir e a energia pode começar a voltar.',
        'dica': 'Aproveite essa fase para se organizar e cuidar da sua rotina.',
      };
    }

    if (semanas == 20) {
      return {
        'fase': 'Metade da gestação',
        'bebe': 'Seu bebê já pode ouvir sons e responder a estímulos.',
        'mamae': 'Você pode começar a sentir movimentos mais claros do bebê.',
        'dica': 'Converse com o bebê e aproveite esse momento especial.',
      };
    }

    // 🔁 FALLBACK (GENÉRICO)
    if (semanas <= 12) {
      return {
        'fase': 'Primeiro trimestre',
        'bebe':
            'O bebê está em uma fase intensa de formação e desenvolvimento inicial.',
        'mamae':
            'É comum sentir mais sono, enjoo, sensibilidade e mudanças hormonais.',
        'dica': 'Descanse sempre que possível e mantenha sua hidratação.',
      };
    } else if (semanas <= 24) {
      return {
        'fase': 'Segundo trimestre',
        'bebe': 'O bebê cresce rapidamente e os movimentos começam a aparecer.',
        'mamae': 'Muitas gestantes sentem mais disposição nessa fase.',
        'dica': 'Aproveite para organizar exames e acompanhar sua evolução.',
      };
    } else if (semanas <= 36) {
      return {
        'fase': 'Terceiro trimestre',
        'bebe': 'O bebê ganha peso e se prepara para o nascimento.',
        'mamae': 'Pode haver mais cansaço e desconforto físico.',
        'dica': 'Prepare a mala da maternidade e mantenha acompanhamento.',
      };
    } else {
      return {
        'fase': 'Reta final',
        'bebe': 'O bebê está pronto para nascer a qualquer momento.',
        'mamae': 'Atenção aos sinais do corpo é essencial.',
        'dica': 'Mantenha contato com sua equipe de apoio.',
      };
    }
  }

  Widget cardTimelineGestacional(int semanas) {
    final conteudoSemana = conteudoSemanaGestacional(semanas);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NatusApp.douradoClaro.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACONTECE ESTA SEMANA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NatusApp.douradoEscuro,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            semanas > 0
                ? 'Semana $semanas • ${conteudoSemana['fase']}'
                : 'Semana gestacional',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: NatusApp.vinho,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 18),

          linhaTimelineGestacional(
            icone: '👶',
            titulo: 'Seu bebê',
            texto: conteudoSemana['bebe'] ?? '',
          ),

          const SizedBox(height: 16),

          linhaTimelineGestacional(
            icone: '🤰',
            titulo: 'Você pode sentir',
            texto: conteudoSemana['mamae'] ?? '',
          ),

          const SizedBox(height: 16),

          linhaTimelineGestacional(
            icone: '💡',
            titulo: 'Dica Natus',
            texto: conteudoSemana['dica'] ?? '',
          ),
        ],
      ),
    );
  }

  Widget linhaTimelineGestacional({
    required String icone,
    required String titulo,
    required String texto,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icone, style: const TextStyle(fontSize: 22)),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                texto,
                style: TextStyle(
                  fontSize: 15,
                  color: NatusApp.textoSuave,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget telaCalculadoraIg() {
    final dpp = dppCalculadoraController.text;
    final resultadoIg = calcularIdadeGestacional(dpp);
    final semanas = calcularSemanas(dpp);
    final fruta = frutaDaSemana(semanas);

    final temDppValida = dpp.length == 10 && semanas > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calculadora de IG',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Calcule a idade gestacional a partir da DPP e acompanhe a evolução do bebê.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          Container(
            constraints: const BoxConstraints(maxWidth: 760),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: NatusApp.vinhoProfundo.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: NatusApp.rose,
                      child: Icon(
                        Icons.pregnant_woman,
                        color: NatusApp.vinho,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Informe a data provável do parto',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: NatusApp.vinho,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                TextField(
                  controller: dppCalculadoraController,
                  inputFormatters: [dataMask],
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'DPP',
                    hintText: 'dd/mm/aaaa',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.calendar_month),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFEA),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: NatusApp.rose.withValues(alpha: 0.8),
                    ),
                  ),
                  child: temDppValida
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resultado da idade gestacional',
                              style: TextStyle(
                                fontSize: 13,
                                color: NatusApp.textoSuave,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              resultadoIg,
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: NatusApp.vinho,
                              ),
                            ),

                            const SizedBox(height: 18),

                            Row(
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Center(
                                    child: imagemGestacional(
                                      semanas: semanas,
                                      tamanho: 100,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                Expanded(
                                  child: Text(
                                    'Seu bebê está do tamanho de uma $fruta.\n\n${mensagemGestacional(semanas)}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: NatusApp.vinho,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            Text(
                              'Cada semana representa uma nova etapa de desenvolvimento. A Natus acompanha essa jornada com cuidado, acolhimento e segurança.',
                              style: TextStyle(
                                fontSize: 15,
                                color: NatusApp.textoSuave,
                                height: 1.4,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aguardando DPP',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: NatusApp.vinho,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Digite a data provável do parto no formato dd/mm/aaaa para visualizar a idade gestacional e a fruta da semana.',
                              style: TextStyle(
                                fontSize: 15,
                                color: NatusApp.textoSuave,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar cálculo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NatusApp.vinho,
                        foregroundColor: (NatusApp.escuro
                            ? NatusApp.fundo
                            : NatusApp.offWhite),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 17,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          dppCalculadoraController.clear();
                        });
                      },
                      icon: const Icon(Icons.cleaning_services),
                      label: const Text('Limpar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NatusApp.rose,
                        foregroundColor: NatusApp.vinho,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget telaCadastroGestante() {
    double valorPlano = valorPlanoAtual();
    double percentualDesconto = converterPercentual(descontoPercentual);
    double valorDesconto = valorPlano * percentualDesconto;
    double entrada = converterValor(entradaController.text);
    int qtdParcelas = int.parse(parcelas);

    double valorFinal = valorPlano - valorDesconto;
    if (valorFinal < 0) valorFinal = 0;

    double valorParcelado = valorFinal - entrada;
    if (valorParcelado < 0) valorParcelado = 0;

    double valorParcela = valorParcelado / qtdParcelas;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cadastro de Gestantes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: NatusApp.vinho,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preencha as informações da gestante para iniciar o acompanhamento',
                style: TextStyle(fontSize: 13, color: NatusApp.textoSuave),
              ),
              const SizedBox(height: 20),
            ],
          ),
          const SizedBox(height: 20),

          bloco('Gestante', [
            Row(
              children: [
                campo(nomeGestante, 'Nome da gestante'),
                const SizedBox(width: 12),
                campo(cpfGestante, 'CPF', mask: cpfMask),
                const SizedBox(width: 12),
                campo(telefoneGestante, 'Telefone', mask: telefoneMask),
                const SizedBox(width: 12),
                campo(emailGestante, 'E-mail'),
              ],
            ),

            Row(
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: cepGestante,
                    inputFormatters: [cepMask],
                    decoration: const InputDecoration(
                      labelText: 'CEP',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) async {
                      if (value.replaceAll(RegExp(r'[^0-9]'), '').length == 8) {
                        final resultado = await buscarEnderecoPorCep(value);

                        if (resultado != null) {
                          enderecoGestante.text = resultado['endereco'] ?? '';
                          bairroGestante.text = resultado['bairro'] ?? '';
                          cidadeGestante.text = resultado['cidade'] ?? '';
                          estadoGestante.text = resultado['estado'] ?? '';
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: campoBloqueadoFull(enderecoGestante, 'Endereço'),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(child: campoFull(numeroGestante, 'Número')),
                const SizedBox(width: 10),
                Expanded(child: campoFull(complementoGestante, 'Apto / Bloco')),
                const SizedBox(width: 10),
                Expanded(child: campoBloqueadoFull(bairroGestante, 'Bairro')),
                const SizedBox(width: 10),
                Expanded(child: campoBloqueadoFull(cidadeGestante, 'Cidade')),
                const SizedBox(width: 10),
                SizedBox(
                  width: 70,
                  child: campoBloqueadoFull(estadoGestante, 'UF'),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: dropdownGrande(
                    'Hospital / Maternidade',
                    hospitalGestante.text.isEmpty
                        ? 'Selecione'
                        : hospitalGestante.text,
                    listaHospitais,
                    (v) {
                      setState(() {
                        hospitalGestante.text = v;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                campo(obstetraGestante, 'Obstetra'),
                const SizedBox(width: 12),
                Expanded(
                  child: dropdownGrande(
                    'Convênio',
                    convenioGestante.text.isEmpty
                        ? 'Selecione'
                        : convenioGestante.text,
                    listaConvenios,
                    (v) {
                      setState(() {
                        convenioGestante.text = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ]),

          bloco('Pai', [
            campo(nomePai, 'Nome do pai'),
            campo(cpfPai, 'CPF do pai / responsável', mask: cpfMask),
            campo(telefonePai, 'Telefone do pai', mask: telefoneMask),
            campo(emailPai, 'E-mail do pai'),
          ]),

          bloco('Bebê', [
            campo(nomeBebe, 'Nome do bebê'),
            dropdown('Sexo', sexo, ['Masculino', 'Feminino', 'Não informado'], (
              v,
            ) {
              setState(() => sexo = v);
            }),
            campoDpp(),
            campoInfo('IG atual', calcularIdadeGestacional(dppController.text)),
          ]),

          bloco('Valores', [
            seletorPlanoGestante(),
            campoInfo('Valor do plano', formatarMoeda(valorPlano)),
            if (descricaoNfsePlano.trim().isNotEmpty)
              campoInfo('Descrição NFS-e', descricaoNfsePlano),
            dropdown(
              'Desconto',
              descontoPercentual,
              ['0%', '1%', '2%', '3%', '4%', '5%', '6%'],
              (v) {
                setState(() => descontoPercentual = v);
              },
            ),
            campoInfo('Valor do desconto', formatarMoeda(valorDesconto)),
            campoDinheiro(entradaController, 'Entrada'),

            campo(parcelasPagasController, 'Parcelas já pagas'),

            dropdown(
              'Parcelas',
              parcelas,
              ['1', '2', '3', '4', '5', '6', '7'],
              (v) {
                setState(() {
                  parcelas = v;
                });
              },
            ),

            dropdown(
              'Forma de pagamento',
              formaPagamento,
              ['Pix', 'Crédito', 'Débito', 'Boleto'],
              (v) {
                setState(() => formaPagamento = v);
              },
            ),
            dropdown('Consultório', consultorio, ['Sim', 'Não'], (v) {
              setState(() => consultorio = v);
            }),
            campoInfo('Valor final', formatarMoeda(valorFinal)),
            campoInfo('Valor da parcela', formatarMoeda(valorParcela)),
          ]),

          ElevatedButton.icon(
            onPressed: salvarGestante,
            icon: const Icon(Icons.save),
            label: const Text('Salvar gestante'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NatusApp.vinho,
              foregroundColor: (NatusApp.escuro
                  ? NatusApp.fundo
                  : NatusApp.offWhite),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget telaGestantes() {
    final totalAtivas = gestantes.where(gestanteAtivaParaContracoes).length;
    final totalPuerperas = gestantes.where((g) {
      return statusGestanteNormalizado(g) == 'Puérpera';
    }).length;
    final totalEncerradas = gestantes.where((g) {
      final historico = (g['historico'] ?? '').trim().toLowerCase();
      return statusGestanteNormalizado(g) == 'Encerrada' ||
          statusGestanteNormalizado(g) == 'Histórico' ||
          historico == 'true' ||
          historico == 'sim' ||
          historico == '1';
    }).length;
    final totalAtendimentos2025 = contarBebesPorAno('2025');
    final totalAtendimentos2026 = contarBebesPorAno('2026');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestantes',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: NatusApp.vinho,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'Acompanhamento das gestantes da sua clínica.',
            style: TextStyle(
              fontSize: 13,
              color: NatusApp.textoSuave,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              cardResumo(
                'Ativas',
                totalAtivas.toString(),
                Icons.pregnant_woman,
                cor: NatusApp.vinho,
              ),
              cardResumo(
                'Puérperas',
                totalPuerperas.toString(),
                Icons.child_friendly,
                cor: NatusApp.marsalaSuave,
              ),
              cardResumo(
                'Encerradas',
                totalEncerradas.toString(),
                Icons.check_circle,
                cor: const Color(0xFF5F7D54),
              ),
              cardResumo(
                'Total',
                gestantes.length.toString(),
                Icons.groups_2_outlined,
                cor: NatusApp.douradoEscuro,
              ),
              cardResumo(
                'Atendimentos 2025',
                totalAtendimentos2025.toString(),
                Icons.calendar_month,
                cor: NatusApp.olivaSeco,
              ),
              cardResumo(
                'Atendimentos 2026',
                totalAtendimentos2026.toString(),
                Icons.event_available,
                cor: NatusApp.olivaSeco,
              ),
            ],
          ),

          const SizedBox(height: 20),

          filtroDashboardPacientesAtivo(),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              filtroBotao('Ativas'),
              filtroBotao('Gestante'),
              filtroBotao('Puérpera'),
              filtroBotao('Histórico'),
              filtroBotao('Encerrada'),
              filtroBotao('Todas'),
            ],
          ),

          const SizedBox(height: 16),

          TextField(
            controller: buscaGestantesController,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Buscar gestante',
              hintText: 'Nome, telefone, e-mail, cidade, hospital ou obstetra',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: buscaGestantesController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          buscaGestantesController.clear();
                        });
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: NatusApp.offWhite,
            ),
          ),

          const SizedBox(height: 16),

          listaGestantes(),
        ],
      ),
    );
  }

  Widget telaBiblioteca() {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final podeGerenciarBiblioteca = usuarioEhAdmin();

    if (biblioteca.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 18 : 26),
          decoration: BoxDecoration(
            color: NatusApp.offWhite,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: NatusApp.rose.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cabecalhoBiblioteca(podeGerenciarBiblioteca),
              const SizedBox(height: 24),
              Text(
                'Nenhum material disponível na biblioteca.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Map<String, List<Map<String, String>>> categorias = {};

    for (var item in biblioteca) {
      final categoria = item['categoria'] ?? 'Outros';

      if (!categorias.containsKey(categoria)) {
        categorias[categoria] = [];
      }

      categorias[categoria]!.add(item);
    }

    final materialDestaque = biblioteca.first;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 18 : 26),
        decoration: BoxDecoration(
          color: NatusApp.offWhite,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: NatusApp.rose.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO PREMIUM
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 58 : 72,
                  height: isMobile ? 58 : 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFEA),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: NatusApp.vinho,
                    size: 34,
                  ),
                ),

                const SizedBox(width: 18),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biblioteca Natus',
                        style: TextStyle(
                          fontSize: isMobile ? 26 : 34,
                          fontWeight: FontWeight.w900,
                          color: NatusApp.vinho,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Conteúdos escolhidos para acompanhar sua gestação com segurança, informação e acolhimento.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: NatusApp.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (podeGerenciarBiblioteca) ...[
              const SizedBox(height: 18),
              botaoAdicionarMaterialBiblioteca(),
            ],

            const SizedBox(height: 24),

            Divider(color: NatusApp.rose.withValues(alpha: 0.35), height: 1),

            const SizedBox(height: 22),

            // CHIPS DE CATEGORIA
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: NatusApp.vinho,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: NatusApp.vinho.withValues(alpha: 0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          color: NatusApp.offWhite,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Todos',
                          style: TextStyle(
                            color: NatusApp.offWhite,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  ...categorias.keys.map((nomeCategoria) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: NatusApp.offWhite,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: NatusApp.rose.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          nomeCategoria,
                          style: TextStyle(
                            color: NatusApp.vinho,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // MATERIAL RECOMENDADO
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF7F3), Color(0xFFFFEAE3)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: NatusApp.rose.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: NatusApp.offWhite.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          color: NatusApp.vinho,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Recomendado para esta fase',
                          style: TextStyle(
                            color: NatusApp.vinho,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cardBibliotecaNetflix(
                              materialDestaque,
                              largura: double.infinity,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cardBibliotecaNetflix(
                              materialDestaque,
                              largura: 280,
                            ),

                            const SizedBox(width: 22),

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Guia da semana',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: NatusApp.textoSuave,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    Text(
                                      materialDestaque['titulo'] ??
                                          'Material selecionado',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: NatusApp.vinho,
                                        height: 1.2,
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    Text(
                                      materialDestaque['descricao'] ??
                                          'Conteúdo selecionado pela equipe Natus para apoiar sua jornada.',
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: NatusApp.textoSuave,
                                      ),
                                    ),

                                    const SizedBox(height: 18),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NatusApp.vinho,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.auto_stories_rounded,
                                            color: NatusApp.offWhite,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Acessar material abaixo',
                                            style: TextStyle(
                                              color: NatusApp.offWhite,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // MAIS CONTEÚDOS
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFFFEFEA),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    color: NatusApp.vinho,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Mais conteúdos para você',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: NatusApp.vinho,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ...categorias.entries.map((categoria) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria.key,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: NatusApp.vinho,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: isMobile ? 330 : 350,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categoria.value.length,
                      separatorBuilder: (context, index) {
                        return const SizedBox(width: 14);
                      },
                      itemBuilder: (context, index) {
                        final material = categoria.value[index];

                        return cardBibliotecaNetflix(
                          material,
                          largura: isMobile ? 165 : 190,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              );
            }),

            const SizedBox(height: 6),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F3),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: NatusApp.rose.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFFFEFEA),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      color: NatusApp.vinho,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Todos os materiais são selecionados com carinho pela equipe Natus para apoiar você em cada momento.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: NatusApp.textoSuave,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget cabecalhoBiblioteca(bool podeGerenciarBiblioteca) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isMobile ? 58 : 72,
              height: isMobile ? 58 : 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFEA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: NatusApp.vinho,
                size: 34,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biblioteca Natus',
                    style: TextStyle(
                      fontSize: isMobile ? 26 : 34,
                      fontWeight: FontWeight.w900,
                      color: NatusApp.vinho,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conteúdos escolhidos para acompanhar sua gestação com segurança, informação e acolhimento.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: NatusApp.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (podeGerenciarBiblioteca) ...[
          const SizedBox(height: 18),
          botaoAdicionarMaterialBiblioteca(),
        ],
      ],
    );
  }

  Widget botaoAdicionarMaterialBiblioteca() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: abrirCadastroMaterialBiblioteca,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar material'),
        style: ElevatedButton.styleFrom(
          backgroundColor: NatusApp.vinho,
          foregroundColor: NatusApp.offWhite,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> abrirCadastroMaterialBiblioteca() async {
    if (!usuarioEhAdmin()) return;

    final tituloController = TextEditingController();
    final categoriaController = TextEditingController(text: 'Gestação');
    final descricaoController = TextEditingController();
    final urlController = TextEditingController();
    final capaUrlController = TextEditingController();
    var tipoSelecionado = 'pdf';

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text('Adicionar material'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        campoFull(tituloController, 'Título'),
                        const SizedBox(height: 12),
                        campoFull(categoriaController, 'Categoria'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: tipoSelecionado,
                          decoration: InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                            DropdownMenuItem(
                              value: 'video',
                              child: Text('Vídeo'),
                            ),
                            DropdownMenuItem(
                              value: 'link',
                              child: Text('Link'),
                            ),
                          ],
                          onChanged: (valor) {
                            if (valor == null) return;
                            setStateDialog(() => tipoSelecionado = valor);
                          },
                        ),
                        const SizedBox(height: 12),
                        campoFull(urlController, 'URL do material'),
                        const SizedBox(height: 12),
                        campoFull(capaUrlController, 'URL da capa'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descricaoController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Descrição',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final titulo = tituloController.text.trim();
                      final url = urlController.text.trim();

                      if (titulo.isEmpty || url.isEmpty) {
                        mostrarMensagem('Informe título e URL do material.');
                        return;
                      }

                      final material = {
                        'titulo': titulo,
                        'categoria': categoriaController.text.trim().isEmpty
                            ? 'Outros'
                            : categoriaController.text.trim(),
                        'tipo': tipoSelecionado,
                        'url': url,
                        'capaUrl': capaUrlController.text.trim(),
                        'descricao': descricaoController.text.trim(),
                        'ativo': 'true',
                        'ordem': (biblioteca.length + 1).toString(),
                        'criadoEm': DateTime.now().toIso8601String(),
                      };

                      Navigator.pop(context);
                      await salvarItemBibliotecaFirestore(material);
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      tituloController.dispose();
      categoriaController.dispose();
      descricaoController.dispose();
      urlController.dispose();
      capaUrlController.dispose();
    }
  }

  Widget cardBibliotecaNetflix(
    Map<String, String> material, {
    required double largura,
  }) {
    final tipo = material['tipo'] ?? 'pdf';
    final titulo = material['titulo'] ?? 'Material';
    final descricao = material['descricao'] ?? '';
    final url = material['url'] ?? '';
    final capaUrl = material['capaUrl'] ?? '';

    IconData icone = Icons.menu_book_rounded;
    IconData iconeAcao = Icons.auto_stories_rounded;
    String textoBotao = 'Acessar material';
    String etiqueta = 'Conteúdo';

    if (tipo == 'video') {
      icone = Icons.play_circle_fill_rounded;
      iconeAcao = Icons.play_arrow_rounded;
      textoBotao = 'Assistir agora';
      etiqueta = 'Vídeo';
    } else if (tipo == 'link') {
      icone = Icons.movie_creation_rounded;
      iconeAcao = Icons.play_arrow_rounded;
      textoBotao = 'Assistir agora';
      etiqueta = 'Filme';
    } else if (tipo == 'pdf') {
      icone = Icons.picture_as_pdf_rounded;
      iconeAcao = Icons.menu_book_rounded;
      textoBotao = 'Acessar material';
      etiqueta = 'PDF';
    }

    return SizedBox(
      width: largura,
      height: 340,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          if (url.isNotEmpty) {
            abrirArquivo(url);
          } else {
            mostrarMensagem('Material ainda não disponível.');
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: NatusApp.offWhite,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: NatusApp.rose.withValues(alpha: 0.30)),
            boxShadow: [
              BoxShadow(
                color: NatusApp.vinhoProfundo.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFEFEA), NatusApp.rose],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (capaUrl.isNotEmpty)
                      Image.network(
                        capaUrl.trim(),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return Center(
                            child: CircularProgressIndicator(
                              color: NatusApp.vinho,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(icone, size: 52, color: NatusApp.vinho),
                          );
                        },
                      )
                    else
                      Center(
                        child: Icon(icone, size: 52, color: NatusApp.vinho),
                      ),

                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: NatusApp.vinho.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          etiqueta.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: NatusApp.offWhite,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: NatusApp.offWhite.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: NatusApp.vinhoProfundo.withValues(
                                alpha: 0.10,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          tipo == 'pdf'
                              ? Icons.open_in_new_rounded
                              : Icons.play_arrow_rounded,
                          color: NatusApp.vinho,
                          size: 23,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.20,
                    fontWeight: FontWeight.w900,
                    color: NatusApp.vinho,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  descricao.isEmpty
                      ? 'Conteúdo selecionado pela equipe Natus.'
                      : descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.30,
                    color: NatusApp.textoSuave,
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (url.isNotEmpty) {
                      abrirArquivo(url);
                    } else {
                      mostrarMensagem('Material ainda não disponível.');
                    }
                  },
                  icon: Icon(iconeAcao, size: 18),
                  label: Text(
                    textoBotao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEFEA),
                    foregroundColor: NatusApp.vinho,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget telaAtendimentos() {
    double km = converterValor(atendimentoKmController.text);

    double valorKm = atendimentoValorKmController.text.trim().isEmpty
        ? 0.75
        : converterValor(atendimentoValorKmController.text);

    double custoDeslocamento = km * valorKm;

    List<String> nomesGestantes = ['Selecione'];
    nomesGestantes.addAll(
      gestantes.map((g) => g['nomeGestante'] ?? 'Sem nome').toList(),
    );

    if (!nomesGestantes.contains(atendimentoGestante)) {
      atendimentoGestante = 'Selecione';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Atendimentos',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),
          const SizedBox(height: 20),

          bloco('Novo atendimento', [
            dropdownGrande(
              'Material usado',
              materialSelecionadoAtendimento,
              ['Selecione', ...materiais.map((m) => m['nome'] ?? '')],
              (v) {
                setState(() => materialSelecionadoAtendimento = v);
              },
            ),

            campo(quantidadeMaterialUsadoController, 'Qtd. usada'),

            ElevatedButton.icon(
              onPressed: adicionarMaterialNoAtendimento,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar material'),
            ),
            dropdownGrande('Gestante', atendimentoGestante, nomesGestantes, (
              v,
            ) {
              setState(() => atendimentoGestante = v);
            }),
            dropdownGrande(
              'Tipo de atendimento',
              atendimentoTipo,
              ['Pré-natal', 'Parto', 'Pós-parto', 'Furinho', 'Consultoria'],
              (v) {
                setState(() => atendimentoTipo = v);
              },
            ),
            campo(atendimentoKmController, 'KM rodado'),
            campoDinheiro(
              atendimentoValorKmController,
              'Valor por KM (padrão R\$ 0,75)',
            ),
            campoInfo(
              'Custo de deslocamento',
              formatarMoeda(custoDeslocamento),
            ),
            campoInfo(
              'Custo dos materiais',
              formatarMoeda(calcularCustoMateriaisAtendimento()),
            ),
            campoInfo(
              'Custo total',
              formatarMoeda(
                custoDeslocamento + calcularCustoMateriaisAtendimento(),
              ),
            ),
            campo(
              atendimentoObservacaoController,
              'Observações / conduta',
              largura: 500,
            ),
          ]),

          const SizedBox(height: 20),

          listaMateriaisUsadosNoAtendimento(),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: salvarAtendimento,
            icon: const Icon(Icons.save),
            label: const Text('Salvar atendimento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NatusApp.vinho,
              foregroundColor: (NatusApp.escuro
                  ? NatusApp.fundo
                  : NatusApp.offWhite),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            ),
          ),

          const SizedBox(height: 30),

          Text(
            'Lista de Atendimentos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),
          const SizedBox(height: 10),
          listaAtendimentos(),
        ],
      ),
    );
  }

  void adicionarMaterialNoAtendimento() {
    if (materialSelecionadoAtendimento == 'Selecione') {
      mostrarMensagem('Selecione um material.');
      return;
    }

    if (quantidadeMaterialUsadoController.text.trim().isEmpty) {
      mostrarMensagem('Informe a quantidade usada.');
      return;
    }

    final material = materiais.firstWhere(
      (m) => m['nome'] == materialSelecionadoAtendimento,
    );

    final quantidadeUsada =
        int.tryParse(quantidadeMaterialUsadoController.text.trim()) ?? 0;

    final custoUnitario = converterValor(material['custo'] ?? '0');

    final custoTotal = quantidadeUsada * custoUnitario;

    setState(() {
      materiaisUsadosNoAtendimento.add({
        'nome': materialSelecionadoAtendimento,
        'quantidade': quantidadeUsada.toString(),
        'custoUnitario': formatarMoeda(custoUnitario),
        'custoTotal': formatarMoeda(custoTotal),
      });

      materialSelecionadoAtendimento = 'Selecione';
      quantidadeMaterialUsadoController.clear();
    });
  }

  double calcularCustoMateriaisAtendimento() {
    double total = 0;

    for (var material in materiaisUsadosNoAtendimento) {
      total += converterValor(material['custoTotal'] ?? '0');
    }

    return total;
  }

  Widget listaMateriaisUsadosNoAtendimento() {
    if (materiaisUsadosNoAtendimento.isEmpty) {
      return const Text('Nenhum material adicionado neste atendimento.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Materiais usados neste atendimento',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NatusApp.vinho,
          ),
        ),
        const SizedBox(height: 10),

        Column(
          children: materiaisUsadosNoAtendimento.asMap().entries.map((entry) {
            final index = entry.key;
            final material = entry.value;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.inventory),
                title: Text(material['nome'] ?? ''),
                subtitle: Text(
                  'Qtd: ${material['quantidade']} | '
                  'Unitário: ${material['custoUnitario']} | '
                  'Total: ${material['custoTotal']}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      materiaisUsadosNoAtendimento.removeAt(index);
                    });
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String gerarResumoMateriaisUsados() {
    if (materiaisUsadosNoAtendimento.isEmpty) {
      return 'Nenhum material informado';
    }

    return materiaisUsadosNoAtendimento
        .map((m) {
          return '${m['nome']} - qtd: ${m['quantidade']} - total: ${m['custoTotal']}';
        })
        .join(' | ');
  }

  void salvarAtendimento() {
    if (atendimentoGestante == 'Selecione') {
      mostrarMensagem('Selecione uma gestante antes de salvar.');
      return;
    }

    double km = converterValor(atendimentoKmController.text);
    double valorKm = converterValor(atendimentoValorKmController.text);
    double custoDeslocamento = km * valorKm;

    for (var usado in materiaisUsadosNoAtendimento) {
      final nome = usado['nome'];

      final materialEstoque = materiais.firstWhere(
        (m) => m['nome'] == nome,
        orElse: () => {},
      );

      if (materialEstoque.isNotEmpty) {
        int estoqueAtual =
            int.tryParse(materialEstoque['quantidade'] ?? '0') ?? 0;

        int usadoQtd = int.tryParse(usado['quantidade'] ?? '0') ?? 0;

        int novoEstoque = estoqueAtual - usadoQtd;

        if (novoEstoque < 0) novoEstoque = 0;

        materialEstoque['quantidade'] = novoEstoque.toString();
      }
    }

    setState(() {
      final novoAtendimento = {
        'materiaisResumo': gerarResumoMateriaisUsados(),
        'custoMateriais': formatarMoeda(calcularCustoMateriaisAtendimento()),
        'gestante': atendimentoGestante,
        'tipo': atendimentoTipo,
        'km': atendimentoKmController.text.trim(),
        'valorKm': atendimentoValorKmController.text.trim(),
        'custoDeslocamento': formatarMoeda(custoDeslocamento),
        'observacao': atendimentoObservacaoController.text.trim(),
        'data': DateTime.now().toString(),
      };

      setState(() {
        atendimentos.add(novoAtendimento);

        materiaisUsadosNoAtendimento.clear();
        atendimentoKmController.clear();
        atendimentoValorKmController.clear();
        atendimentoObservacaoController.clear();
        atendimentoGestante = 'Selecione';
        atendimentoTipo = 'Pré-natal';
      });

      salvarAtendimentoFirestore(novoAtendimento);

      mostrarMensagem('Atendimento salvo com sucesso.');
    });
  }

  Widget listaAtendimentos() {
    if (atendimentos.isEmpty) {
      return const Text('Nenhum atendimento registrado ainda.');
    }

    return Column(
      children: atendimentos.asMap().entries.map((entry) {
        final index = entry.key;
        final a = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: NatusApp.rose,
              child: Icon(Icons.medical_services, color: NatusApp.vinho),
            ),
            title: Text(
              '${a['tipo']} - ${a['gestante']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'KM: ${a['km']} | Valor/KM: R\$ ${a['valorKm']}\n'
              'Custo deslocamento: ${a['custoDeslocamento']}\n'
              'Materiais: ${a['materiaisResumo']}\n'
              'Observação: ${a['observacao']}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  atendimentos.removeAt(index);
                });
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> enviarAcessoGestante(Map<String, String> g) async {
    try {
      final idGestante = g['id'] ?? '';

      if (idGestante.isEmpty) {
        mostrarMensagem('ID da gestante não encontrado.');
        return;
      }

      final doc = await firestore.collection('gestantes').doc(idGestante).get();

      if (!doc.exists) {
        mostrarMensagem('Gestante não encontrada no Firebase.');
        return;
      }

      final dados = doc.data() ?? {};

      final telefone = dados['telefoneGestante']?.toString() ?? '';
      final nome = dados['nomeGestante']?.toString() ?? '';
      final email = dados['emailGestante']?.toString() ?? '';

      if (email.trim().isEmpty) {
        mostrarMensagem('E-mail da gestante não informado.');
        return;
      }

      if (telefone.trim().isEmpty) {
        mostrarMensagem('Telefone da gestante não informado.');
        return;
      }

      final usuarioAtual = FirebaseAuth.instance.currentUser;

      if (usuarioAtual == null) {
        mostrarMensagem('Usuário não autenticado. Faça login novamente.');
        return;
      }

      mostrarMensagem('Gerando novo link de acesso...');

      final idToken = await usuarioAtual.getIdToken();

      final resposta = await http.post(
        Uri.parse(
          'https://reenviarlinktrocasenhagestante-knszwirncq-uc.a.run.app',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'gestanteId': idGestante,
          'nomeGestante': nome,
          'emailGestante': email.trim().toLowerCase(),
          'telefoneGestante': telefone,
        }),
      );

      final dadosResposta = jsonDecode(resposta.body);

      if (resposta.statusCode != 200 || dadosResposta['sucesso'] != true) {
        mostrarMensagem(
          dadosResposta['mensagem']?.toString() ??
              'Não foi possível gerar um novo link de acesso.',
        );
        return;
      }

      final linkNovo = dadosResposta['link']?.toString() ?? '';

      if (linkNovo.trim().isEmpty) {
        mostrarMensagem('O Firebase não retornou um novo link de acesso.');
        return;
      }

      final telefoneLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');

      final mensagem = Uri.encodeComponent(
        'Olá, $nome! 🤍\n\n'
        'Segue um novo link para criar ou trocar sua senha de acesso ao Portal Natus:\n\n'
        '$linkNovo\n\n'
        'Use este link mais recente. Os links anteriores podem ter expirado.\n\n'
        'Depois disso, você poderá acessar o app com seu e-mail e senha.\n\n'
        'Com carinho,\n'
        'Equipe Natus',
      );

      final url = Uri.parse('https://wa.me/55$telefoneLimpo?text=$mensagem');

      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      mostrarMensagem('Erro ao gerar novo link de acesso: $e');
    }
  }

  Widget telaFichaGestanteTempoReal(Map<String, String> g) {
    final idGestante = g['id'] ?? '';

    if (idGestante.isEmpty) {
      return telaFichaGestante(g);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('gestantes').doc(idGestante).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Gestante não encontrada.'));
        }

        final dados = snapshot.data!.data() as Map<String, dynamic>;

        final gestanteAtualizada = dados.map((chave, valor) {
          return MapEntry(chave, valor.toString());
        });

        gestanteAtualizada['id'] = snapshot.data!.id;

        return telaFichaGestante(gestanteAtualizada);
      },
    );
  }

  Widget telaFichaGestante(Map<String, String> g) {
    final igAtual = calcularIdadeGestacional(g['dpp'] ?? '');

    final usuarioEnfermeira = tipoEhProfissionalClinica(widget.tipoUsuario);
    final podeVerFinanceiroGestante = !usuarioEnfermeira;

    final atendimentosDaGestante = atendimentos
        .where((a) => a['gestante'] == (g['nomeGestante'] ?? ''))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                gestanteSelecionada = null;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para lista'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NatusApp.vinho,
              foregroundColor: (NatusApp.escuro
                  ? NatusApp.fundo
                  : NatusApp.offWhite),
            ),
          ),
          const SizedBox(height: 20),
          Text(g['nomeGestante'] ?? 'Ficha da gestante'),

          const SizedBox(height: 8),

          badgeStatus(g['statusGestante'] ?? 'Gestante'),

          const SizedBox(height: 12),

          Text(
            'IG atual: $igAtual',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () {
              abrirPopupEditarGestante(g);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Editar cadastro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NatusApp.offWhite,
              foregroundColor: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: () {
              enviarAcessoGestante(g);
            },
            icon: const Icon(Icons.lock_reset),
            label: const Text('Reenviar acesso da gestante'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NatusApp.vinho,
              foregroundColor: (NatusApp.escuro
                  ? NatusApp.fundo
                  : NatusApp.offWhite),
            ),
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: () {
              atualizarStatusGestante(g);
            },
            icon: const Icon(Icons.swap_horiz),
            label: Text(
              (g['statusGestante'] ?? 'Gestante') == 'Gestante'
                  ? 'Transformar em puérpera'
                  : (g['statusGestante'] ?? 'Gestante') == 'Puérpera'
                  ? 'Encerrar atendimento'
                  : 'Atendimento encerrado',
            ),
          ),

          const SizedBox(height: 24),

          blocoFicha('Gestante', [
            linhaInfo('Nome', g['nomeGestante']),
            linhaInfo('CPF', g['cpfGestante']),
            linhaInfo('Telefone', g['telefoneGestante']),
            linhaInfo('E-mail', g['emailGestante']),
            linhaInfo('Endereço', g['enderecoGestante']),
            linhaInfo('Bairro', g['bairroGestante']),
            linhaInfo('Cidade', g['cidadeGestante']),
            linhaInfo('CEP', g['cepGestante']),
            linhaInfo('Hospital', g['hospitalGestante']),
            linhaInfo('Obstetra', g['obstetraGestante']),
            linhaInfo('Convênio', g['convenioGestante']),
            linhaInfo('Risco gestacional', g['riscoGestacional']),
            linhaInfo('Diabetes gestacional', g['diabetesGestacional']),
          ], onEditar: () => abrirPopupEditarSecaoGestante(g, 'Gestante')),

          blocoFicha('Pai', [
            linhaInfo('Nome do pai', g['nomePai']),
            linhaInfo('CPF do pai / responsável', g['cpfPai']),
            linhaInfo('Telefone do pai', g['telefonePai']),
            linhaInfo('E-mail do pai', g['emailPai']),
          ], onEditar: () => abrirPopupEditarSecaoGestante(g, 'Pai')),

          blocoFicha('Bebê', [
            linhaInfo('Nome do bebê', g['nomeBebe']),
            linhaInfo('Sexo', g['sexo']),
            linhaInfo('DPP', g['dpp']),
            linhaInfo('IG atual', igAtual),
            linhaInfo('Data de nascimento', g['dataNascimento']),
            linhaInfo('Via de nascimento', g['viaNascimento']),
            linhaInfo('IG ao nascer', g['igAoNascer']),
            linhaInfo('Peso', g['pesoBebe']),
            linhaInfo('Golden Hour', g['goldenHour']),
            linhaInfo('Amamentação', g['amamentacao']),
            linhaInfo('Observações', g['observacoesBebe']),
          ], onEditar: () => abrirPopupEditarSecaoGestante(g, 'Bebê')),

          if (podeVerFinanceiroGestante)
            blocoFicha('Valores', [
              linhaInfo('Plano', g['plano']),
              linhaInfo('Valor do plano', g['valorPlano']),
              linhaInfo(
                'Desconto',
                '${g['descontoPercentual']} (${g['valorDesconto']})',
              ),
              linhaInfo('Entrada', g['entrada']),
              linhaInfo(
                'Parcelas',
                '${g['parcelas']}x de ${g['valorParcela']}',
              ),
              linhaInfo('Forma de pagamento', g['formaPagamento']),
              linhaInfo('Consultório', g['consultorio']),
            ], onEditar: () => abrirPopupEditarSecaoGestante(g, 'Valores')),

          if (podeVerFinanceiroGestante) financeiroGestantePremium(g),

          if (podeVerFinanceiroGestante)
            blocoFicha('Centro de custo', [
              linhaInfo(
                'Custo total',
                formatarMoeda(
                  calcularCustoTotalGestante(g['nomeGestante'] ?? ''),
                ),
              ),

              linhaInfo(
                'Lucro estimado',
                formatarMoeda(
                  converterValor(g['valorPlano'] ?? '0') -
                      calcularCustoTotalGestante(g['nomeGestante'] ?? ''),
                ),
              ),
            ]),

          blocoFicha('Atendimentos da gestante', [
            if (atendimentosDaGestante.isEmpty)
              linhaInfo('Atendimentos', 'Nenhum atendimento registrado ainda')
            else
              ...atendimentosDaGestante.map((a) {
                return linhaInfo(
                  a['tipo'] ?? 'Atendimento',
                  'KM: ${a['km']}\n'
                  'Custo deslocamento: ${a['custoDeslocamento']}\n'
                  'Materiais: ${a['materiaisResumo']}\n'
                  'Custo materiais: ${a['custoMateriais']}\n'
                  'Obs: ${a['observacao']}',
                );
              }),
          ]),

          bloco('Contrações', [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  contracaoGestanteSelecionada = g['nomeGestante'] ?? '';
                });

                if (inicioContracao == null) {
                  iniciarContracao();
                } else {
                  pararContracao();
                }
              },
              icon: Icon(
                inicioContracao == null ? Icons.play_arrow : Icons.stop,
              ),
              label: Text(
                inicioContracao == null
                    ? 'Iniciar contração'
                    : 'Parar contração',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: inicioContracao == null
                    ? Colors.green
                    : Colors.red,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
              ),
            ),

            const SizedBox(height: 16),

            listaContracoes(),
          ]),

          blocoFicha('Documentos da gestante', [
            ...documentos
                .where((d) => d['gestante'] == (g['nomeGestante'] ?? ''))
                .map((d) {
                  return linhaInfo(d['tipo'] ?? 'Documento', d['nome'] ?? '');
                }),
          ]),

          blocoFicha('Exames', [
            ...documentos
                .where(
                  (d) =>
                      d['gestante'] == (g['nomeGestante'] ?? '') &&
                      d['tipo'] == 'Exame',
                )
                .map((d) {
                  return cardDocumentoProntuario(d);
                }),
          ]),

          if (podeVerFinanceiroGestante)
            blocoFicha('Contratos', [
              ...documentos
                  .where(
                    (d) =>
                        d['gestante'] == (g['nomeGestante'] ?? '') &&
                        d['tipo'] == 'Contrato',
                  )
                  .map((d) {
                    return cardDocumentoProntuario(d);
                  }),
            ]),

          if (podeVerFinanceiroGestante)
            blocoFicha('Comprovantes', [
              ...documentos
                  .where(
                    (d) =>
                        d['gestante'] == (g['nomeGestante'] ?? '') &&
                        d['tipo'] == 'Comprovante',
                  )
                  .map((d) {
                    return cardDocumentoProntuario(d);
                  }),
            ]),
        ],
      ),
    );
  }

  Widget blocoFicha(
    String titulo,
    List<Widget> itens, {
    VoidCallback? onEditar,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.vinho,
                  ),
                ),
              ),
              if (onEditar != null)
                Tooltip(
                  message: 'Editar $titulo',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onEditar,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NatusApp.rose.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 19,
                        color: NatusApp.vinho,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          ...itens,
        ],
      ),
    );
  }

  // ── 2f parte 2: visual do badge unificado em NatusStatusBadge ──
  Widget badgeStatus(String status) => NatusStatusBadge(status);

  int contarGestantesPorFiltroAba(String status) {
    if (status == 'Ativas') {
      return gestantes.where(gestanteEstaAtiva).length;
    }

    if (status == 'Gestante') {
      return gestantes.where(gestanteAtivaParaContracoes).length;
    }

    if (status == 'Puérpera') {
      return gestantes.where((g) {
        return gestanteEstaAtiva(g) &&
            statusGestanteNormalizado(g) == 'Puérpera';
      }).length;
    }

    if (status == 'Histórico') {
      return gestantes.where((g) {
        final historico = (g['historico'] ?? '').trim().toLowerCase();
        return historico == 'true' ||
            historico == 'sim' ||
            historico == '1' ||
            statusGestanteNormalizado(g) == 'Histórico';
      }).length;
    }

    if (status == 'Encerrada') {
      return gestantes.where((g) {
        return statusGestanteNormalizado(g) == 'Encerrada';
      }).length;
    }

    if (status == 'Todas') {
      return gestantes.length;
    }

    return 0;
  }

  Widget filtroBotao(String status) {
    final selecionado = filtroStatusGestante == status;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          filtroStatusGestante = status;
          filtroDashboardPacientes = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? NatusApp.marsala : NatusApp.offWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionado
                ? NatusApp.marsala
                : NatusApp.begeEscuro.withValues(alpha: 0.9),
          ),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selecionado ? NatusApp.offWhite : NatusApp.textoSuave,
          ),
        ),
      ),
    );
  }

  Widget filtroDashboardPacientesAtivo() {
    final filtro = filtroDashboardPacientes;
    if (filtro == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NatusApp.vinho.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NatusApp.vinho.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard_customize_rounded, color: NatusApp.vinho),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Filtro do Dashboard: ${filtro.titulo}',
              style: TextStyle(
                color: NatusApp.vinho,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Limpar filtro do Dashboard',
            onPressed: limparFiltroDashboardPacientes,
            icon: const Icon(Icons.close_rounded),
            color: NatusApp.vinho,
          ),
        ],
      ),
    );
  }

  Widget filtroFinanceiroBotao(String filtro) {
    final selecionado = filtroFinanceiro == filtro;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          filtroFinanceiro = filtro;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: selecionado ? NatusApp.vinho : NatusApp.offWhite,
        foregroundColor: selecionado
            ? (NatusApp.escuro ? NatusApp.fundo : NatusApp.offWhite)
            : NatusApp.vinho,
        side: BorderSide(color: NatusApp.vinho),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: Text(filtro),
    );
  }

  Widget linhaInfo(String label, String? valor) {
    final texto = (valor == null || valor.trim().isEmpty)
        ? 'Não informado'
        : valor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  Widget telaAlmoxarifado() {
    final totalItens = materiais.length;
    final baixoEstoque = materiaisComEstoqueBaixo().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Almoxarifado',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Controle de insumos, estoque mínimo e materiais disponíveis.',
            style: TextStyle(color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              cardResumoAlmox(
                'Total de insumos',
                totalItens.toString(),
                Icons.inventory_2,
                NatusApp.vinho,
              ),
              cardResumoAlmox(
                'Estoque baixo',
                baixoEstoque.toString(),
                Icons.warning_amber,
                baixoEstoque > 0 ? Colors.red : Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 24),

          bloco('Cadastrar insumo', [
            campo(materialNomeController, 'Nome do insumo'),

            const SizedBox(height: 12),

            campo(materialQuantidadeController, 'Quantidade atual'),

            const SizedBox(height: 12),

            campoDinheiro(materialCustoController, 'Custo unitário'),

            const SizedBox(height: 12),

            campo(materialMinimoController, 'Quantidade mínima'),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: salvarMaterial,
              icon: const Icon(Icons.save),
              label: const Text('Salvar insumo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NatusApp.vinho,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          TextField(
            controller: buscaAlmoxarifadoController,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Buscar insumo',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              filtroBotaoAlmox('Todos'),
              filtroBotaoAlmox('Insumos'),
              filtroBotaoAlmox('Estoque baixo'),
            ],
          ),

          const SizedBox(height: 24),

          listaMateriais(),
        ],
      ),
    );
  }

  void salvarMaterial() {
    final novoMaterial = {
      'nome': materialNomeController.text.trim(),
      'quantidade': materialQuantidadeController.text.trim(),
      'custo': materialCustoController.text.trim(),
      'minimo': materialMinimoController.text.trim(),
    };

    setState(() {
      materiais.add(novoMaterial);

      materialNomeController.clear();
      materialQuantidadeController.clear();
      materialCustoController.clear();
      materialMinimoController.clear();
    });

    salvarMaterialFirestore(novoMaterial);
  }

  Widget listaMateriais() {
    var lista = materiais.where((m) {
      final nome = (m['nome'] ?? '').toLowerCase();
      final busca = buscaAlmoxarifadoController.text.toLowerCase().trim();

      final quantidade = int.tryParse(m['quantidade'] ?? '0') ?? 0;
      final minimo = int.tryParse(m['minimo'] ?? '0') ?? 0;

      if (busca.isNotEmpty && !nome.contains(busca)) {
        return false;
      }

      if (filtroAlmoxarifado == 'Estoque baixo') {
        return quantidade <= minimo;
      }

      return true;
    }).toList();

    if (lista.isEmpty) {
      return const Text('Nenhum insumo encontrado.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lista.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 1 : 3,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isMobile ? 3.6 : 2.2,
          ),
          itemBuilder: (context, index) {
            return cardMaterialPremium(lista[index]);
          },
        );
      },
    );
  }

  Widget filtroBotaoAlmox(String filtro) {
    final selecionado = filtroAlmoxarifado == filtro;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          filtroAlmoxarifado = filtro;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: selecionado ? NatusApp.vinho : NatusApp.offWhite,
        foregroundColor: selecionado
            ? (NatusApp.escuro ? NatusApp.fundo : NatusApp.offWhite)
            : NatusApp.vinho,
        side: BorderSide(color: NatusApp.vinho),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: Text(filtro),
    );
  }

  Widget cardResumoAlmox(
    String titulo,
    String valor,
    IconData icone,
    Color cor,
  ) => NatusCardResumoAlmox(titulo, valor, icone, cor);

  Widget cardMaterialPremium(Map<String, String> m) {
    final nome = m['nome'] ?? '';
    final quantidade = int.tryParse(m['quantidade'] ?? '0') ?? 0;
    final minimo = int.tryParse(m['minimo'] ?? '0') ?? 0;
    final custo = m['custo'] ?? '0';

    final baixo = quantidade <= minimo;
    final corStatus = baixo ? Colors.red : Colors.green;
    final textoStatus = baixo ? 'Estoque baixo' : 'Estoque OK';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: corStatus.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: NatusApp.rose.withValues(alpha: 0.25),
                child: Icon(Icons.inventory_2, color: NatusApp.vinho),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.vinho,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text('Quantidade atual: $quantidade'),
          Text('Estoque mínimo: $minimo'),
          Text('Custo unitário: R\$ $custo'),

          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: corStatus.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              textoStatus,
              style: TextStyle(color: corStatus, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget telaCentroDeCusto() {
    if (gestantes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma gestante cadastrada ainda.',
          style: TextStyle(fontSize: 22),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Centro de custo',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),
          const SizedBox(height: 20),

          Column(
            children: gestantes.map((g) {
              final nome = g['nomeGestante'] ?? '';
              final receita = converterValor(g['valorPlano'] ?? '0');
              final desconto = converterValor(g['valorDesconto'] ?? '0');
              final entrada = converterValor(g['entrada'] ?? '0');
              final custoTotal = calcularCustoTotalGestante(nome);
              final resultado = receita - desconto - custoTotal;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: NatusApp.rose,
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: NatusApp.vinho,
                    ),
                  ),
                  title: Text(
                    nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Plano: ${g['plano']}\n'
                    'Receita: ${formatarMoeda(receita)} | Desconto: ${formatarMoeda(desconto)}\n'
                    'Entrada: ${formatarMoeda(entrada)} | Custos: ${formatarMoeda(custoTotal)}\n'
                    'Resultado estimado: ${formatarMoeda(resultado)}',
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int calcularSemanas(String dpp) {
    try {
      final partes = dpp.split('/');
      if (partes.length != 3) return 0;

      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);

      final dataDpp = DateTime(ano, mes, dia);
      final hoje = DateTime.now();

      final diasParaDpp = dataDpp.difference(hoje).inDays;
      final semanas = 40 - (diasParaDpp ~/ 7);

      return semanas.clamp(0, 42);
    } catch (e) {
      return 0;
    }
  }

  String frutaDaSemana(int semanas) {
    if (semanas <= 4) return 'grão de papoula';
    if (semanas <= 6) return 'lentilha';
    if (semanas <= 8) return 'uva';
    if (semanas <= 10) return 'morango';
    if (semanas <= 12) return 'limão';
    if (semanas <= 16) return 'abacate';
    if (semanas <= 20) return 'manga';
    if (semanas <= 24) return 'milho';
    if (semanas <= 28) return 'berinjela';
    if (semanas <= 32) return 'coco';
    if (semanas <= 36) return 'melão';

    return 'melancia';
  }

  String imagemFrutaDaSemana(int semanas) {
    final int semana = semanas.clamp(4, 42).toInt();

    final imagens = <int, String>{
      4: 'assets/frutas/mirtilo.png',
      5: 'assets/frutas/framboesa.png',
      6: 'assets/frutas/framboesa.png',
      7: 'assets/frutas/uva.png',
      8: 'assets/frutas/uva.png',
      9: 'assets/frutas/morango.png',
      10: 'assets/frutas/morango.png',
      11: 'assets/frutas/limao.png',
      12: 'assets/frutas/limao.png',
      13: 'assets/frutas/pessego.png',
      14: 'assets/frutas/pessego.png',
      15: 'assets/frutas/abacate.png',
      16: 'assets/frutas/abacate.png',
      17: 'assets/frutas/pera.png',
      18: 'assets/frutas/manga.png',
      19: 'assets/frutas/manga.png',
      20: 'assets/frutas/manga.png',
      21: 'assets/frutas/milho.png',
      22: 'assets/frutas/milho.png',
      23: 'assets/frutas/berinjela.png',
      24: 'assets/frutas/berinjela.png',
      25: 'assets/frutas/couve flor.png',
      26: 'assets/frutas/couve flor.png',
      27: 'assets/frutas/repolho.png',
      28: 'assets/frutas/repolho.png',
      29: 'assets/frutas/abobora.png',
      30: 'assets/frutas/abobora.png',
      31: 'assets/frutas/coco.png',
      32: 'assets/frutas/coco.png',
      33: 'assets/frutas/abacaxi.png',
      34: 'assets/frutas/abacaxi.png',
      35: 'assets/frutas/melao.png',
      36: 'assets/frutas/melao.png',
      37: 'assets/frutas/melancia.png',
      38: 'assets/frutas/melancia.png',
      39: 'assets/frutas/melancia.png',
      40: 'assets/frutas/melancia.png',
      41: 'assets/frutas/melancia.png',
      42: 'assets/frutas/melancia.png',
    };

    return imagens[semana] ?? 'assets/frutas/morango.png';
  }

  Widget imagemGestacional({required int semanas, double tamanho = 150}) {
    return Image.asset(
      imagemFrutaDaSemana(semanas),
      height: tamanho,
      width: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Text('🍓', style: TextStyle(fontSize: 80));
      },
    );
  }

  String faseGestacaoNatus(int semanas) {
    if (semanas <= 0) return 'Acompanhamento gestacional';
    if (semanas <= 13) return 'Primeiro trimestre';
    if (semanas <= 27) return 'Segundo trimestre';
    return 'Terceiro trimestre';
  }

  String artigoFruta(String fruta) {
    const femininas = {
      'lentilha',
      'framboesa',
      'manga',
      'melancia',
      'uva',
      'berinjela',
    };
    return femininas.contains(fruta.toLowerCase().trim()) ? 'uma' : 'um';
  }

  Widget chipHeroGestante({
    required IconData icon,
    required String titulo,
    required String valor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: NatusApp.douradoEscuro),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 11,
                  color: NatusApp.textoSuave,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 13,
                  color: NatusApp.vinho,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget cardHeroGestantePremium({
    required String bebe,
    required String idadeGestacional,
    required int semanas,
    required String fruta,
    required int diasRestantes,
  }) {
    final nomeBebe = bebe.trim().isEmpty ? 'seu bebê' : bebe.trim();
    final fase = faseGestacaoNatus(semanas);
    final percentual = semanas <= 0
        ? 0
        : (((semanas / 40).clamp(0.0, 1.0)) * 100).round();
    final semanasRestantes = (40 - semanas).clamp(0, 40);
    final legendaProgresso = diasRestantes == 9999
        ? 'Informe a DPP para acompanhar o progresso da gestação.'
        : semanasRestantes <= 0
        ? 'Reta final: o grande dia pode chegar a qualquer momento!'
        : 'Faltam $semanasRestantes semanas para o grande dia!';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: NatusApp.offWhite,
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NatusApp.rose.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compacto = constraints.maxWidth < 560;
                final tamanhoImagem = compacto ? 132.0 : 154.0;

                final blocoTexto = Column(
                  crossAxisAlignment: compacto
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: NatusApp.marsala,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        idadeGestacional,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: NatusApp.offWhite,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$nomeBebe está do tamanho\nde '),
                          TextSpan(
                            text: '${artigoFruta(fruta)} $fruta',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontFamily: 'Georgia',
                              color: NatusApp.marsala,
                            ),
                          ),
                        ],
                      ),
                      textAlign: compacto ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontSize: compacto ? 26.0 : 32.0,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        color: NatusApp.vinho,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Uma fase importante da jornada, acompanhada com cuidado e acolhimento.',
                      textAlign: compacto ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: NatusApp.textoSuave,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: compacto
                          ? WrapAlignment.center
                          : WrapAlignment.start,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        chipHeroGestante(
                          icon: Icons.calendar_month,
                          titulo: 'Semana',
                          valor: semanas > 0
                              ? '$semanas semanas'
                              : 'A calcular',
                        ),
                        chipHeroGestante(
                          icon: Icons.auto_awesome,
                          titulo: 'Fase',
                          valor: fase,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: semanas > 0
                                  ? (semanas / 40).clamp(0.0, 1.0)
                                  : 0.0,
                              minHeight: 7,
                              backgroundColor: NatusApp.bege,
                              valueColor: AlwaysStoppedAnimation(
                                NatusApp.marsala,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$percentual%',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: NatusApp.marsala,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      legendaProgresso,
                      textAlign: compacto ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: NatusApp.textoSuave,
                      ),
                    ),
                  ],
                );

                final blocoImagem = Container(
                  width: compacto ? 222 : 235,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: NatusApp.offWhite,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: NatusApp.douradoClaro.withValues(alpha: 0.7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      imagemGestacional(
                        semanas: semanas,
                        tamanho: tamanhoImagem,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Referência da semana',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: NatusApp.textoSuave,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );

                if (compacto) {
                  return Column(
                    children: [
                      blocoTexto,
                      const SizedBox(height: 22),
                      blocoImagem,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: blocoTexto),
                    const SizedBox(width: 24),
                    blocoImagem,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget contadorContracoesGestante({
    required Map<String, String> gestante,
    required bool emContracao,
    required VoidCallback onIniciar,
    required VoidCallback onParar,
  }) {
    return bloco('Contador de contrações', [
      Text(
        'Gestante: ${gestante['nomeGestante'] ?? 'Não informado'}',
        style: TextStyle(fontWeight: FontWeight.bold, color: NatusApp.vinho),
      ),

      const SizedBox(height: 12),

      ElevatedButton.icon(
        onPressed: emContracao ? onParar : onIniciar,
        icon: Icon(emContracao ? Icons.stop : Icons.play_arrow),
        label: Text(emContracao ? 'Parar contração' : 'Iniciar contração'),
        style: ElevatedButton.styleFrom(
          backgroundColor: emContracao ? Colors.red : Colors.green,
          foregroundColor: (NatusApp.escuro
              ? NatusApp.fundo
              : NatusApp.offWhite),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        ),
      ),
    ]);
  }

  Widget vitrineBibliotecaGestante() {
    final itensAtivos = biblioteca
        .where((item) {
          return (item['ativo'] ?? 'true') == 'true';
        })
        .take(2)
        .toList();

    if (itensAtivos.isEmpty) {
      return blocoFicha('Biblioteca Natus', [
        const Text('Nenhum conteúdo disponível no momento.'),
      ]);
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return blocoFicha('Biblioteca Natus', [
      Text(
        'Conteúdos selecionados para apoiar sua jornada.',
        style: TextStyle(color: NatusApp.textoSuave),
      ),

      const SizedBox(height: 20),

      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: itensAtivos.map((item) {
          return SizedBox(
            width: isMobile ? 160 : 220,
            child: cardBibliotecaNetflix(item, largura: isMobile ? 160 : 220),
          );
        }).toList(),
      ),
    ]);
  }

  Map<String, String>? proximaParcelaGestante(Map<String, String> g) {
    final nomeGestante = g['nomeGestante'] ?? '';

    final pendentes = parcelasFinanceiras.where((p) {
      return p['gestante'] == nomeGestante && p['status'] != 'Pago';
    }).toList();

    if (pendentes.isEmpty) {
      return null;
    }

    pendentes.sort((a, b) {
      final dataA = converterDataBr(a['vencimento'] ?? '');
      final dataB = converterDataBr(b['vencimento'] ?? '');

      return dataA.compareTo(dataB);
    });

    return pendentes.first;
  }

  DateTime converterDataBr(String data) {
    try {
      final partes = data.split('/');

      if (partes.length != 3) {
        return DateTime(2100);
      }

      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);

      return DateTime(ano, mes, dia);
    } catch (e) {
      return DateTime(2100);
    }
  }

  Widget telaAreaGestante() {
    if (gestantes.isEmpty) {
      return const Center(child: Text('Nenhuma gestante vinculada.'));
    }

    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

    final gestantesVinculadas = gestantes.where((g) {
      return g['uidGestante'] == uidLogado;
    }).toList();

    if (gestantesVinculadas.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma gestante vinculada a este login.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: NatusApp.vinho,
          ),
        ),
      );
    }

    final g = gestantesVinculadas.first;

    final nome = g['nomeGestante'] ?? '';
    final bebe = g['nomeBebe'] ?? 'seu bebê';
    final dpp = g['dpp'] ?? '';

    final idadeGestacional = calcularIdadeGestacional(dpp);
    final semanas = calcularSemanas(dpp);
    final fruta = frutaDaSemana(semanas);
    final diasRestantes = diasParaDpp(dpp);

    final proximaParcela = proximaParcelaGestante(g);
    final parcelaAtrasada =
        proximaParcela != null &&
        converterDataBr(
          proximaParcela['vencimento'] ?? '',
        ).isBefore(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: NatusSaudacaoDashboard(
                  nome,
                  subtitulo: 'Como você e o bebê estão hoje?',
                ),
              ),

              const SizedBox(height: 28),

              cardHeroGestantePremium(
                bebe: bebe,
                idadeGestacional: idadeGestacional,
                semanas: semanas,
                fruta: fruta,
                diasRestantes: diasRestantes,
              ),

              const SizedBox(height: 28),

              cardTimelineGestacional(semanas),

              const SizedBox(height: 28),

              vitrineBibliotecaGestante(),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: parcelaAtrasada
                        ? [const Color(0xFFFFF5F5), const Color(0xFFFFE8E8)]
                        : [NatusApp.offWhite, const Color(0xFFFFF4F0)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: parcelaAtrasada
                        ? Colors.red.withValues(alpha: 0.35)
                        : NatusApp.rose.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: parcelaAtrasada
                                ? Colors.red.shade100
                                : NatusApp.rose.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            parcelaAtrasada
                                ? Icons.warning_rounded
                                : Icons.payments_rounded,
                            color: parcelaAtrasada
                                ? Colors.red
                                : NatusApp.vinho,
                            size: 28,
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parcelaAtrasada
                                    ? 'Atenção financeira'
                                    : 'Financeiro Natus',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: NatusApp.textoSuave,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                parcelaAtrasada
                                    ? 'Parcela em atraso'
                                    : 'Próxima parcela',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: parcelaAtrasada
                                      ? Colors.red
                                      : NatusApp.vinho,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: parcelaAtrasada
                                ? Colors.red.withValues(alpha: 0.10)
                                : const Color(0xFFFFEFEA),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            proximaParcela == null
                                ? 'Sem pendência'
                                : parcelaAtrasada
                                ? 'Em atraso'
                                : 'Pendente',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: parcelaAtrasada
                                  ? Colors.red
                                  : NatusApp.vinho,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: NatusApp.offWhite.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: parcelaAtrasada
                              ? Colors.red.withValues(alpha: 0.18)
                              : NatusApp.rose.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Valor da parcela',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: NatusApp.textoSuave,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  proximaParcela == null
                                      ? 'Nenhuma parcela'
                                      : '${proximaParcela['valor']}',
                                  style: TextStyle(
                                    fontSize: proximaParcela == null ? 20 : 30,
                                    fontWeight: FontWeight.w900,
                                    color: parcelaAtrasada
                                        ? Colors.red
                                        : NatusApp.vinho,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (proximaParcela != null)
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: parcelaAtrasada
                                    ? Colors.red.withValues(alpha: 0.08)
                                    : NatusApp.rose.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                parcelaAtrasada
                                    ? Icons.priority_high_rounded
                                    : Icons.favorite_rounded,
                                color: parcelaAtrasada
                                    ? Colors.red
                                    : NatusApp.vinho,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: NatusApp.offWhite.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vencimento',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: NatusApp.textoSuave,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  proximaParcela == null
                                      ? '--/--/----'
                                      : '${proximaParcela['vencimento']}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: parcelaAtrasada
                                        ? Colors.red
                                        : NatusApp.vinho,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: NatusApp.offWhite.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: NatusApp.textoSuave,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  proximaParcela == null
                                      ? 'Tudo certo'
                                      : parcelaAtrasada
                                      ? 'Regularizar'
                                      : 'Aguardando',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: parcelaAtrasada
                                        ? Colors.red
                                        : NatusApp.vinho,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget telaDocumentos() {
    final gestantesAtivas = gestantesAtivasParaDocumentos();

    if (gestantes.isEmpty) {
      return const Center(child: Text('Nenhuma gestante cadastrada'));
    }

    if (widget.tipoUsuario != 'gestante' && gestantesAtivas.isEmpty) {
      return const Center(
        child: Text('Nenhuma gestante ativa disponível para upload.'),
      );
    }

    final nomesGestantesAtivas = [
      'Selecione',
      ...gestantesAtivas
          .map((g) => g['nomeGestante'] ?? '')
          .where((nome) => nome.trim().isNotEmpty),
    ];

    if (!nomesGestantesAtivas.contains(documentoGestanteSelecionada)) {
      documentoGestanteSelecionada = 'Selecione';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),
          const SizedBox(height: 20),

          bloco('Novo documento', [
            if (widget.tipoUsuario != 'gestante') ...[
              dropdownGrande(
                'Gestante',
                documentoGestanteSelecionada,
                nomesGestantesAtivas,
                (v) {
                  setState(() {
                    documentoGestanteSelecionada = v;
                  });
                },
              ),

              const SizedBox(height: 16),
            ],

            dropdown(
              'Tipo',
              documentoTipoSelecionado,
              ['Exame', 'Contrato', 'Comprovante'],
              (v) {
                setState(() {
                  documentoTipoSelecionado = v;
                });
              },
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () async {
                await selecionarArquivo();
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('Anexar arquivo'),
            ),

            if (arquivoSelecionado != null)
              Text('Arquivo: ${arquivoSelecionado!.name}'),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: salvarDocumento,
              icon: const Icon(Icons.save),
              label: const Text('Salvar documento'),
            ),
          ]),

          const SizedBox(height: 20),

          listaDocumentos(),
        ],
      ),
    );
  }

  Future<void> salvarDocumento() async {
    if (arquivoSelecionado == null) {
      mostrarMensagem('Selecione um arquivo antes de salvar');
      return;
    }

    String gestanteSelecionadaNome = '';

    if (widget.tipoUsuario == 'gestante') {
      final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';
      final gestanteLogada = gestantes.firstWhere(
        (g) => g['uidGestante'] == uidLogado,
        orElse: () => {},
      );
      gestanteSelecionadaNome = gestanteLogada['nomeGestante'] ?? '';
    } else {
      if (documentoGestanteSelecionada.isEmpty ||
          documentoGestanteSelecionada == 'Selecione') {
        mostrarMensagem('Selecione uma gestante ativa.');
        return;
      }

      final gestanteSelecionada = gestantesAtivasParaDocumentos().firstWhere(
        (g) => g['nomeGestante'] == documentoGestanteSelecionada,
        orElse: () => {},
      );

      if (gestanteSelecionada.isEmpty) {
        mostrarMensagem(
          'Essa gestante não está ativa para receber documentos.',
        );
        return;
      }

      gestanteSelecionadaNome = documentoGestanteSelecionada;
    }

    if (gestanteSelecionadaNome.trim().isEmpty) {
      mostrarMensagem('Não foi possível identificar a gestante.');
      return;
    }

    mostrarMensagem('Enviando arquivo...');

    final urlArquivo = await uploadArquivo(arquivoSelecionado!);

    if (urlArquivo == null) {
      mostrarMensagem('Não foi possível enviar o arquivo');
      return;
    }

    final novoDocumento = {
      'nome': arquivoSelecionado!.name,
      'tipo': documentoTipoSelecionado,
      'gestante': gestanteSelecionadaNome,
      'arquivoNome': arquivoSelecionado!.name,
      'arquivoUrl': urlArquivo,
      'data': formatarDataHora(DateTime.now()),
    };

    setState(() {
      documentos.add(novoDocumento);
      documentoTipoSelecionado = 'Exame';
      documentoGestanteSelecionada = 'Selecione';
      arquivoSelecionado = null;
    });

    await firestore.collection('documentos').add(novoDocumento);

    mostrarMensagem('Documento salvo com arquivo!');
  }

  Widget listaDocumentos() {
    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

    List<Map<String, String>> documentosParaMostrar = documentos;

    if (widget.tipoUsuario == 'gestante') {
      final gestanteLogada = gestantes.firstWhere(
        (g) => g['uidGestante'] == uidLogado,
        orElse: () => {},
      );

      final nomeGestanteLogada = gestanteLogada['nomeGestante'] ?? '';

      documentosParaMostrar = documentos.where((d) {
        return d['gestante'] == nomeGestanteLogada;
      }).toList();
    }

    if (documentosParaMostrar.isEmpty) {
      return const Text('Nenhum documento cadastrado');
    }

    DateTime converterDataDocumento(String data) {
      try {
        final partes = data.split(' ');
        final dataPartes = partes[0].split('/');
        final horaPartes = partes.length > 1
            ? partes[1].split(':')
            : ['0', '0'];

        final dia = int.parse(dataPartes[0]);
        final mes = int.parse(dataPartes[1]);
        final ano = int.parse(dataPartes[2]);
        final hora = int.parse(horaPartes[0]);
        final minuto = int.parse(horaPartes[1]);

        return DateTime(ano, mes, dia, hora, minuto);
      } catch (e) {
        return DateTime(1900);
      }
    }

    documentosParaMostrar.sort((a, b) {
      final dataA = converterDataDocumento(a['data'] ?? '');
      final dataB = converterDataDocumento(b['data'] ?? '');

      return dataB.compareTo(dataA);
    });

    final tipos = ['Contrato', 'Comprovante', 'Exame', 'Outro'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tipos.map((tipo) {
        final documentosDoTipo = documentosParaMostrar.where((d) {
          final tipoDocumento = d['tipo'] ?? 'Outro';
          return tipoDocumento == tipo;
        }).toList();

        if (documentosDoTipo.isEmpty) {
          return const SizedBox();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tipo,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),

              const SizedBox(height: 10),

              ...documentosDoTipo.map((d) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: NatusApp.rose,
                      child: Icon(Icons.description, color: NatusApp.vinho),
                    ),
                    title: Text(
                      d['arquivoNome'] ?? d['nome'] ?? 'Documento',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: NatusApp.vinho,
                      ),
                    ),
                    subtitle: Text(
                      '${widget.tipoUsuario == 'gestante' ? '' : 'Gestante: ${d['gestante'] ?? 'Não informada'}\n'}'
                      'Tipo: ${d['tipo'] ?? 'Documento'}\n'
                      'Enviado em: ${d['data'] ?? 'Sem data'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Abrir documento',
                          icon: Icon(Icons.open_in_new, color: NatusApp.vinho),
                          onPressed: () async {
                            final url = d['arquivoUrl'];

                            if (url != null && url.toString().isNotEmpty) {
                              abrirArquivo(url);
                            } else {
                              mostrarMensagem('Documento sem arquivo.');
                            }
                          },
                        ),
                        if (widget.tipoUsuario != 'gestante')
                          IconButton(
                            tooltip: 'Excluir documento',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              excluirDocumento(d);
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget cardDocumentoProntuario(Map<String, String> d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: NatusApp.rose,
          child: Icon(Icons.description, color: NatusApp.vinho),
        ),
        title: Text(
          '${d['tipo'] ?? 'Documento'} - ${d['nome'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Arquivo: ${d['arquivoNome'] ?? 'Sem arquivo'}\n'
          'Data: ${d['data'] ?? 'Sem data'}',
        ),
        trailing: IconButton(
          tooltip: 'Abrir documento',
          icon: Icon(Icons.open_in_new, color: NatusApp.vinho),
          onPressed: () async {
            final url = d['arquivoUrl'];

            if (url != null && url.toString().isNotEmpty) {
              await abrirDocumento(url);
            } else {
              mostrarMensagem('Documento sem arquivo');
            }
          },
        ),
      ),
    );
  }

  Widget telaContracoes() {
    final textoBuscaContracoes = buscaContracoesController.text.trim();

    final gestantesAtivasContracoes = gestantes.where((g) {
      return gestanteAtivaParaContracoes(g) &&
          gestanteApareceNaBusca(g, textoBuscaContracoes);
    }).toList();

    final nomesGestantes = [
      'Selecione',
      ...gestantesAtivasContracoes
          .map((g) => g['nomeGestante'] ?? '')
          .where((nome) => nome.trim().isNotEmpty),
    ];

    if (widget.tipoUsuario == 'gestante') {
      final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

      final gestanteLogada = gestantes.firstWhere(
        (g) => g['uidGestante'] == uidLogado && gestanteAtivaParaContracoes(g),
        orElse: () => {},
      );

      final nomeGestanteLogada = gestanteLogada['nomeGestante'] ?? '';

      if (nomeGestanteLogada.isNotEmpty) {
        contracaoGestanteSelecionada = nomeGestanteLogada;
      } else {
        contracaoGestanteSelecionada = 'Selecione';
      }
    } else {
      if (!nomesGestantes.contains(contracaoGestanteSelecionada)) {
        contracaoGestanteSelecionada = 'Selecione';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contador de Contrações',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Registre início, fim, intensidade e observações de cada contração.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          bloco('Nova contração', [
            if (widget.tipoUsuario != 'gestante') ...[
              TextField(
                controller: buscaContracoesController,
                decoration: const InputDecoration(
                  labelText: 'Buscar gestante ativa',
                  hintText: 'Nome, telefone, e-mail, cidade, hospital...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {
                    if (!nomesGestantes.contains(
                      contracaoGestanteSelecionada,
                    )) {
                      contracaoGestanteSelecionada = 'Selecione';
                    }
                  });
                },
              ),

              const SizedBox(height: 12),

              if (nomesGestantes.length == 1) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NatusApp.rose.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: NatusApp.rose.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    'Nenhuma gestante ativa encontrada para registrar contrações.',
                    style: TextStyle(
                      color: NatusApp.vinho,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],

              dropdownGrande(
                'Gestante',
                contracaoGestanteSelecionada,
                nomesGestantes,
                (v) {
                  setState(() {
                    contracaoGestanteSelecionada = v;
                  });
                },
              ),

              const SizedBox(height: 12),
            ],

            if (inicioContracao != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Contração em andamento\nIniciada às ${inicioContracao!.hour.toString().padLeft(2, '0')}:${inicioContracao!.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: inicioContracao == null
                  ? iniciarContracao
                  : pararContracao,
              icon: Icon(
                inicioContracao == null ? Icons.play_arrow : Icons.stop,
              ),
              label: Text(
                inicioContracao == null
                    ? 'Iniciar contração'
                    : 'Parar contração',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: inicioContracao == null
                    ? Colors.green
                    : Colors.red,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          listaContracoes(),
        ],
      ),
    );
  }

  void iniciarContracao() {
    if (contracaoGestanteSelecionada == 'Selecione') {
      mostrarMensagem('Selecione uma gestante ativa antes de iniciar.');
      return;
    }

    final gestanteAtivaSelecionada = gestantes.any((g) {
      return (g['nomeGestante'] ?? '') == contracaoGestanteSelecionada &&
          gestanteAtivaParaContracoes(g);
    });

    if (!gestanteAtivaSelecionada) {
      mostrarMensagem(
        'Essa gestante não está ativa para registrar contrações.',
      );
      return;
    }

    setState(() {
      inicioContracao = DateTime.now();
    });

    mostrarMensagem('Contração iniciada.');
  }

  void pararContracao() {
    if (inicioContracao == null) {
      mostrarMensagem('Inicie uma contração antes de parar.');
      return;
    }

    final fimContracao = DateTime.now();

    final duracao = fimContracao.difference(inicioContracao!);

    Duration? intervalo;

    final listaGestante = contracoes.where((c) {
      return c['gestante'] == contracaoGestanteSelecionada;
    }).toList();

    if (listaGestante.isNotEmpty) {
      listaGestante.sort((a, b) {
        final dataA = DateTime.tryParse(a['criadoEm'] ?? '') ?? DateTime(1900);
        final dataB = DateTime.tryParse(b['criadoEm'] ?? '') ?? DateTime(1900);
        return dataB.compareTo(dataA);
      });

      final ultima = listaGestante.first;

      final fimAnterior = DateTime.tryParse(ultima['fimISO'] ?? '');

      if (fimAnterior != null) {
        intervalo = inicioContracao!.difference(fimAnterior);
      }
    }

    String intensidadeSelecionada = 'Moderada';
    final observacaoTempController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar contração'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Duração: ${formatarDuracao(duracao)}'),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            intensidadeSelecionada = 'Leve';
                          });
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.sentiment_very_satisfied,
                              color: intensidadeSelecionada == 'Leve'
                                  ? Colors.green
                                  : Colors.grey,
                              size: 40,
                            ),
                            const Text('Leve'),
                          ],
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            intensidadeSelecionada = 'Moderada';
                          });
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.sentiment_neutral,
                              color: intensidadeSelecionada == 'Moderada'
                                  ? Colors.orange
                                  : Colors.grey,
                              size: 40,
                            ),
                            const Text('Moderada'),
                          ],
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            intensidadeSelecionada = 'Forte';
                          });
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.sentiment_very_dissatisfied,
                              color: intensidadeSelecionada == 'Forte'
                                  ? Colors.red
                                  : Colors.grey,
                              size: 40,
                            ),
                            const Text('Forte'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: observacaoTempController,
                    decoration: const InputDecoration(
                      labelText: 'Observação opcional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();

                    setState(() {
                      inicioContracao = null;
                    });
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final novaContracao = {
                      'gestante': contracaoGestanteSelecionada,
                      'inicio': formatarDataHora(inicioContracao!),
                      'inicioISO': inicioContracao!.toIso8601String(),
                      'fim': formatarDataHora(fimContracao),
                      'fimISO': fimContracao.toIso8601String(),
                      'duracao': formatarDuracao(duracao),
                      'intervalo': intervalo == null
                          ? 'Primeira contração'
                          : formatarDuracao(intervalo),
                      'intensidade': intensidadeSelecionada,
                      'observacao': observacaoTempController.text.trim(),
                      'dataRegistro': formatarDataHora(DateTime.now()),
                      'criadoEm': DateTime.now().toIso8601String(),
                    };
                    setState(() {
                      contracoes.add(novaContracao);
                      salvarContracaoFirestore(novaContracao);

                      fimUltimaContracao = fimContracao;
                      inicioContracao = null;
                    });

                    Navigator.of(context).pop();

                    mostrarMensagem('Contração registrada.');
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget listaContracoes() {
    final lista = contracoes.where((c) {
      return c['gestante'] == contracaoGestanteSelecionada;
    }).toList();

    if (lista.isEmpty) {
      return const Text('Nenhuma contração registrada para esta gestante.');
    }

    lista.sort((a, b) {
      final dataA = DateTime.tryParse(a['criadoEm'] ?? '') ?? DateTime(1900);
      final dataB = DateTime.tryParse(b['criadoEm'] ?? '') ?? DateTime(1900);

      return dataB.compareTo(dataA);
    });

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: lista.asMap().entries.map((entry) {
        final index = entry.key;
        final c = entry.value;

        final isUltima = index == 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isUltima ? const Color(0xFFFFEFEA) : NatusApp.offWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isUltima ? NatusApp.vinho : NatusApp.rose,
              child: Icon(
                Icons.timer,
                color: isUltima ? NatusApp.offWhite : NatusApp.vinho,
              ),
            ),
            title: Text(
              'Duração: ${c['duracao'] ?? 'Não informada'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isUltima ? NatusApp.vinho : NatusApp.texto,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Início: ${c['inicio'] ?? '-'}\n'
                  'Fim: ${c['fim'] ?? '-'}\n'
                  'Observação: ${c['observacao'] ?? 'Sem observação'}',
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: NatusApp.vinho.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Intervalo: ${c['intervalo'] ?? 'Não informado'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: NatusApp.vinho,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget telaUsuarios() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('usuarios').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Nenhum usuário cadastrado no sistema.'),
          );
        }

        final usuarios = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controle de Usuários',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Gerencie os perfis de acesso do sistema Natus.',
                style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: abrirPopupCriarUsuario,
                icon: const Icon(Icons.person_add),
                label: const Text('Criar usuário'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NatusApp.vinho,
                  foregroundColor: (NatusApp.escuro
                      ? NatusApp.fundo
                      : NatusApp.offWhite),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: testarImportacaoGestantes2025,
                icon: const Icon(Icons.upload_file),
                label: const Text('Importar XLS/CSV 2025'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NatusApp.rose,
                  foregroundColor: NatusApp.vinho,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: importarGestantes2026,
                icon: const Icon(Icons.upload_file),
                label: const Text('Importar XLS/CSV 2026'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NatusApp.vinho,
                  foregroundColor: (NatusApp.escuro
                      ? NatusApp.fundo
                      : NatusApp.offWhite),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ...usuarios.map((doc) {
                final dados = doc.data() as Map<String, dynamic>;
                final tipo = dados['tipo'] ?? 'sem tipo';
                final nome = dados['nome'] ?? 'Usuário sem nome';
                final email = dados['email'] ?? 'E-mail não informado';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => alterarTipoUsuario(doc.id, tipo),
                    leading: CircleAvatar(
                      backgroundColor: NatusApp.rose,
                      child: Icon(Icons.person, color: NatusApp.vinho),
                    ),
                    title: Text(
                      nome,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$email • Tipo de acesso: $tipo'),
                    trailing: IconButton(
                      tooltip: 'Excluir usuário',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Excluir usuário'),
                              content: Text(
                                'Deseja realmente excluir o usuário $nome?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: (NatusApp.escuro
                                        ? NatusApp.fundo
                                        : NatusApp.offWhite),
                                  ),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmar == true) {
                          await firestore
                              .collection('usuarios')
                              .doc(doc.id)
                              .delete();

                          mostrarMensagem('Usuário excluído.');
                        }
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget telaProntuario() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prontuário Obstétrico',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Área clínica da gestante com anamnese e evolução.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonFormField<Map<String, String>>(
              initialValue: gestanteProntuarioSelecionada,
              decoration: InputDecoration(
                labelText: 'Selecionar gestante',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: gestantes
                  .where((g) {
                    final status = (g['statusGestante'] ?? '').trim();

                    return status == 'Gestante' || status == 'Puérpera';
                  })
                  .map((g) {
                    return DropdownMenuItem(
                      value: g,
                      child: Text(
                        g['nomeGestante'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  })
                  .toList(),
              onChanged: (value) {
                setState(() {
                  gestanteProntuarioSelecionada = value;
                });
              },
            ),
          ),

          const SizedBox(height: 24),

          if (gestanteProntuarioSelecionada != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: NatusApp.offWhite,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gestanteProntuarioSelecionada!['nomeGestante'] ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: NatusApp.vinho,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      chipProntuario(
                        Icons.favorite,
                        'DPP',
                        gestanteProntuarioSelecionada!['dpp'] ?? '-',
                      ),

                      chipProntuario(
                        Icons.local_hospital,
                        'Hospital',
                        gestanteProntuarioSelecionada!['hospitalGestante'] ??
                            '-',
                      ),

                      chipProntuario(
                        Icons.medical_services,
                        'Obstetra',
                        gestanteProntuarioSelecionada!['obstetraGestante'] ??
                            '-',
                      ),

                      chipProntuario(
                        Icons.phone,
                        'Telefone',
                        gestanteProntuarioSelecionada!['telefoneGestante'] ??
                            '-',
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Seções do prontuário',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NatusApp.vinho,
                    ),
                  ),

                  const SizedBox(height: 18),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isMobile ? 2 : 4,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.3,
                    children: [
                      cardSessaoProntuario(Icons.assignment, 'Anamnese'),
                      cardSessaoProntuario(Icons.monitor_heart, 'Evolução'),
                      cardSessaoProntuario(
                        Icons.health_and_safety,
                        'Exame físico',
                      ),
                      cardSessaoProntuario(
                        Icons.medical_information,
                        'Plano de cuidado',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (secaoProntuarioSelecionada == 'Anamnese')
                    blocoAnamneseProntuario(gestanteProntuarioSelecionada!),

                  if (secaoProntuarioSelecionada == 'Evolução')
                    blocoEvolucaoProntuario(gestanteProntuarioSelecionada!),

                  if (secaoProntuarioSelecionada == 'Exame físico')
                    blocoExameFisicoProntuario(gestanteProntuarioSelecionada!),

                  if (secaoProntuarioSelecionada == 'Plano de cuidado')
                    blocoPlanoCuidadoProntuario(gestanteProntuarioSelecionada!),
                  const SizedBox(height: 24),

                  timelineProntuario(gestanteProntuarioSelecionada!),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget chipProntuario(IconData icone, String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NatusApp.rose.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 18, color: NatusApp.vinho),

          const SizedBox(width: 8),

          Text(
            '$titulo: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          Text(valor),
        ],
      ),
    );
  }

  Widget cardSessaoProntuario(IconData icone, String titulo) {
    final selecionado = secaoProntuarioSelecionada == titulo;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          secaoProntuarioSelecionada = titulo;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selecionado ? NatusApp.vinho : NatusApp.offWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado
                ? NatusApp.vinho
                : NatusApp.rose.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: selecionado
                  ? NatusApp.offWhite.withValues(alpha: 0.18)
                  : NatusApp.rose.withValues(alpha: 0.18),
              child: Icon(
                icone,
                color: selecionado ? NatusApp.offWhite : NatusApp.vinho,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selecionado ? NatusApp.offWhite : NatusApp.vinho,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> salvarAnamneseProntuario(Map<String, String> g) async {
    final idGestante = g['id'] ?? '';

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: gestante sem ID.');
      return;
    }

    try {
      await firestore.collection('prontuario_atendimentos').add({
        'idGestante': idGestante,
        'nomeGestante': g['nomeGestante'] ?? '',
        'tipo': 'Anamnese',
        'queixaPrincipal': anamneseQueixaController.text.trim(),
        'historicoObstetrico': anamneseHistoricoObstetricoController.text
            .trim(),
        'historicoSaude': anamneseHistoricoSaudeController.text.trim(),
        'alergias': anamneseAlergiasController.text.trim(),
        'medicamentos': anamneseMedicamentosController.text.trim(),
        'habitos': anamneseHabitosController.text.trim(),
        'aspectosEmocionais': anamneseEmocionalController.text.trim(),
        'planejamentoParto': anamnesePartoController.text.trim(),
        'amamentacao': anamneseAmamentacaoController.text.trim(),
        'eo': usuarioEhAdmin() ? eoResponsavelProntuario : nomeEoLogada(),
        'data': formatarDataHora(DateTime.now()),
        'criadoEm': DateTime.now().toIso8601String(),
      });

      anamneseQueixaController.clear();
      anamneseHistoricoObstetricoController.clear();
      anamneseHistoricoSaudeController.clear();
      anamneseAlergiasController.clear();
      anamneseMedicamentosController.clear();
      anamneseHabitosController.clear();
      anamneseEmocionalController.clear();
      anamnesePartoController.clear();
      anamneseAmamentacaoController.clear();

      setState(() {});

      mostrarMensagem('Anamnese salva como novo atendimento.');
    } catch (e) {
      mostrarMensagem('Erro ao salvar anamnese: $e');
    }
  }

  Future<void> salvarExameFisicoProntuario(Map<String, String> g) async {
    final idGestante = g['id'] ?? '';

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: gestante sem ID.');
      return;
    }

    try {
      await firestore.collection('prontuario_atendimentos').add({
        'idGestante': idGestante,
        'nomeGestante': g['nomeGestante'] ?? '',
        'tipo': 'Exame físico',
        'pa': examePaController.text.trim(),
        'fc': exameFcController.text.trim(),
        'temperatura': exameTemperaturaController.text.trim(),
        'peso': examePesoController.text.trim(),
        'altura': exameAlturaController.text.trim(),
        'imc': exameImcController.text.trim(),
        'alturaUterina': exameAlturaUterinaController.text.trim(),
        'bcf': exameBcfController.text.trim(),
        'edema': exameEdemaController.text.trim(),
        'mamas': exameMamasController.text.trim(),
        'abdome': exameAbdomeController.text.trim(),
        'observacoes': exameObservacoesController.text.trim(),
        'eo': usuarioEhAdmin() ? eoResponsavelProntuario : nomeEoLogada(),
        'data': formatarDataHora(DateTime.now()),
        'criadoEm': DateTime.now().toIso8601String(),
      });

      examePaController.clear();
      exameFcController.clear();
      exameTemperaturaController.clear();
      examePesoController.clear();
      exameAlturaController.clear();
      exameImcController.clear();
      exameAlturaUterinaController.clear();
      exameBcfController.clear();
      exameEdemaController.clear();
      exameMamasController.clear();
      exameAbdomeController.clear();
      exameObservacoesController.clear();

      setState(() {});

      mostrarMensagem('Exame físico salvo como novo atendimento.');
    } catch (e) {
      mostrarMensagem('Erro ao salvar exame físico: $e');
    }
  }

  Future<void> salvarPlanoCuidadoProntuario(Map<String, String> g) async {
    final idGestante = g['id'] ?? '';

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: gestante sem ID.');
      return;
    }

    try {
      await firestore.collection('prontuario_atendimentos').add({
        'idGestante': idGestante,
        'nomeGestante': g['nomeGestante'] ?? '',
        'tipo': 'Plano de cuidado',
        'condutas': planoCondutasController.text.trim(),
        'orientacoes': planoOrientacoesController.text.trim(),
        'encaminhamentos': planoEncaminhamentosController.text.trim(),
        'retorno': planoRetornoController.text.trim(),
        'observacoes': planoObservacoesController.text.trim(),
        'eo': usuarioEhAdmin() ? eoResponsavelProntuario : nomeEoLogada(),
        'data': formatarDataHora(DateTime.now()),
        'criadoEm': DateTime.now().toIso8601String(),
      });

      planoCondutasController.clear();
      planoOrientacoesController.clear();
      planoEncaminhamentosController.clear();
      planoRetornoController.clear();
      planoObservacoesController.clear();

      setState(() {});

      mostrarMensagem('Plano de cuidado salvo.');
    } catch (e) {
      mostrarMensagem('Erro ao salvar plano de cuidado: $e');
    }
  }

  Future<void> salvarEvolucaoProntuario(Map<String, String> g) async {
    final idGestante = g['id'] ?? '';
    final nomeGestante = g['nomeGestante'] ?? '';
    final texto = observacaoProntuarioController.text.trim();

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: gestante sem ID.');
      return;
    }

    if (texto.isEmpty) {
      mostrarMensagem('Digite uma evolução.');
      return;
    }

    try {
      await firestore.collection('prontuarios').add({
        'idGestante': idGestante,
        'nomeGestante': nomeGestante,
        'texto': texto,
        'data': formatarDataHora(DateTime.now()),
        'criadoEm': DateTime.now().toIso8601String(),
        'eo': usuarioEhAdmin() ? eoResponsavelProntuario : nomeEoLogada(),
        'tipo': tipoObservacaoProntuario,
        'anexo': nomeArquivoSelecionado,
      });

      observacaoProntuarioController.clear();
      nomeArquivoSelecionado = '';

      setState(() {});

      mostrarMensagem('Evolução registrada no prontuário.');
    } catch (e) {
      mostrarMensagem('Erro ao salvar evolução: $e');
    }
  }

  Widget infoCompactaProntuario(String titulo, String valor) {
    final texto = valor.trim().isEmpty ? 'Não informado' : valor.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: NatusApp.textoSuave,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            texto,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: 15,
              color: NatusApp.vinho,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget blocoAnamneseProntuario(Map<String, String> g) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return blocoFicha('Anamnese', [
      infoCompactaProntuario('Nome completo', g['nomeGestante'] ?? ''),
      infoCompactaProntuario('Telefone', g['telefoneGestante'] ?? ''),
      infoCompactaProntuario('DPP', g['dpp'] ?? ''),

      const SizedBox(height: 16),

      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(
              anamneseQueixaController,
              'Queixa principal / demanda atual',
            ),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(
              anamneseHistoricoObstetricoController,
              'Histórico obstétrico',
            ),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(
              anamneseHistoricoSaudeController,
              'Histórico de saúde',
            ),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(anamneseAlergiasController, 'Alergias'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(anamneseMedicamentosController, 'Medicamentos em uso'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(anamneseHabitosController, 'Hábitos e rotina'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(
              anamneseEmocionalController,
              'Aspectos emocionais e rede de apoio',
            ),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(anamnesePartoController, 'Planejamento de parto'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(
              anamneseAmamentacaoController,
              'Intenção / histórico de amamentação',
            ),
          ),
        ],
      ),

      const SizedBox(height: 18),

      ElevatedButton.icon(
        onPressed: () async {
          await salvarAnamneseProntuario(g);
        },
        icon: const Icon(Icons.save),
        label: const Text('Salvar anamnese'),
        style: ElevatedButton.styleFrom(
          backgroundColor: NatusApp.vinho,
          foregroundColor: (NatusApp.escuro
              ? NatusApp.fundo
              : NatusApp.offWhite),
        ),
      ),
    ]);
  }

  Widget blocoExameFisicoProntuario(Map<String, String> g) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return blocoFicha('Exame físico', [
      infoCompactaProntuario('Nome completo', g['nomeGestante'] ?? ''),
      infoCompactaProntuario('DPP', g['dpp'] ?? ''),

      const SizedBox(height: 16),

      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(examePaController, 'PA'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(exameFcController, 'FC'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(exameTemperaturaController, 'Temperatura'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(examePesoController, 'Peso'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(exameAlturaController, 'Altura'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(exameImcController, 'IMC'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(exameAlturaUterinaController, 'Altura uterina'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(exameBcfController, 'BCF'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(exameEdemaController, 'Edema'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(exameMamasController, 'Mamas'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(exameAbdomeController, 'Abdome'),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(exameObservacoesController, 'Observações clínicas'),
          ),
        ],
      ),

      const SizedBox(height: 18),

      ElevatedButton.icon(
        onPressed: () async {
          await salvarExameFisicoProntuario(g);
        },
        icon: const Icon(Icons.save),
        label: const Text('Salvar exame físico'),
        style: ElevatedButton.styleFrom(
          backgroundColor: NatusApp.vinho,
          foregroundColor: (NatusApp.escuro
              ? NatusApp.fundo
              : NatusApp.offWhite),
        ),
      ),
    ]);
  }

  Widget blocoPlanoCuidadoProntuario(Map<String, String> g) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return blocoFicha('Plano de cuidado', [
      infoCompactaProntuario('Nome completo', g['nomeGestante'] ?? ''),
      infoCompactaProntuario('DPP', g['dpp'] ?? ''),

      const SizedBox(height: 16),

      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(planoCondutasController, 'Condutas realizadas'),
          ),

          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(planoOrientacoesController, 'Orientações fornecidas'),
          ),

          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(planoEncaminhamentosController, 'Encaminhamentos'),
          ),

          SizedBox(
            width: isMobile ? double.infinity : 300,
            child: campo(planoRetornoController, 'Retorno previsto'),
          ),

          SizedBox(
            width: isMobile ? double.infinity : 500,
            child: campo(planoObservacoesController, 'Observações adicionais'),
          ),
        ],
      ),

      const SizedBox(height: 18),

      ElevatedButton.icon(
        onPressed: () async {
          await salvarPlanoCuidadoProntuario(g);
        },
        icon: const Icon(Icons.save),
        label: const Text('Salvar plano de cuidado'),
        style: ElevatedButton.styleFrom(
          backgroundColor: NatusApp.vinho,
          foregroundColor: (NatusApp.escuro
              ? NatusApp.fundo
              : NatusApp.offWhite),
        ),
      ),
    ]);
  }

  Widget timelineProntuario(Map<String, String> g) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('prontuario_atendimentos')
          .where('idGestante', isEqualTo: g['id'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return blocoFicha('Histórico clínico', [
            const Text('Nenhum atendimento registrado ainda.'),
          ]);
        }

        final atendimentos = docs.map((d) {
          final dados = d.data() as Map<String, dynamic>;

          return dados.map((k, v) {
            return MapEntry(k, v.toString());
          });
        }).toList();

        atendimentos.sort((a, b) {
          return (b['criadoEm'] ?? '').compareTo(a['criadoEm'] ?? '');
        });

        return blocoFicha('Histórico clínico', [
          ...atendimentos.map((a) {
            final tipo = a['tipo'] ?? '';
            final eo = a['eo'] ?? '';
            final data = a['data'] ?? '';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NatusApp.offWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: NatusApp.rose.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: NatusApp.rose.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.medical_services,
                          color: NatusApp.vinho,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tipo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: NatusApp.vinho,
                              ),
                            ),

                            Text(
                              '$data — $eo',
                              style: TextStyle(color: NatusApp.textoSuave),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  ...a.entries
                      .where((e) {
                        return ![
                          'idGestante',
                          'nomeGestante',
                          'tipo',
                          'eo',
                          'data',
                          'criadoEm',
                        ].contains(e.key);
                      })
                      .map((e) {
                        if (e.value.trim().isEmpty) {
                          return const SizedBox();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: NatusApp.texto,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '${e.key}: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: NatusApp.vinho,
                                  ),
                                ),
                                TextSpan(text: e.value),
                              ],
                            ),
                          ),
                        );
                      }),
                ],
              ),
            );
          }),
        ]);
      },
    );
  }

  Widget blocoEvolucaoProntuario(Map<String, String> g) {
    return blocoFicha('Evoluções do prontuário', [
      if (usuarioEhAdmin())
        dropdown('Responsável', eoResponsavelProntuario, [], (v) {
          setState(() {
            eoResponsavelProntuario = v;
          });
        })
      else
        campoInfo('Responsável', nomeEoLogada()),

      const SizedBox(height: 10),

      dropdown(
        'Tipo',
        tipoObservacaoProntuario,
        ['Evolução', 'Orientação', 'Intercorrência', 'Retorno'],
        (v) {
          setState(() {
            tipoObservacaoProntuario = v;
          });
        },
      ),

      const SizedBox(height: 10),

      campo(observacaoProntuarioController, 'Digite a evolução ou observação'),

      const SizedBox(height: 10),

      ElevatedButton.icon(
        onPressed: () async {
          await selecionarArquivo();
        },
        icon: const Icon(Icons.attach_file),
        label: const Text('Anexar arquivo'),
      ),

      const SizedBox(height: 10),

      ElevatedButton.icon(
        onPressed: () async {
          await salvarEvolucaoProntuario(g);
        },
        icon: const Icon(Icons.save),
        label: const Text('Salvar evolução'),
      ),

      const SizedBox(height: 15),

      StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('prontuarios')
            .where('idGestante', isEqualTo: g['id'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            );
          }

          final evolucoes = snapshot.data!.docs;

          if (evolucoes.isEmpty) {
            return const Text('Nenhuma evolução registrada ainda.');
          }

          final lista = evolucoes.map((doc) {
            final dados = doc.data() as Map<String, dynamic>;

            return dados.map((chave, valor) {
              return MapEntry(chave, valor.toString());
            });
          }).toList();

          lista.sort((a, b) {
            final dataA = a['criadoEm'] ?? '';
            final dataB = b['criadoEm'] ?? '';
            return dataB.compareTo(dataA);
          });

          return Column(
            children: lista.map((o) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: corPorTipoObservacao(
                    o['tipo'] ?? '',
                  ).withValues(alpha: 0.1),
                  border: Border.all(
                    color: corPorTipoObservacao(o['tipo'] ?? ''),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${o['data']} — ${o['eo']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: corPorTipoObservacao(o['tipo'] ?? ''),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      o['tipo'] ?? '',
                      style: TextStyle(
                        color: corPorTipoObservacao(o['tipo'] ?? ''),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(o['texto'] ?? ''),
                    if ((o['anexo'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'Anexo: ${o['anexo']}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    ]);
  }

  Widget telaConfiguracoes() {
    final paletaAtiva = NatusTema.paleta;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configurações',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Personalize a aparência do Natus. A escolha vale para o seu '
            'login e fica salva para as próximas sessões.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          bloco('Tema do aplicativo', [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: NatusTema.paletas
                  .map((p) => cartaoTema(p, p.chave == paletaAtiva.chave))
                  .toList(),
            ),
          ]),
        ],
      ),
    );
  }

  Widget cartaoTema(NatusPaleta p, bool ativo) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => selecionarTema(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.offWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ativo ? p.marsala : p.begeEscuro,
            width: ativo ? 2.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                bolinhaCor(p.marsala),
                const SizedBox(width: 6),
                bolinhaCor(p.dourado),
                const SizedBox(width: 6),
                bolinhaCor(p.fundo, borda: p.begeEscuro),
                const Spacer(),
                if (ativo) Icon(Icons.check_circle, color: p.marsala, size: 20),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              p.nome,
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),

            const SizedBox(height: 2),

            Text(
              p.descricao,
              style: TextStyle(fontSize: 12, color: p.textoSuave),
            ),
          ],
        ),
      ),
    );
  }

  Widget bolinhaCor(Color c, {Color? borda}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(
          color: borda ?? NatusApp.begeEscuro.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Future<void> selecionarTema(NatusPaleta p) async {
    NatusTema.aplicarPorChave(p.chave);

    if (mounted) setState(() {});

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await firestore.collection('usuarios').doc(uid).set({
          'tema': p.chave,
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Sem rede a troca continua valendo na sessão atual.
    }
  }

  Future<void> carregarTemaUsuario() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await firestore.collection('usuarios').doc(uid).get();
      final tema = (doc.data() ?? const {})['tema']?.toString() ?? '';

      if (tema.isNotEmpty) {
        NatusTema.aplicarPorChave(tema);
      }
    } catch (_) {
      // Mantém o tema padrão se não conseguir ler.
    }
  }

  Widget telaSimples(String texto) {
    return Center(
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: NatusApp.vinho,
        ),
      ),
    );
  }

  Widget telaMapa() {
    final larguraTela = MediaQuery.of(context).size.width;
    final isMobile = larguraTela < 700;

    if (!mapaJaCarregado && !carregandoMapa) {
      carregandoMapa = true;

      Future.microtask(() async {
        await carregarMarcadores();

        if (mounted) {
          setState(() {
            carregandoMapa = false;
            mapaJaCarregado = true;
          });
        }
      });
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: NatusApp.fundo,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            color: NatusApp.offWhite,
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map, color: NatusApp.vinho),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mapa de gestantes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: NatusApp.vinho,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setState(() {
                              mapaJaCarregado = false;
                              carregandoMapa = false;
                              marcadores.clear();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar mapa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NatusApp.vinho,
                            foregroundColor: (NatusApp.escuro
                                ? NatusApp.fundo
                                : NatusApp.offWhite),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.map, color: NatusApp.vinho),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mapa de gestantes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: NatusApp.vinho,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            mapaJaCarregado = false;
                            carregandoMapa = false;
                            marcadores.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Atualizar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NatusApp.vinho,
                          foregroundColor: (NatusApp.escuro
                              ? NatusApp.fundo
                              : NatusApp.offWhite),
                        ),
                      ),
                    ],
                  ),
          ),

          if (carregandoMapa) const LinearProgressIndicator(),

          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 8 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 18 : 0),
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(-25.4284, -49.2733),
                    zoom: 11,
                  ),
                  myLocationEnabled: false,
                  zoomControlsEnabled: !isMobile,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  markers: marcadores,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget bloco(String titulo, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: NatusApp.vinho.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: NatusApp.vinho,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(spacing: 12, runSpacing: 12, children: children),
          ),
        ],
      ),
    );
  }

  Widget campo(
    TextEditingController controller,
    String label, {
    MaskTextInputFormatter? mask,
    double largura = 230,
  }) {
    return SizedBox(
      width: largura,
      child: TextFormField(
        controller: controller,
        inputFormatters: mask != null ? [mask] : [],
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: NatusApp.vinho, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget campoBloqueado(TextEditingController controller, String label) {
    return SizedBox(
      width: 230,
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: const Color(0xFFF7F1EF),
        ),
      ),
    );
  }

  Widget campoFull(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always, // 👈 ESSENCIAL
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
    );
  }

  Widget campoBloqueadoFull(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        filled: true,
        fillColor: const Color(0xFFF7F1EF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
    );
  }

  Widget seletorPlanoGestante() {
    final planosAtivos = planosCadastrados
        .where((p) => p['ativo'] != false)
        .toList();

    if (planosAtivos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0B36B)),
        ),
        child: const Text(
          'Nenhum plano ativo cadastrado. Cadastre um plano em “Planos da Natus” antes de cadastrar a gestante.',
          style: TextStyle(
            color: Color(0xFF7A4A00),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final valorAtualExiste = planosAtivos.any(
      (p) => (p['id'] ?? '').toString() == planoIdSelecionado,
    );
    final valorDropdown = valorAtualExiste
        ? planoIdSelecionado
        : (planosAtivos.first['id'] ?? '').toString();

    if (!valorAtualExiste && planoIdSelecionado.isEmpty) {
      Future.microtask(() => aplicarPlanoSelecionado(valorDropdown));
    }

    return DropdownButtonFormField<String>(
      initialValue: valorDropdown,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Plano',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
      items: planosAtivos.map((p) {
        final id = (p['id'] ?? '').toString();
        final nome = (p['nomePlano'] ?? '').toString();
        final valor = converterValorDinamico(p['valor']);
        return DropdownMenuItem(
          value: id,
          child: Text('$nome • ${formatarMoeda(valor)}'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) aplicarPlanoSelecionado(value);
      },
    );
  }

  String enderecoCompletoGestante(Map<String, String> g) {
    final rua = (g['enderecoGestante'] ?? '').trim();
    final numero = (g['numeroGestante'] ?? '').trim();
    final complemento = (g['complementoGestante'] ?? '').trim();
    final bairro = (g['bairroGestante'] ?? '').trim();
    final cidade = (g['cidadeGestante'] ?? '').trim();
    final estado = (g['estadoGestante'] ?? 'PR').trim().isEmpty
        ? 'PR'
        : (g['estadoGestante'] ?? 'PR').trim();
    final cep = (g['cepGestante'] ?? '').trim();

    final linha1 = [rua, numero].where((v) => v.isNotEmpty).join(', ');
    final partes = <String>[];

    if (linha1.isNotEmpty) partes.add(linha1);
    if (complemento.isNotEmpty) partes.add(complemento);
    if (bairro.isNotEmpty) partes.add(bairro);
    if (cidade.isNotEmpty || estado.isNotEmpty) {
      partes.add([cidade, estado].where((v) => v.isNotEmpty).join(' - '));
    }
    if (cep.isNotEmpty) partes.add('CEP $cep');

    return partes.isEmpty ? 'Endereço não informado' : partes.join('\n');
  }

  double valorTotalNfseGestante(Map<String, String> g) {
    final valorPlano = converterValor(g['valorPlano'] ?? '0');
    if (valorPlano > 0) return valorPlano;

    final parcelas = parcelasDaGestanteFicha(g);
    return totalParcelasPorStatusGestante(parcelas, (_) => true);
  }

  String descricaoNfseGestante(Map<String, String> g) {
    final descricao = (g['descricaoNfse'] ?? '').trim();
    if (descricao.isNotEmpty) return descricao;

    final plano = (g['plano'] ?? '').trim();
    if (plano.isNotEmpty) {
      return 'Serviços de enfermagem obstétrica, acompanhamento gestacional, consultoria de amamentação e assistência materno neonatal vinculados ao plano $plano.';
    }

    return 'Serviços de enfermagem obstétrica, acompanhamento gestacional, consultoria de amamentação e assistência materno neonatal.';
  }

  Map<String, String>? notaFiscalDaGestante(
    Map<String, String> g,
    List<Map<String, String>> notas,
  ) {
    final gestanteId = (g['id'] ?? '').trim();
    final nomeGestante = (g['nomeGestante'] ?? '').trim();

    final notasGestante = notas.where((n) {
      final notaGestanteId = (n['gestanteId'] ?? '').trim();
      final notaNome = (n['nomeTomador'] ?? n['gestante'] ?? '').trim();
      return (gestanteId.isNotEmpty && notaGestanteId == gestanteId) ||
          (nomeGestante.isNotEmpty && notaNome == nomeGestante);
    }).toList();

    if (notasGestante.isEmpty) return null;

    notasGestante.sort((a, b) {
      final dataA = (a['criadoEm'] ?? '').trim();
      final dataB = (b['criadoEm'] ?? '').trim();
      return dataB.compareTo(dataA);
    });

    return notasGestante.first;
  }

  String statusNfseTexto(Map<String, String>? nota) {
    final status = (nota?['status'] ?? '').trim().toUpperCase();

    switch (status) {
      case 'EMITIDA':
      case 'AUTORIZADA':
        return 'Emitida';
      case 'PROCESSANDO':
      case 'EM_PROCESSAMENTO':
      case 'PENDENTE_FOCUS':
      case 'PRONTA_PARA_EMISSAO':
        return 'Pendente';
      case 'ERRO':
      case 'REJEITADA':
      case 'CANCELADA':
        return 'Erro';
      default:
        return 'Não emitida';
    }
  }

  Color statusNfseCor(Map<String, String>? nota) {
    final status = statusNfseTexto(nota);

    if (status == 'Emitida') return Colors.green;
    if (status == 'Pendente') return Colors.orange;
    if (status == 'Erro') return Colors.red;
    return Colors.grey;
  }

  Widget badgeNfse(Map<String, String>? nota) {
    final texto = statusNfseTexto(nota);
    final cor = statusNfseCor(nota);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Future<List<Map<String, String>>> carregarNotasFiscaisNfse() async {
    final resultado = await firestore.collection('notas_fiscais').get();

    return resultado.docs.map((doc) {
      final dados = doc.data();
      final mapa = dados.map((chave, valor) {
        return MapEntry(chave, valor?.toString() ?? '');
      });
      mapa['id'] = doc.id;
      return mapa;
    }).toList();
  }

  Widget miniCardNfse(String titulo, String valor, IconData icone, Color cor) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: cor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: cor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 12, color: NatusApp.textoSuave),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.vinho,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget telaCentralNfse() {
    return FutureBuilder<List<Map<String, String>>>(
      future: carregarNotasFiscaisNfse(),
      builder: (context, snapshot) {
        final notas = snapshot.data ?? [];
        final totalGestantes = gestantes.length;
        final emitidas = gestantes.where((g) {
          final nota = notaFiscalDaGestante(g, notas);
          return statusNfseTexto(nota) == 'Emitida';
        }).length;
        final pendentes = gestantes.where((g) {
          final nota = notaFiscalDaGestante(g, notas);
          return statusNfseTexto(nota) == 'Pendente';
        }).length;
        final naoEmitidas = totalGestantes - emitidas - pendentes;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Central de NFS-e',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Gere manualmente a nota fiscal de serviço pelo valor total do plano da cliente selecionada.',
                style: TextStyle(fontSize: 14, color: NatusApp.textoSuave),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  miniCardNfse(
                    'Clientes',
                    totalGestantes.toString(),
                    Icons.people_alt_rounded,
                    NatusApp.vinho,
                  ),
                  miniCardNfse(
                    'Emitidas',
                    emitidas.toString(),
                    Icons.check_circle_rounded,
                    Colors.green,
                  ),
                  miniCardNfse(
                    'Pendentes',
                    pendentes.toString(),
                    Icons.pending_actions_rounded,
                    Colors.orange,
                  ),
                  miniCardNfse(
                    'Não emitidas',
                    naoEmitidas.toString(),
                    Icons.receipt_long_rounded,
                    Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              bloco('Gestantes para emissão de NFS-e', [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                else if (gestantes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nenhuma gestante cadastrada.'),
                  )
                else
                  ...gestantes.map((g) {
                    final nota = notaFiscalDaGestante(g, notas);
                    return cardGestanteNfse(g, nota);
                  }),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget cardGestanteNfse(Map<String, String> g, Map<String, String>? nota) {
    final nome = (g['nomeGestante'] ?? 'Gestante sem nome').trim();
    final plano = (g['plano'] ?? 'Plano não informado').trim();
    final cpf = (g['cpfGestante'] ?? '').trim();
    final valorTotal = valorTotalNfseGestante(g);
    final status = statusNfseTexto(nota);
    final podeGerar = status != 'Emitida' && status != 'Pendente';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NatusApp.vinho.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.receipt_long_rounded, color: NatusApp.vinho),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NatusApp.vinho,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$plano • ${formatarMoeda(valorTotal)}',
                      style: TextStyle(color: NatusApp.textoSuave),
                    ),
                    if (cpf.isNotEmpty)
                      Text(
                        'CPF: $cpf',
                        style: TextStyle(color: NatusApp.textoSuave),
                      ),
                  ],
                ),
              ),
              badgeNfse(nota),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: podeGerar
                    ? () async {
                        await abrirModalGerarNfse(g, nota);
                      }
                    : null,
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: Text(podeGerar ? 'Gerar NFS-e' : 'NFS-e em andamento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NatusApp.vinho,
                  foregroundColor: (NatusApp.escuro
                      ? NatusApp.fundo
                      : NatusApp.offWhite),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await abrirModalGerarNfse(g, nota, apenasVisualizar: true);
                },
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Conferir dados'),
              ),
              if (((nota?['pdfUrl'] ?? '').trim()).isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    await abrirDocumento(nota!['pdfUrl'] ?? '');
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Abrir PDF'),
                ),
              if (((nota?['xmlUrl'] ?? '').trim()).isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    await abrirDocumento(nota!['xmlUrl'] ?? '');
                  },
                  icon: const Icon(Icons.code_rounded, size: 18),
                  label: const Text('Abrir XML'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> abrirModalGerarNfse(
    Map<String, String> g,
    Map<String, String>? nota, {
    bool apenasVisualizar = false,
  }) async {
    final valorTotal = valorTotalNfseGestante(g);
    final descricao = descricaoNfseGestante(g);
    final endereco = enderecoCompletoGestante(g);
    final status = statusNfseTexto(nota);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          apenasVisualizar ? 'Conferir dados da NFS-e' : 'Gerar NFS-e',
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                campoResumoNfse('Cliente', g['nomeGestante'] ?? ''),
                campoResumoNfse('CPF', g['cpfGestante'] ?? ''),
                campoResumoNfse('E-mail', g['emailGestante'] ?? ''),
                campoResumoNfse('Telefone', g['telefoneGestante'] ?? ''),
                campoResumoNfse('Endereço', endereco),
                campoResumoNfse('Plano', g['plano'] ?? ''),
                campoResumoNfse(
                  'Valor total da nota',
                  formatarMoeda(valorTotal),
                ),
                campoResumoNfse('Descrição NFS-e', descricao),
                campoResumoNfse('Status atual', status),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          if (!apenasVisualizar && status != 'Emitida' && status != 'Pendente')
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await prepararNfseFocus(g);
              },
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Confirmar NFS-e'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NatusApp.vinho,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
              ),
            ),
        ],
      ),
    );
  }

  Widget campoResumoNfse(String titulo, String valor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: NatusApp.textoSuave,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor.trim().isEmpty ? 'Não informado' : valor,
            style: TextStyle(fontSize: 14, color: NatusApp.texto),
          ),
        ],
      ),
    );
  }

  Future<void> prepararNfseFocus(Map<String, String> g) async {
    final valorTotal = valorTotalNfseGestante(g);
    final gestanteId = (g['id'] ?? '').trim();

    if (valorTotal <= 0) {
      mostrarMensagem('Informe o valor do plano antes de gerar a NFS-e.');
      return;
    }

    if (gestanteId.isEmpty) {
      mostrarMensagem(
        'Gestante sem ID. Recarregue a tela antes de gerar a NFS-e.',
      );
      return;
    }

    if ((g['cpfGestante'] ?? '').trim().isEmpty) {
      mostrarMensagem('Informe o CPF da gestante antes de gerar a NFS-e.');
      return;
    }

    try {
      mostrarMensagem('Enviando NFS-e para a Focus...');

      final notaRef = await firestore.collection('notas_fiscais').add({
        'empresaId': 'natus',
        'gestanteId': gestanteId,
        'gestante': g['nomeGestante'] ?? '',
        'nomeTomador': g['nomeGestante'] ?? '',
        'cpfCnpjTomador': g['cpfGestante'] ?? '',
        'emailTomador': g['emailGestante'] ?? '',
        'telefoneTomador': g['telefoneGestante'] ?? '',
        'endereco': g['enderecoGestante'] ?? '',
        'numero': g['numeroGestante'] ?? '',
        'complemento': g['complementoGestante'] ?? '',
        'bairro': g['bairroGestante'] ?? '',
        'cidade': g['cidadeGestante'] ?? '',
        'estado': g['estadoGestante'] ?? 'PR',
        'cep': g['cepGestante'] ?? '',
        'planoId': g['planoId'] ?? '',
        'plano': g['plano'] ?? '',
        'valorTotal': valorTotal,
        'descricaoServico': descricaoNfseGestante(g),
        'status': 'PROCESSANDO',
        'ambiente': 'homologacao',
        'focusRef': '',
        'pdfUrl': '',
        'xmlUrl': '',
        'criadoEm': formatarDataHora(DateTime.now()),
        'emitidoEm': '',
        'origem': 'central_nfse_manual',
      });

      final callable = FirebaseFunctions.instance.httpsCallable(
        'gerarNfseFocus',
      );
      final resposta = await callable.call({
        'notaFiscalId': notaRef.id,
        'gestanteId': gestanteId,
      });

      final data = Map<String, dynamic>.from(resposta.data as Map);
      final statusRetorno = (data['status'] ?? 'PROCESSANDO').toString();
      final dadosAtualizados = <String, dynamic>{
        'status': statusRetorno,
        'focusRef': (data['focusRef'] ?? data['referencia'] ?? '').toString(),
        'focusNumero': (data['numero'] ?? '').toString(),
        'focusCodigoVerificacao': (data['codigoVerificacao'] ?? '').toString(),
        'pdfUrl': (data['pdfUrl'] ?? data['urlPdf'] ?? '').toString(),
        'xmlUrl': (data['xmlUrl'] ?? data['urlXml'] ?? '').toString(),
        'focusMensagem': (data['mensagem'] ?? '').toString(),
        'atualizadoEm': formatarDataHora(DateTime.now()),
      };

      if (statusRetorno.toUpperCase() == 'EMITIDA' ||
          statusRetorno.toUpperCase() == 'AUTORIZADA') {
        dadosAtualizados['emitidoEm'] = formatarDataHora(DateTime.now());
      }

      await firestore
          .collection('notas_fiscais')
          .doc(notaRef.id)
          .update(dadosAtualizados);

      setState(() {});
      mostrarMensagem('NFS-e enviada para a Focus.');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Erro Firebase Functions Focus: ${e.code} - ${e.message}');
      mostrarMensagem(e.message ?? 'Erro ao gerar NFS-e na Focus.');
    } catch (e) {
      debugPrint('❌ Erro ao gerar NFS-e na Focus: $e');
      mostrarMensagem('Erro ao gerar NFS-e na Focus.');
    }
  }

  Future<List<Map<String, String>>> carregarHistoricoFiscalNfse() async {
    final resultado = await firestore.collection('notas_fiscais').get();

    final notas = resultado.docs.map((doc) {
      final dados = doc.data();
      final mapa = dados.map((chave, valor) {
        return MapEntry(chave, valor?.toString() ?? '');
      });
      mapa['id'] = doc.id;
      return mapa;
    }).toList();

    notas.sort((a, b) {
      final dataA = (a['emitidoEm'] ?? a['atualizadoEm'] ?? a['criadoEm'] ?? '')
          .trim();
      final dataB = (b['emitidoEm'] ?? b['atualizadoEm'] ?? b['criadoEm'] ?? '')
          .trim();
      return dataB.compareTo(dataA);
    });

    return notas;
  }

  double valorNotaFiscal(Map<String, String> nota) {
    return converterValor(nota['valorTotal'] ?? nota['valor'] ?? '0');
  }

  String tituloStatusHistoricoNfse(Map<String, String> nota) {
    final status = (nota['status'] ?? '').trim().toUpperCase();

    if (status == 'EMITIDA' || status == 'AUTORIZADA') return 'Emitida';
    if (status == 'PROCESSANDO' ||
        status == 'EM_PROCESSAMENTO' ||
        status == 'PENDENTE_FOCUS' ||
        status == 'PRONTA_PARA_EMISSAO') {
      return 'Processando';
    }
    if (status == 'CANCELADA') return 'Cancelada';
    if (status == 'ERRO' || status == 'REJEITADA') return 'Erro';
    return status.isEmpty ? 'Sem status' : status;
  }

  Color corStatusHistoricoNfse(Map<String, String> nota) {
    final status = tituloStatusHistoricoNfse(nota);

    if (status == 'Emitida') return Colors.green;
    if (status == 'Processando') return Colors.orange;
    if (status == 'Cancelada') return Colors.grey;
    if (status == 'Erro') return Colors.red;
    return NatusApp.vinho;
  }

  Widget badgeHistoricoNfse(Map<String, String> nota) {
    final cor = corStatusHistoricoNfse(nota);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tituloStatusHistoricoNfse(nota),
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget telaHistoricoFiscalNfse() {
    return FutureBuilder<List<Map<String, String>>>(
      future: carregarHistoricoFiscalNfse(),
      builder: (context, snapshot) {
        final notas = snapshot.data ?? [];
        final emitidas = notas
            .where((n) => tituloStatusHistoricoNfse(n) == 'Emitida')
            .toList();
        final processando = notas
            .where((n) => tituloStatusHistoricoNfse(n) == 'Processando')
            .length;
        final erros = notas
            .where((n) => tituloStatusHistoricoNfse(n) == 'Erro')
            .length;
        final totalEmitido = emitidas.fold<double>(
          0,
          (soma, nota) => soma + valorNotaFiscal(nota),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Histórico Fiscal',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Acompanhe as NFS-e geradas pela Central Fiscal da Natus, com acesso rápido ao PDF e XML.',
                style: TextStyle(fontSize: 14, color: NatusApp.textoSuave),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  miniCardNfse(
                    'Total emitido',
                    formatarMoeda(totalEmitido),
                    Icons.payments_rounded,
                    NatusApp.vinho,
                  ),
                  miniCardNfse(
                    'Notas emitidas',
                    emitidas.length.toString(),
                    Icons.check_circle_rounded,
                    Colors.green,
                  ),
                  miniCardNfse(
                    'Processando',
                    processando.toString(),
                    Icons.pending_actions_rounded,
                    Colors.orange,
                  ),
                  miniCardNfse(
                    'Com erro',
                    erros.toString(),
                    Icons.error_rounded,
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              bloco('Notas fiscais emitidas e registradas', [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                else if (notas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nenhuma NFS-e registrada ainda.'),
                  )
                else
                  ...notas.map(cardHistoricoNfse),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget cardHistoricoNfse(Map<String, String> nota) {
    final cliente =
        (nota['nomeTomador'] ?? nota['gestante'] ?? 'Cliente não informado')
            .trim();
    final plano = (nota['plano'] ?? 'Plano não informado').trim();
    final valor = valorNotaFiscal(nota);
    final numero = (nota['focusNumero'] ?? nota['numero'] ?? '').trim();
    final codigo = (nota['focusCodigoVerificacao'] ?? '').trim();
    final data =
        (nota['emitidoEm'] ?? nota['atualizadoEm'] ?? nota['criadoEm'] ?? '')
            .trim();
    final pdfUrl = (nota['pdfUrl'] ?? '').trim();
    final xmlUrl = (nota['xmlUrl'] ?? '').trim();
    final mensagem = (nota['focusMensagem'] ?? '').trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NatusApp.vinho.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.receipt_long_rounded, color: NatusApp.vinho),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.isEmpty ? 'Cliente não informado' : cliente,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NatusApp.vinho,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$plano • ${formatarMoeda(valor)}',
                      style: TextStyle(color: NatusApp.textoSuave),
                    ),
                  ],
                ),
              ),
              badgeHistoricoNfse(nota),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              chipInfoFiscal(
                Icons.event_rounded,
                data.isEmpty ? 'Data não informada' : data,
              ),
              chipInfoFiscal(
                Icons.numbers_rounded,
                numero.isEmpty ? 'Número não informado' : 'Nº $numero',
              ),
              if (codigo.isNotEmpty)
                chipInfoFiscal(Icons.verified_rounded, 'Cód. $codigo'),
            ],
          ),
          if (mensagem.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              mensagem,
              style: TextStyle(fontSize: 12, color: NatusApp.textoSuave),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pdfUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async => abrirDocumento(pdfUrl),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Abrir PDF'),
                ),
              if (xmlUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async => abrirDocumento(xmlUrl),
                  icon: const Icon(Icons.code_rounded, size: 18),
                  label: const Text('Abrir XML'),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {});
                  mostrarMensagem('Histórico fiscal atualizado.');
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Atualizar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget chipInfoFiscal(IconData icone, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: NatusApp.vinho),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(fontSize: 12, color: NatusApp.textoSuave),
          ),
        ],
      ),
    );
  }

  Widget telaPlanosNatus() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planos da Natus',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: NatusApp.vinho,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cadastre os planos que serão usados no cadastro de gestantes, Asaas, ZapSign e NFS-e.',
            style: TextStyle(fontSize: 13, color: NatusApp.textoSuave),
          ),
          const SizedBox(height: 24),
          bloco('Cadastrar novo plano', [
            Row(
              children: [
                Expanded(
                  child: campoFull(planoNomeController, 'Nome do plano'),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: campoFull(planoValorController, 'Valor total'),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: campoFull(planoParcelasController, 'Parcelas'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            campoFull(planoDescricaoComercialController, 'Descrição comercial'),
            const SizedBox(height: 12),
            campoFull(planoDescricaoNfseController, 'Descrição NFS-e'),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: salvarPlanoNatus,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar plano'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NatusApp.vinho,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          bloco('Planos cadastrados', [
            if (planosCadastrados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Nenhum plano cadastrado ainda.'),
              )
            else
              ...planosCadastrados.map((p) {
                final ativo = p['ativo'] != false;
                final nome = (p['nomePlano'] ?? '').toString();
                final valor = converterValorDinamico(p['valor']);
                final qtdParcelas = (p['parcelas'] ?? '1').toString();
                final descricaoNfse = (p['descricaoNfse'] ?? '').toString();

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ativo
                          ? NatusApp.rose
                          : Colors.grey.shade300,
                      child: Icon(
                        ativo ? Icons.check_rounded : Icons.block_rounded,
                        color: ativo ? NatusApp.vinho : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(
                      nome,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${formatarMoeda(valor)} • $qtdParcelas parcela(s)\nNFS-e: ${descricaoNfse.isEmpty ? 'sem descrição fiscal cadastrada' : descricaoNfse}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          tooltip: 'Editar plano',
                          onPressed: () => editarPlanoNatus(p),
                          icon: const Icon(Icons.edit_rounded),
                          color: NatusApp.vinho,
                        ),
                        TextButton(
                          onPressed: () => alterarStatusPlano(p),
                          child: Text(ativo ? 'Inativar' : 'Ativar'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ]),
        ],
      ),
    );
  }

  Widget campoDinheiro(TextEditingController controller, String label) {
    return SizedBox(
      width: 230,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget campoData(TextEditingController controller, String label) {
    return SizedBox(
      width: 230,
      child: TextField(
        controller: controller,
        inputFormatters: [dataMask],
        keyboardType: TextInputType.number,
        onChanged: (valor) {
          setState(() {});
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget campoDpp() {
    return SizedBox(
      width: 230,
      child: TextField(
        controller: dppController,
        inputFormatters: [dataMask],
        keyboardType: TextInputType.number,
        onChanged: (valor) {
          setState(() {});
        },
        decoration: InputDecoration(
          labelText: 'DPP',
          border: const OutlineInputBorder(),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: escolherDpp,
          ),
        ),
      ),
    );
  }

  Widget campoInfo(String titulo, String valor) {
    return SizedBox(
      width: 230,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: titulo,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: const Color(0xFFFFF3EF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
        child: Text(
          valor,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: NatusApp.vinho,
          ),
        ),
      ),
    );
  }

  Widget dropdown(
    String label,
    String valor,
    List<String> itens,
    Function(String) onChange,
  ) {
    return SizedBox(
      width: 230,
      child: DropdownButtonFormField<String>(
        initialValue: valor,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: itens
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (v) => onChange(v!),
      ),
    );
  }

  Widget dropdownPopup(
    String valor,
    List<String> opcoes,
    Function(String) aoMudar,
  ) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: valor,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: opcoes.map((opcao) {
          return DropdownMenuItem(value: opcao, child: Text(opcao));
        }).toList(),
        onChanged: (v) {
          if (v != null) {
            aoMudar(v);
          }
        },
      ),
    );
  }

  Widget dropdownGrande(
    String label,
    String valor,
    List<String> itens,
    Function(String) onChange,
  ) {
    return SizedBox(
      width: 360,
      child: DropdownButtonFormField<String>(
        initialValue: valor,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: itens
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (v) => onChange(v!),
      ),
    );
  }

  Future<void> escolherDpp() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (data != null) {
      setState(() {
        dppController.text =
            '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
      });
    }
  }

  void salvarGestante() {
    if (nomeGestante.text.trim().isEmpty || dppController.text.trim().isEmpty) {
      mostrarMensagem('Preencha pelo menos o nome da gestante e a DPP.');
      return;
    }

    if (planoIdSelecionado.isEmpty || plano.trim().isEmpty) {
      mostrarMensagem(
        'Cadastre e selecione um plano antes de salvar a gestante.',
      );
      return;
    }

    double valorPlano = valorPlanoAtual();
    double percentualDesconto = converterPercentual(descontoPercentual);
    double valorDesconto = valorPlano * percentualDesconto;
    double entrada = converterValor(entradaController.text);
    int qtdParcelas = int.parse(parcelas);

    double valorFinal = valorPlano - valorDesconto;
    if (valorFinal < 0) valorFinal = 0;

    double valorParcelado = valorFinal - entrada;
    if (valorParcelado < 0) valorParcelado = 0;

    double valorParcela = valorParcelado / qtdParcelas;

    final novaGestante = {
      'nomeGestante': nomeGestante.text.trim(),
      'cpfGestante': cpfGestante.text.trim(),
      'telefoneGestante': telefoneGestante.text.trim(),
      'emailGestante': emailGestante.text.trim(),
      'enderecoGestante': enderecoGestante.text.trim(),
      'numeroGestante': numeroGestante.text.trim(),
      'complementoGestante': complementoGestante.text.trim(),
      'bairroGestante': bairroGestante.text.trim(),
      'cidadeGestante': cidadeGestante.text.trim(),
      'estadoGestante': estadoGestante.text.trim(),
      'cepGestante': cepGestante.text.trim(),
      'hospitalGestante': hospitalGestante.text.trim(),
      'obstetraGestante': obstetraGestante.text.trim(),
      'convenioGestante': convenioGestante.text.trim(),
      'nomePai': nomePai.text.trim(),
      'cpfPai': cpfPai.text.trim(),
      'telefonePai': telefonePai.text.trim(),
      'emailPai': emailPai.text.trim(),
      'nomeBebe': nomeBebe.text.trim(),
      'sexo': sexo,
      'dpp': dppController.text.trim(),
      'dataNascimento': dataNascimento.text.trim(),
      'viaNascimento': viaNascimento,
      'igAoNascer': igAoNascer.text.trim(),
      'pesoBebe': pesoBebe.text.trim(),
      'goldenHour': goldenHour,
      'amamentacao': amamentacao,
      'observacoesBebe': observacoesBebe.text.trim(),
      'planoId': planoIdSelecionado,
      'plano': plano,
      'descricaoNfse': descricaoNfsePlano,
      'valorPlano': formatarMoeda(valorPlano),
      'descontoPercentual': descontoPercentual,
      'valorDesconto': formatarMoeda(valorDesconto),
      'entrada': formatarMoeda(entrada),
      'parcelas': parcelas,
      'parcelasPagas': parcelasPagasController.text.trim().isEmpty
          ? '0'
          : parcelasPagasController.text.trim(),
      'formaPagamento': formaPagamento,
      'valorParcela': formatarMoeda(valorParcela),
      'consultorio': consultorio,
      'statusGestante': 'Gestante',
      'uid': FirebaseAuth.instance.currentUser!.uid,
    };

    setState(() {
      gestantes.add(novaGestante);
      limparCampos();
    });

    salvarGestanteFirestore(novaGestante);
    gerarParcelasDaGestante(novaGestante);
  }

  void limparCampos() {
    nomeGestante.clear();
    cpfGestante.clear();
    telefoneGestante.clear();
    emailGestante.clear();
    enderecoGestante.clear();
    bairroGestante.clear();
    cidadeGestante.clear();
    cepGestante.clear();
    hospitalGestante.clear();
    obstetraGestante.clear();
    convenioGestante.clear();

    nomePai.clear();
    cpfPai.clear();
    telefonePai.clear();
    emailPai.clear();

    dppController.clear();
    nomeBebe.clear();
    dataNascimento.clear();
    igAoNascer.clear();
    pesoBebe.clear();
    observacoesBebe.clear();

    entradaController.clear();
    parcelasPagasController.clear();

    sexo = 'Não informado';
    viaNascimento = 'Não informado';
    goldenHour = 'Não informado';
    amamentacao = 'Não informado';
    plano = '';
    planoIdSelecionado = '';
    descricaoNfsePlano = '';
    final ativos = planosCadastrados.where((p) => p['ativo'] != false).toList();
    if (ativos.isNotEmpty) {
      final primeiro = ativos.first;
      planoIdSelecionado = (primeiro['id'] ?? '').toString();
      plano = (primeiro['nomePlano'] ?? '').toString();
      parcelas = (primeiro['parcelas'] ?? '1').toString();
      descricaoNfsePlano = (primeiro['descricaoNfse'] ?? '').toString();
    }
    descontoPercentual = '0%';
    parcelas = '1';
    consultorio = 'Não';
    formaPagamento = 'Pix';
  }

  Widget listaGestantes() {
    if (gestantes.isEmpty) {
      return const Text('Nenhuma gestante cadastrada ainda.');
    }

    final busca = buscaGestantesController.text.trim();
    final listaOrdenada = [...gestantes];

    listaOrdenada.sort((a, b) {
      final statusA = statusGestanteNormalizado(a);
      final statusB = statusGestanteNormalizado(b);

      int prioridade(String status) {
        if (status == 'Gestante') return 1;
        if (status == 'Puérpera') return 2;
        if (status == 'Histórico') return 3;
        if (status == 'Encerrada') return 4;
        return 5;
      }

      final prioridadeA = prioridade(statusA);
      final prioridadeB = prioridade(statusB);

      if (prioridadeA != prioridadeB) {
        return prioridadeA.compareTo(prioridadeB);
      }

      // Se ambos forem gestantes, ordena por DPP
      if (statusA == 'Gestante') {
        final diasA = diasParaDpp(a['dpp'] ?? '');
        final diasB = diasParaDpp(b['dpp'] ?? '');

        return diasA.compareTo(diasB);
      }

      return (a['nomeGestante'] ?? '').compareTo(b['nomeGestante'] ?? '');
    });

    final listaFiltrada = listaOrdenada.where((g) {
      final status = statusGestanteNormalizado(g);

      if (filtroStatusGestante == 'Ativas') {
        if (!gestanteEstaAtiva(g)) {
          return false;
        }
      } else if (filtroStatusGestante != 'Todas') {
        if (status != filtroStatusGestante) {
          return false;
        }
      }

      if (filtroDashboardPacientes != null &&
          !filtroDashboardPacientes!.corresponde(g)) {
        return false;
      }

      return gestanteApareceNaBusca(g, busca);
    }).toList();

    if (listaFiltrada.isEmpty) {
      return const Text('Nenhuma gestante encontrada com esse filtro.');
    }

    return Column(
      children: listaFiltrada.map((g) {
        final igAtual = calcularIdadeGestacional(g['dpp'] ?? '');
        final usuarioEnfermeira = tipoEhProfissionalClinica(widget.tipoUsuario);
        final podeVerDadosFinanceiros = !usuarioEnfermeira;

        return NatusCardGestanteLista(
          gestante: g,
          igAtual: igAtual,
          statusNormalizado: statusGestanteNormalizado(g),
          mostrarFinanceiro: podeVerDadosFinanceiros,
          onAbrir: () {
            setState(() {
              gestanteSelecionada = g;
            });
          },
          onExcluir: () => confirmarExcluirGestante(g),
        );
      }).toList(),
    );
  }

  Future<void> confirmarExcluirGestante(Map<String, String> g) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: const Text(
            'Tem certeza que deseja excluir esta gestante? Esta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!context.mounted) return;
                if (!context.mounted) return;
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final id = g['id'];
                final nome = g['nomeGestante'];

                if (id == null || id.isEmpty) {
                  mostrarMensagem('ID não encontrado.');
                  return;
                }

                try {
                  final parcelas = await firestore
                      .collection('parcelas')
                      .where('gestante', isEqualTo: nome)
                      .get();

                  for (var doc in parcelas.docs) {
                    await doc.reference.delete();
                  }

                  await firestore.collection('gestantes').doc(id).delete();

                  setState(() {
                    gestantes.removeWhere((item) => item['id'] == id);

                    parcelasFinanceiras.removeWhere(
                      (p) => p['gestante'] == nome,
                    );

                    marcadores.removeWhere((m) => m.markerId.value == id);
                    mapaJaCarregado = false;
                  });

                  mostrarMensagem(
                    'Gestante e financeiro excluídos com sucesso.',
                  );
                } catch (e) {
                  debugPrint('❌ Erro ao excluir gestante e financeiro: $e');
                  mostrarMensagem('Erro ao excluir gestante e financeiro.');
                }
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  String calcularIdadeGestacional(String dppTexto) {
    try {
      final partes = dppTexto.split('/');

      if (partes.length != 3) {
        return 'Informe a DPP';
      }

      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);

      final dpp = DateTime(ano, mes, dia);
      final hoje = DateTime.now();

      final diasAteDpp = dpp.difference(hoje).inDays;
      final diasGestacao = 280 - diasAteDpp;

      if (diasGestacao < 0) {
        return 'Antes da gestação';
      }

      final semanas = diasGestacao ~/ 7;
      final dias = diasGestacao % 7;

      return '$semanas semanas e $dias dias';
    } catch (e) {
      return 'Informe a DPP';
    }
  }

  double converterValor(String texto) {
    String limpo = texto
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();

    if (limpo.isEmpty) return 0;

    return double.tryParse(limpo) ?? 0;
  }

  double converterPercentual(String texto) {
    String limpo = texto.replaceAll('%', '').trim();
    double percentual = double.tryParse(limpo) ?? 0;
    return percentual / 100;
  }

  double calcularCustoTotalGestante(String nomeGestante) {
    double total = 0;

    for (var a in atendimentos) {
      if (a['gestante'] == nomeGestante) {
        total += converterValor(a['custoDeslocamento'] ?? '0');
        total += converterValor(a['custoMateriais'] ?? '0');
      }
    }

    return total;
  }

  String formatarMoeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<LatLng?> buscarCoordenada(String endereco) async {
    try {
      const apiKey = 'AIzaSyAL3dKPODz98P9UEhlzW1YM4JTRiCBvesI';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(endereco)}'
        '&region=br'
        '&key=$apiKey',
      );

      final resposta = await http.get(url);

      if (resposta.statusCode != 200) {
        debugPrint('❌ Erro HTTP Geocoding: ${resposta.statusCode}');
        return null;
      }

      final dados = jsonDecode(resposta.body);

      if (dados['status'] != 'OK') {
        debugPrint('❌ Geocoding status: ${dados['status']} - $endereco');
        return null;
      }

      final location = dados['results'][0]['geometry']['location'];

      final lat = location['lat'];
      final lng = location['lng'];

      if (lat == null || lng == null) {
        debugPrint('❌ Latitude/longitude nulas para: $endereco');
        return null;
      }

      return LatLng((lat as num).toDouble(), (lng as num).toDouble());
    } catch (e) {
      debugPrint('Erro ao converter endereço via API: $e');
      return null;
    }
  }

  Future<Map<String, String>?> buscarEnderecoPorCep(String cep) async {
    try {
      final cepLimpo = cep.replaceAll(RegExp(r'[^0-9]'), '');

      if (cepLimpo.length != 8) return null;

      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey('erro')) return null;

        return {
          'endereco': data['logradouro'] ?? '',
          'bairro': data['bairro'] ?? '',
          'cidade': data['localidade'] ?? '',
          'estado': data['uf'] ?? '',
        };
      }
    } catch (e) {
      debugPrint('Erro ao buscar CEP: $e');
    }

    return null;
  }

  String formatarDataHora(DateTime data) {
    String dia = data.day.toString().padLeft(2, '0');
    String mes = data.month.toString().padLeft(2, '0');
    String ano = data.year.toString();

    String hora = data.hour.toString().padLeft(2, '0');
    String minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano $hora:$minuto';
  }

  String formatarDuracao(Duration duracao) {
    final minutos = duracao.inMinutes;
    final segundos = duracao.inSeconds % 60;

    if (minutos == 0) {
      return '$segundos segundos';
    }

    return '$minutos min e $segundos seg';
  }

  Color corPorTipoObservacao(String tipo) {
    switch (tipo) {
      case 'Evolução':
        return Colors.green;
      case 'Orientação':
        return Colors.orange;
      case 'Intercorrência':
        return Colors.red;
      case 'Retorno':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  PlatformFile? arquivoSelecionado;

  Future<void> selecionarArquivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        arquivoSelecionado = result.files.first;
      });

      mostrarMensagem('Arquivo selecionado: ${arquivoSelecionado!.name}');
    }
  }

  Future<void> carregarGestantesFirestore() async {
    try {
      var nomeFiltroCarteira = widget.nomeUsuario;

      // Obstetra: o filtro de carteira usa o nome do registro vinculado
      // na coleção `obstetras` (mais confiável que o nome do login);
      // se não houver vínculo, cai para o nome do usuário.
      if (widget.tipoUsuario == 'obstetra') {
        if (obstetras.isEmpty) {
          await carregarObstetrasFirestore();
        }

        final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

        final obVinculado = obstetras.firstWhere(
          (o) => o['uidObstetra'] == uidLogado,
          orElse: () => {},
        );

        final nomeVinculado = (obVinculado['nome'] ?? '').trim();
        if (nomeVinculado.isNotEmpty) {
          nomeFiltroCarteira = nomeVinculado;
        }
      }

      final listaFirebase = gregras.filtrarGestantesPorPerfil(
        await dados.buscarGestantes(),
        tipoUsuario: widget.tipoUsuario,
        nomeUsuario: nomeFiltroCarteira,
      );

      setState(() {
        gestantes.clear();
        gestantes.addAll(listaFirebase);
        marcadores.clear();
        mapaJaCarregado = false;
        carregandoMapa = false;
      });

      debugPrint('✅ Gestantes carregadas do Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao carregar gestantes: $e');
      mostrarMensagem('Erro ao carregar gestantes do Firebase');
    }
  }

  String montarEnderecoMapa(Map<String, String> g) {
    final rua = (g['enderecoGestante'] ?? '').trim();
    final numero = (g['numeroGestante'] ?? '').trim();
    final bairro = (g['bairroGestante'] ?? '').trim();
    final cidade = (g['cidadeGestante'] ?? '').trim();
    final estado = (g['estadoGestante'] ?? '').trim();
    final cep = (g['cepGestante'] ?? '').trim();

    if (cep.isNotEmpty) {
      return '$cep, Brasil';
    }

    if (rua.isEmpty || cidade.isEmpty) {
      return '';
    }

    final partes = <String>[
      if (rua.isNotEmpty) rua,
      if (numero.isNotEmpty) numero,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) cidade,
      if (estado.isNotEmpty) estado,
      'Brasil',
    ];

    return partes.join(', ');
  }

  Future<void> carregarMarcadores() async {
    Set<Marker> novosMarcadores = {};

    for (var g in gestantes) {
      if (!gestanteEstaAtiva(g)) {
        continue;
      }

      final endereco = montarEnderecoMapa(g);

      if (endereco.isEmpty) {
        debugPrint('⚠️ Sem endereço suficiente: ${g['nomeGestante']}');
        continue;
      }

      debugPrint('📍 Buscando endereço no mapa: $endereco');

      final coordenada = await buscarCoordenada(endereco);

      if (coordenada != null) {
        novosMarcadores.add(
          Marker(
            markerId: MarkerId(g['id'] ?? g['nomeGestante'] ?? 'sem-id'),
            position: coordenada,
            infoWindow: InfoWindow(
              title: g['nomeGestante'],
              snippet: g['telefoneGestante'] ?? '',
            ),
          ),
        );
      } else {
        debugPrint('❌ Não encontrou coordenada para: $endereco');
      }
    }

    setState(() {
      marcadores = novosMarcadores;
    });

    debugPrint('✅ Total de pins no mapa: ${novosMarcadores.length}');
  }

  Future<void> atualizarStatusGestante(Map<String, String> gestante) async {
    final id = gestante['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem('Não foi possível encontrar o ID da gestante.');
      return;
    }

    final statusAtual = gestante['statusGestante'] ?? 'Gestante';

    if (statusAtual == 'Gestante') {
      abrirPopupNascimento(gestante);
      return;
    }

    if (statusAtual == 'Puérpera') {
      try {
        await firestore.collection('gestantes').doc(id).update({
          'statusGestante': 'Encerrada',
        });

        setState(() {
          gestante['statusGestante'] = 'Encerrada';
          gestanteSelecionada = gestante;
          marcadores.removeWhere((m) => m.markerId.value == id);
          mapaJaCarregado = false;
        });

        mostrarMensagem('Atendimento encerrado.');
      } catch (e) {
        debugPrint('❌ Erro ao encerrar atendimento: $e');
        mostrarMensagem('Erro ao encerrar atendimento.');
      }

      return;
    }

    mostrarMensagem('Este atendimento já está encerrado.');
  }

  void abrirPopupEditarGestante(Map<String, String> gestante) {
    final nomeTemp = TextEditingController(
      text: gestante['nomeGestante'] ?? '',
    );
    final telefoneTemp = TextEditingController(
      text: gestante['telefoneGestante'] ?? '',
    );
    final emailTemp = TextEditingController(
      text: gestante['emailGestante'] ?? '',
    );
    final cepTemp = TextEditingController(text: gestante['cepGestante'] ?? '');
    final enderecoTemp = TextEditingController(
      text: gestante['enderecoGestante'] ?? '',
    );
    final bairroTemp = TextEditingController(
      text: gestante['bairroGestante'] ?? '',
    );
    final cidadeTemp = TextEditingController(
      text: gestante['cidadeGestante'] ?? '',
    );
    final hospitalTemp = TextEditingController(
      text: gestante['hospitalGestante'] ?? '',
    );
    final obstetraTemp = TextEditingController(
      text: gestante['obstetraGestante'] ?? '',
    );
    final convenioTemp = TextEditingController(
      text: gestante['convenioGestante'] ?? '',
    );

    const opcoesRisco = [
      'Não informado',
      'Habitual',
      'Intermediário',
      'Alto Risco',
    ];
    const opcoesDiabetes = ['Não informado', 'Sim', 'Não'];

    String riscoTemp = (gestante['riscoGestacional'] ?? '').trim();
    if (!opcoesRisco.contains(riscoTemp)) riscoTemp = 'Não informado';

    String diabetesTemp = (gestante['diabetesGestacional'] ?? '').trim();
    if (!opcoesDiabetes.contains(diabetesTemp)) diabetesTemp = 'Não informado';

    Widget campoPopup(
      TextEditingController controller,
      String label, {
      bool bloqueado = false,
      Function(String)? onChanged,
    }) {
      return SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          enabled: !bloqueado,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar cadastro da gestante'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  campoPopup(nomeTemp, 'Nome da gestante'),

                  const SizedBox(height: 16),

                  campoPopup(telefoneTemp, 'Telefone'),

                  const SizedBox(height: 16),

                  campoPopup(emailTemp, 'E-mail'),

                  const SizedBox(height: 16),

                  campoPopup(
                    cepTemp,
                    'CEP',
                    onChanged: (value) async {
                      if (value.replaceAll(RegExp(r'[^0-9]'), '').length == 8) {
                        final resultado = await buscarEnderecoPorCep(value);

                        if (resultado != null) {
                          enderecoTemp.text = resultado['endereco'] ?? '';
                          bairroTemp.text = resultado['bairro'] ?? '';
                          cidadeTemp.text = resultado['cidade'] ?? '';
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  campoPopup(enderecoTemp, 'Endereço', bloqueado: true),

                  const SizedBox(height: 16),

                  campoPopup(bairroTemp, 'Bairro', bloqueado: true),

                  const SizedBox(height: 16),

                  campoPopup(cidadeTemp, 'Cidade', bloqueado: true),

                  const SizedBox(height: 16),

                  campoPopup(hospitalTemp, 'Maternidade / Hospital'),

                  const SizedBox(height: 16),

                  campoPopup(obstetraTemp, 'Obstetra'),

                  const SizedBox(height: 16),

                  campoPopup(convenioTemp, 'Convênio'),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      initialValue: riscoTemp,
                      decoration: const InputDecoration(
                        labelText: 'Risco gestacional (pré-natal)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      items: opcoesRisco
                          .map(
                            (o) => DropdownMenuItem(value: o, child: Text(o)),
                          )
                          .toList(),
                      onChanged: (v) => riscoTemp = v ?? 'Não informado',
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      initialValue: diabetesTemp,
                      decoration: const InputDecoration(
                        labelText: 'Diabetes gestacional',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      items: opcoesDiabetes
                          .map(
                            (o) => DropdownMenuItem(value: o, child: Text(o)),
                          )
                          .toList(),
                      onChanged: (v) => diabetesTemp = v ?? 'Não informado',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await salvarEdicaoGestante(
                  gestante,
                  nomeTemp.text.trim(),
                  telefoneTemp.text.trim(),
                  emailTemp.text.trim(),
                  enderecoTemp.text.trim(),
                  bairroTemp.text.trim(),
                  cidadeTemp.text.trim(),
                  cepTemp.text.trim(),
                  hospitalTemp.text.trim(),
                  obstetraTemp.text.trim(),
                  convenioTemp.text.trim(),
                  riscoTemp,
                  diabetesTemp,
                );

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Salvar alterações'),
            ),
          ],
        );
      },
    );
  }

  void abrirPopupEditarSecaoGestante(
    Map<String, String> gestante,
    String secao,
  ) {
    final camposPorSecao = <String, List<Map<String, String>>>{
      'Gestante': [
        {'campo': 'nomeGestante', 'label': 'Nome da gestante'},
        {'campo': 'cpfGestante', 'label': 'CPF'},
        {'campo': 'telefoneGestante', 'label': 'Telefone'},
        {'campo': 'emailGestante', 'label': 'E-mail'},
        {'campo': 'cepGestante', 'label': 'CEP'},
        {'campo': 'enderecoGestante', 'label': 'Endereço'},
        {'campo': 'numeroGestante', 'label': 'Número'},
        {'campo': 'complementoGestante', 'label': 'Complemento'},
        {'campo': 'bairroGestante', 'label': 'Bairro'},
        {'campo': 'cidadeGestante', 'label': 'Cidade'},
        {'campo': 'estadoGestante', 'label': 'Estado'},
        {'campo': 'hospitalGestante', 'label': 'Maternidade / Hospital'},
        {'campo': 'obstetraGestante', 'label': 'Obstetra'},
        {'campo': 'convenioGestante', 'label': 'Convênio'},
        {
          'campo': 'riscoGestacional',
          'label': 'Risco gestacional (Habitual/Intermediário/Alto Risco)',
        },
        {
          'campo': 'diabetesGestacional',
          'label': 'Diabetes gestacional (Sim/Não)',
        },
      ],
      'Pai': [
        {'campo': 'nomePai', 'label': 'Nome do pai'},
        {'campo': 'cpfPai', 'label': 'CPF do pai / responsável'},
        {'campo': 'telefonePai', 'label': 'Telefone do pai'},
        {'campo': 'emailPai', 'label': 'E-mail do pai'},
      ],
      'Bebê': [
        {'campo': 'nomeBebe', 'label': 'Nome do bebê'},
        {'campo': 'sexo', 'label': 'Sexo'},
        {'campo': 'dpp', 'label': 'DPP'},
        {'campo': 'dataNascimento', 'label': 'Data de nascimento'},
        {'campo': 'viaNascimento', 'label': 'Via de nascimento'},
        {'campo': 'igAoNascer', 'label': 'IG ao nascer'},
        {'campo': 'pesoBebe', 'label': 'Peso'},
        {'campo': 'goldenHour', 'label': 'Golden Hour'},
        {'campo': 'amamentacao', 'label': 'Amamentação'},
        {'campo': 'observacoesBebe', 'label': 'Observações'},
      ],
      'Valores': [
        {'campo': 'plano', 'label': 'Plano'},
        {'campo': 'valorPlano', 'label': 'Valor do plano'},
        {'campo': 'descontoPercentual', 'label': 'Desconto percentual'},
        {'campo': 'valorDesconto', 'label': 'Valor do desconto'},
        {'campo': 'entrada', 'label': 'Entrada'},
        {'campo': 'parcelas', 'label': 'Parcelas'},
        {'campo': 'valorParcela', 'label': 'Valor da parcela'},
        {'campo': 'formaPagamento', 'label': 'Forma de pagamento'},
        {'campo': 'consultorio', 'label': 'Consultório'},
        {'campo': 'descricaoNfse', 'label': 'Descrição NFS-e'},
      ],
    };

    final campos = camposPorSecao[secao] ?? [];
    final controllers = <String, TextEditingController>{};

    for (final item in campos) {
      final campo = item['campo'] ?? '';
      controllers[campo] = TextEditingController(text: gestante[campo] ?? '');
    }

    Future<void> preencherEnderecoPorCep(String value) async {
      if (value.replaceAll(RegExp(r'[^0-9]'), '').length != 8) return;

      final resultado = await buscarEnderecoPorCep(value);

      if (resultado != null) {
        controllers['enderecoGestante']?.text = resultado['endereco'] ?? '';
        controllers['bairroGestante']?.text = resultado['bairro'] ?? '';
        controllers['cidadeGestante']?.text = resultado['cidade'] ?? '';
        controllers['estadoGestante']?.text = resultado['estado'] ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar $secao'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 14,
                children: campos.map((item) {
                  final campo = item['campo'] ?? '';
                  final label = item['label'] ?? campo;
                  final controller = controllers[campo]!;
                  final mascara = campo == 'cpfGestante' || campo == 'cpfPai'
                      ? cpfMask
                      : campo == 'telefoneGestante' || campo == 'telefonePai'
                      ? telefoneMask
                      : campo == 'cepGestante'
                      ? cepMask
                      : null;

                  return SizedBox(
                    width: 260,
                    child: TextField(
                      controller: controller,
                      inputFormatters: mascara == null ? null : [mascara],
                      maxLines:
                          campo == 'descricaoNfse' || campo == 'observacoesBebe'
                          ? 3
                          : 1,
                      onChanged: campo == 'cepGestante'
                          ? preencherEnderecoPorCep
                          : null,
                      decoration: InputDecoration(
                        labelText: label,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final dadosAtualizados = <String, String>{};

                controllers.forEach((campo, controller) {
                  dadosAtualizados[campo] = controller.text.trim();
                });

                await salvarEdicaoSecaoGestante(gestante, dadosAtualizados);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NatusApp.vinho,
                foregroundColor: (NatusApp.escuro
                    ? NatusApp.fundo
                    : NatusApp.offWhite),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> salvarEdicaoSecaoGestante(
    Map<String, String> gestante,
    Map<String, String> dadosAtualizados,
  ) async {
    final id = gestante['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem('ID da gestante não encontrado.');
      return;
    }

    try {
      await firestore.collection('gestantes').doc(id).update(dadosAtualizados);

      setState(() {
        gestante.addAll(dadosAtualizados);
        gestanteSelecionada = gestante;
      });

      mostrarMensagem('Cadastro atualizado com sucesso.');
    } catch (e) {
      debugPrint('❌ Erro ao editar seção da gestante: $e');
      mostrarMensagem('Erro ao atualizar cadastro.');
    }
  }

  void abrirPopupCriarUsuario() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStatePopup) {
            return AlertDialog(
              title: const Text('Criar novo usuário'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    campo(novoNomeController, 'Nome'),

                    const SizedBox(height: 16),

                    campo(novoEmailController, 'E-mail'),

                    const SizedBox(height: 16),

                    TextField(
                      enabled: false,
                      controller: TextEditingController(text: 'N@tus2026!'),
                      decoration: const InputDecoration(
                        labelText: 'Senha padrão',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: novoTipoUsuario,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de usuário',
                        border: OutlineInputBorder(),
                      ),
                      items: ['admin', 'enfermeira', 'obstetra', 'gestante']
                          .map(
                            (tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStatePopup(() {
                          novoTipoUsuario = value!;
                          gestanteSelecionadaLogin = null;
                          enfermeiraSelecionadaLogin = null;
                          obstetraSelecionadoLogin = null;
                        });
                      },
                    ),

                    if (novoTipoUsuario == 'gestante') ...[
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: gestanteSelecionadaLogin,
                        decoration: const InputDecoration(
                          labelText: 'Selecionar gestante',
                          border: OutlineInputBorder(),
                        ),
                        items: gestantes
                            .where(
                              (g) =>
                                  g['uidGestante'] == null ||
                                  g['uidGestante'] == '',
                            )
                            .map(
                              (g) => DropdownMenuItem(
                                value: g['id'],
                                child: Text(g['nomeGestante'] ?? 'Sem nome'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setStatePopup(() {
                            gestanteSelecionadaLogin = value;
                          });
                        },
                      ),
                    ],

                    if (novoTipoUsuario == 'enfermeira') ...[
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: enfermeiraSelecionadaLogin,
                        decoration: const InputDecoration(
                          labelText: 'Selecionar enfermeira',
                          border: OutlineInputBorder(),
                        ),
                        items: enfermeiras
                            .where(
                              (e) =>
                                  e['uidEnfermeira'] == null ||
                                  e['uidEnfermeira'] == '',
                            )
                            .map(
                              (e) => DropdownMenuItem(
                                value: e['id'],
                                child: Text(e['nome'] ?? 'Sem nome'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setStatePopup(() {
                            enfermeiraSelecionadaLogin = value;
                          });
                        },
                      ),
                    ],

                    if (novoTipoUsuario == 'obstetra') ...[
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: obstetraSelecionadoLogin,
                        decoration: const InputDecoration(
                          labelText: 'Selecionar obstetra',
                          border: OutlineInputBorder(),
                        ),
                        items: obstetras
                            .where(
                              (o) =>
                                  o['uidObstetra'] == null ||
                                  o['uidObstetra'] == '',
                            )
                            .map(
                              (o) => DropdownMenuItem(
                                value: o['id'],
                                child: Text(o['nome'] ?? 'Sem nome'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setStatePopup(() {
                            obstetraSelecionadoLogin = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: criarUsuarioFirebase,
                  child: const Text('Criar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> criarUsuarioFirebase() async {
    if (novoNomeController.text.trim().isEmpty ||
        novoEmailController.text.trim().isEmpty) {
      mostrarMensagem('Preencha nome e e-mail.');
      return;
    }

    if (novoTipoUsuario == 'gestante' && gestanteSelecionadaLogin == null) {
      mostrarMensagem('Selecione a gestante para vincular ao login.');
      return;
    }

    if (novoTipoUsuario == 'enfermeira' && enfermeiraSelecionadaLogin == null) {
      mostrarMensagem('Selecione a enfermeira para vincular ao login.');
      return;
    }

    if (novoTipoUsuario == 'obstetra' && obstetraSelecionadoLogin == null) {
      mostrarMensagem('Selecione o obstetra para vincular ao login.');
      return;
    }

    if (novoTipoUsuario == 'superAdmin' || novoTipoUsuario == 'superadmin') {
      mostrarMensagem('Criação de Super Admin bloqueada neste cadastro.');
      return;
    }

    try {
      const senhaPadrao = 'N@tus2026!';

      final secondaryApp = await Firebase.initializeApp(
        name: 'Secondary',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: novoEmailController.text.trim(),
        password: senhaPadrao,
      );

      final uid = userCredential.user!.uid;

      await firestore.collection('usuarios').doc(uid).set({
        'nome': novoNomeController.text.trim(),
        'email': novoEmailController.text.trim(),
        'tipo': novoTipoUsuario,
        'uid': uid,
      });

      if (novoTipoUsuario == 'gestante') {
        await firestore
            .collection('gestantes')
            .doc(gestanteSelecionadaLogin)
            .update({'uidGestante': uid});
      }

      if (novoTipoUsuario == 'enfermeira') {
        await firestore
            .collection('enfermeiras')
            .doc(enfermeiraSelecionadaLogin)
            .update({'uidEnfermeira': uid});
      }

      if (novoTipoUsuario == 'obstetra') {
        await firestore
            .collection('obstetras')
            .doc(obstetraSelecionadoLogin)
            .update({'uidObstetra': uid});
      }

      await secondaryAuth.signOut();
      await secondaryApp.delete();

      if (!mounted) return;
      Navigator.pop(context);

      novoNomeController.clear();
      novoEmailController.clear();
      gestanteSelecionadaLogin = null;
      enfermeiraSelecionadaLogin = null;
      obstetraSelecionadoLogin = null;
      novoTipoUsuario = 'gestante';

      await carregarEnfermeirasFirestore();
      await carregarObstetrasFirestore();
      await carregarGestantesFirestore();

      mostrarMensagem('Usuário criado com sucesso!');
    } catch (e) {
      mostrarMensagem('Erro ao criar usuário: $e');
    }
  }

  Future<void> salvarEdicaoGestante(
    Map<String, String> gestante,
    String nome,
    String telefone,
    String email,
    String endereco,
    String bairro,
    String cidade,
    String cep,
    String hospital,
    String obstetra,
    String convenio,
    String riscoGestacional,
    String diabetesGestacional,
  ) async {
    final id = gestante['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem('ID da gestante não encontrado.');
      return;
    }

    try {
      final dadosAtualizados = {
        'nomeGestante': nome,
        'telefoneGestante': telefone,
        'emailGestante': email,
        'enderecoGestante': endereco,
        'bairroGestante': bairro,
        'cidadeGestante': cidade,
        'cepGestante': cep,
        'hospitalGestante': hospital,
        'obstetraGestante': obstetra,
        'convenioGestante': convenio,
        'riscoGestacional': riscoGestacional,
        'diabetesGestacional': diabetesGestacional,
      };

      await firestore.collection('gestantes').doc(id).update(dadosAtualizados);

      setState(() {
        gestante.addAll(dadosAtualizados);
        gestanteSelecionada = gestante;
      });

      mostrarMensagem('Cadastro atualizado com sucesso.');
    } catch (e) {
      debugPrint('❌ Erro ao editar gestante: $e');
      mostrarMensagem('Erro ao atualizar cadastro.');
    }
  }

  String formatarDataNascimentoDigitada(String valor) {
    final texto = valor.trim();

    if (texto.isEmpty) return '';

    final dataIso = DateTime.tryParse(texto);
    if (dataIso != null) {
      return formatarDataFinanceira(dataIso);
    }

    final somenteData = texto.split(' ').first.trim();

    final dataComSeparador = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$',
    ).firstMatch(somenteData);

    if (dataComSeparador != null) {
      final dia = int.tryParse(dataComSeparador.group(1) ?? '');
      final mes = int.tryParse(dataComSeparador.group(2) ?? '');
      var ano = int.tryParse(dataComSeparador.group(3) ?? '');

      if (dia != null && mes != null && ano != null) {
        if (ano < 100) ano += 2000;

        return '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$ano';
      }
    }

    final apenasNumeros = texto.replaceAll(RegExp(r'[^0-9]'), '');

    if (apenasNumeros.length == 8) {
      final dia = int.tryParse(apenasNumeros.substring(0, 2));
      final mes = int.tryParse(apenasNumeros.substring(2, 4));
      final ano = int.tryParse(apenasNumeros.substring(4, 8));

      if (dia != null && mes != null && ano != null) {
        return '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$ano';
      }
    }

    if (apenasNumeros.length == 6) {
      final dia = int.tryParse(apenasNumeros.substring(0, 2));
      final mes = int.tryParse(apenasNumeros.substring(2, 4));
      final anoCurto = int.tryParse(apenasNumeros.substring(4, 6));

      if (dia != null && mes != null && anoCurto != null) {
        final ano = 2000 + anoCurto;

        return '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$ano';
      }
    }

    return texto;
  }

  void abrirPopupNascimento(Map<String, String> gestante) {
    final dataNascimentoTemp = TextEditingController(
      text: formatarDataNascimentoDigitada(gestante['dataNascimento'] ?? ''),
    );

    final nomeBebeTemp = TextEditingController(
      text: gestante['nomeBebe'] ?? '',
    );
    final igAoNascerTemp = TextEditingController(
      text: gestante['igAoNascer'] ?? '',
    );
    final pesoBebeTemp = TextEditingController(
      text: gestante['pesoBebe'] ?? '',
    );
    final observacoesTemp = TextEditingController(
      text: gestante['observacoesBebe'] ?? '',
    );

    String sexoTemp = (gestante['sexo'] ?? 'Não informado') == 'Não informado'
        ? 'Sexo'
        : gestante['sexo'] ?? 'Sexo';

    String viaNascimentoTemp =
        (gestante['viaNascimento'] ?? 'Não informado') == 'Não informado'
        ? 'Via de nascimento'
        : gestante['viaNascimento'] ?? 'Via de nascimento';

    String goldenHourTemp =
        (gestante['goldenHour'] ?? 'Não informado') == 'Não informado'
        ? 'Golden Hour'
        : gestante['goldenHour'] ?? 'Golden Hour';

    String amamentacaoTemp =
        (gestante['amamentacao'] ?? 'Não informado') == 'Não informado'
        ? 'Amamentação'
        : gestante['amamentacao'] ?? 'Amamentação';

    Widget campoNascimento(
      TextEditingController controller,
      String label, {
      double altura = 52,
      int maxLines = 1,
      List<TextInputFormatter>? inputFormatters,
      TextInputType? keyboardType,
    }) {
      return SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Dados do nascimento'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      campoNascimento(nomeBebeTemp, 'Nome do bebê'),

                      const SizedBox(height: 16),

                      campoNascimento(
                        dataNascimentoTemp,
                        'Data de nascimento',
                        inputFormatters: [dataMask],
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 16),

                      campoNascimento(igAoNascerTemp, 'IG ao nascer'),

                      const SizedBox(height: 16),

                      campoNascimento(pesoBebeTemp, 'Peso do bebê'),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: 360,
                        child: dropdownPopup(
                          sexoTemp,
                          ['Sexo', 'Masculino', 'Feminino', 'Não informado'],
                          (v) {
                            setStateDialog(() {
                              sexoTemp = v;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: 360,
                        child: dropdownPopup(
                          viaNascimentoTemp,
                          [
                            'Via de nascimento',
                            'Normal',
                            'Cesárea',
                            'Nascer em casa',
                          ],
                          (v) {
                            setStateDialog(() {
                              viaNascimentoTemp = v;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: 360,
                        child: dropdownPopup(
                          goldenHourTemp,
                          ['Golden Hour', 'Sim', 'Não'],
                          (v) {
                            setStateDialog(() {
                              goldenHourTemp = v;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: 360,
                        child: dropdownPopup(
                          amamentacaoTemp,
                          ['Amamentação', 'AME', 'Mista', 'Fórmula'],
                          (v) {
                            setStateDialog(() {
                              amamentacaoTemp = v;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      campoNascimento(
                        observacoesTemp,
                        'Observações pós-parto',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await salvarNascimento(
                      gestante,
                      nomeBebeTemp.text.trim(),
                      formatarDataNascimentoDigitada(dataNascimentoTemp.text),
                      sexoTemp == 'Sexo' ? 'Não informado' : sexoTemp,
                      viaNascimentoTemp == 'Via de nascimento'
                          ? 'Não informado'
                          : viaNascimentoTemp,
                      igAoNascerTemp.text.trim(),
                      pesoBebeTemp.text.trim(),
                      goldenHourTemp == 'Golden Hour'
                          ? 'Não informado'
                          : goldenHourTemp,
                      amamentacaoTemp == 'Amamentação'
                          ? 'Não informado'
                          : amamentacaoTemp,
                      observacoesTemp.text.trim(),
                    );

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Salvar e tornar puérpera'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> salvarNascimentoEPuerperio(
    Map<String, String> gestante,
    String nomeBebe,
    String dataNascimento,
    String sexo,
    String viaNascimento,
    String igAoNascer,
    String pesoBebe,
    String goldenHour,
    String amamentacao,
    String observacoes,
  ) async {
    final id = gestante['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem('ID não encontrado.');
      return;
    }

    try {
      final dataNascimentoFormatada = formatarDataNascimentoDigitada(
        dataNascimento,
      );

      final dadosAtualizados = {
        'nomeBebe': nomeBebe,
        'dataNascimento': dataNascimentoFormatada,
        'dataNascimentoBebe': dataNascimentoFormatada,
        'sexo': sexo,
        'viaNascimento': viaNascimento,
        'igAoNascer': igAoNascer,
        'pesoBebe': pesoBebe,
        'goldenHour': goldenHour,
        'amamentacao': amamentacao,
        'observacoesBebe': observacoes,
        'statusGestante': 'Puérpera',
      };

      await firestore.collection('gestantes').doc(id).update(dadosAtualizados);

      setState(() {
        gestante.addAll(dadosAtualizados);
        gestanteSelecionada = gestante;
      });

      mostrarMensagem('Gestante transformada em puérpera com sucesso.');
    } catch (e) {
      debugPrint('❌ Erro ao salvar nascimento: $e');
      mostrarMensagem('Erro ao salvar dados do nascimento.');
    }
  }

  Future<void> salvarGestanteFirestore(Map<String, String> gestante) async {
    debugPrint('🔥 TENTANDO SALVAR NO FIREBASE');

    try {
      final docRef = await firestore.collection('gestantes').add(gestante);

      gestante['id'] = docRef.id;

      await carregarGestantesFirestore();

      debugPrint('✅ SALVO NO FIREBASE COM ID: ${docRef.id}');
      mostrarMensagem(
        'Gestante salva no Firebase! O acesso será criado automaticamente.',
      );
    } catch (e) {
      debugPrint('❌ ERRO FIREBASE: $e');
      mostrarMensagem('Erro ao salvar: $e');
    }
  }

  Future<void> salvarAtendimentoFirestore(
    Map<String, String> atendimento,
  ) async {
    try {
      await firestore.collection('atendimentos').add(atendimento);
      debugPrint('✅ Atendimento salvo no Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao salvar atendimento: $e');
      mostrarMensagem('Erro ao salvar atendimento no Firebase');
    }
  }

  Future<void> salvarMaterialFirestore(Map<String, String> material) async {
    try {
      await firestore.collection('materiais').add(material);
      debugPrint('✅ Material salvo no Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao salvar material: $e');
      mostrarMensagem('Erro ao salvar material no Firebase');
    }
  }

  Future<void> carregarMateriaisFirestore() async {
    try {
      final resultado = await firestore.collection('materiais').get();

      final listaFirebase = resultado.docs.map((doc) {
        final dados = doc.data();

        return dados.map((chave, valor) {
          return MapEntry(chave, valor.toString());
        });
      }).toList();

      setState(() {
        materiais.clear();
        materiais.addAll(listaFirebase);
      });

      debugPrint('✅ Materiais carregados do Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao carregar materiais: $e');
      mostrarMensagem('Erro ao carregar materiais');
    }
  }

  Future<String?> uploadArquivo(PlatformFile arquivo) async {
    try {
      if (arquivo.bytes == null) {
        mostrarMensagem('Não foi possível ler o arquivo.');
        return null;
      }

      final nomeArquivo =
          '${DateTime.now().millisecondsSinceEpoch}_${arquivo.name}';

      final ref = storage.ref().child('documentos/$nomeArquivo');

      await ref.putData(arquivo.bytes!);

      final url = await ref.getDownloadURL();

      debugPrint('✅ Arquivo enviado: $url');

      return url;
    } catch (e) {
      debugPrint('❌ Erro no upload: $e');
      mostrarMensagem('Erro ao enviar arquivo');
      return null;
    }
  }

  Future<void> abrirDocumento(String url) async {
    try {
      final uri = Uri.parse(url);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Não foi possível abrir o documento';
      }
    } catch (e) {
      debugPrint('❌ Erro ao abrir documento: $e');
      mostrarMensagem('Erro ao abrir documento');
    }
  }

  Future<void> copiarTexto(String texto, String mensagem) async {
    final valor = texto.trim();

    if (valor.isEmpty) {
      mostrarMensagem('Nada disponível para copiar.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: valor));
    mostrarMensagem(mensagem);
  }

  bool parcelaTemCobrancaAsaas(Map<String, String> parcela) {
    final status = (parcela['asaasStatus'] ?? '').trim();
    final paymentId = (parcela['asaasPaymentId'] ?? '').trim();
    final invoiceUrl = (parcela['asaasInvoiceUrl'] ?? '').trim();
    final bankSlipUrl = (parcela['asaasBankSlipUrl'] ?? '').trim();
    final pixCopiaCola = (parcela['asaasPixCopiaCola'] ?? '').trim();

    return status == 'GERADA' ||
        paymentId.isNotEmpty ||
        invoiceUrl.isNotEmpty ||
        bankSlipUrl.isNotEmpty ||
        pixCopiaCola.isNotEmpty;
  }

  Future<void> abrirLinkCobrancaAsaas(Map<String, String> parcela) async {
    final invoiceUrl = (parcela['asaasInvoiceUrl'] ?? '').trim();
    final bankSlipUrl = (parcela['asaasBankSlipUrl'] ?? '').trim();

    if (invoiceUrl.isNotEmpty) {
      await abrirDocumento(invoiceUrl);
      return;
    }

    if (bankSlipUrl.isNotEmpty) {
      await abrirDocumento(bankSlipUrl);
      return;
    }

    mostrarMensagem('Link da cobrança Asaas ainda não disponível.');
  }

  Future<void> abrirBoletoAsaas(Map<String, String> parcela) async {
    final bankSlipUrl = (parcela['asaasBankSlipUrl'] ?? '').trim();

    if (bankSlipUrl.isEmpty) {
      mostrarMensagem('Boleto ainda não disponível para esta cobrança.');
      return;
    }

    await abrirDocumento(bankSlipUrl);
  }

  Future<void> carregarDocumentosFirestore() async {
    try {
      final resultado = await firestore.collection('documentos').get();

      final listaFirebase = resultado.docs.map((doc) {
        final dados = doc.data();

        final mapa = dados.map((chave, valor) {
          return MapEntry(chave, valor.toString());
        });

        mapa['id'] = doc.id;

        return mapa;
      }).toList();

      setState(() {
        documentos.clear();
        documentos.addAll(listaFirebase);
      });

      debugPrint('✅ Documentos carregados do Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao carregar documentos: $e');
      mostrarMensagem('Erro ao carregar documentos');
    }
  }

  Future<void> excluirDocumento(Map<String, String> doc) async {
    try {
      final id = doc['id'];
      final url = doc['arquivoUrl'];

      // 🔥 1. Excluir do Storage
      if (url != null && url.isNotEmpty) {
        final ref = storage.refFromURL(url);
        await ref.delete();
      }

      // 🔥 2. Excluir do Firestore
      if (id != null && id.isNotEmpty) {
        await firestore.collection('documentos').doc(id).delete();
      }

      // 🔥 3. Atualizar tela
      setState(() {
        documentos.removeWhere((d) => d['id'] == id);
      });

      mostrarMensagem('Documento excluído com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao excluir documento: $e');
      mostrarMensagem('Erro ao excluir documento');
    }
  }

  Future<void> gerarParcelasDaGestante(Map<String, String> gestante) async {
    final nome = gestante['nomeGestante'] ?? '';

    final parcelasExistentes = await firestore
        .collection('parcelas')
        .where('gestante', isEqualTo: nome)
        .get();

    if (parcelasExistentes.docs.isNotEmpty) {
      debugPrint('⚠️ Parcelas já existem para essa gestante.');
      return;
    }

    final quantidadeParcelas = int.tryParse(gestante['parcelas'] ?? '1') ?? 1;
    final valorParcela = gestante['valorParcela'] ?? 'R\$ 0,00';
    final valorEntrada = gestante['entrada'] ?? 'R\$ 0,00';
    final parcelasPagas = int.tryParse(gestante['parcelasPagas'] ?? '0') ?? 0;

    Map<String, String> baseFinanceira({
      required String tipo,
      required String numero,
      required String descricao,
      required String valor,
      required String vencimento,
      required String status,
    }) {
      return {
        'gestante': nome,
        'tipo': tipo,
        'numero': numero,
        'descricao': descricao,
        'valor': valor,
        'vencimento': vencimento,
        'status': status,
        'comprovanteNome': '',
        'comprovanteUrl': '',
        'dataPagamento': '',
        'asaasStatus': 'NAO_GERADA',
        'asaasBillingType': '',
        'asaasCustomerId': '',
        'asaasPaymentId': '',
        'asaasInvoiceUrl': '',
        'asaasBankSlipUrl': '',
        'asaasPixQrCode': '',
        'asaasPixCopiaCola': '',
        'asaasPreparadoEm': '',
        'asaasWebhookEvento': '',
        'asaasWebhookRecebidoEm': '',
        'asaasAtualizadoPorWebhook': 'false',
      };
    }

    final entradaExiste = converterValor(valorEntrada) > 0;

    if (entradaExiste) {
      final entradaPaga = parcelasPagas > 0;
      final vencimentoEntrada = gerarVencimentoEntradaHistorico(parcelasPagas);

      final entradaFinanceira = baseFinanceira(
        tipo: 'entrada',
        numero: '0',
        descricao: 'Entrada',
        valor: valorEntrada,
        vencimento: vencimentoEntrada,
        status: entradaPaga ? 'Pago' : 'Pendente',
      );

      if (entradaPaga) {
        entradaFinanceira['dataPagamento'] = vencimentoEntrada;
      }

      setState(() {
        parcelasFinanceiras.add(entradaFinanceira);
      });

      await firestore.collection('parcelas').add(entradaFinanceira);
    }

    for (int i = 1; i <= quantidadeParcelas; i++) {
      final novaParcela = baseFinanceira(
        tipo: 'parcela',
        numero: i.toString(),
        descricao: '$iª Parcela',
        valor: valorParcela,
        vencimento: gerarVencimentoParcelaHistorico(i, parcelasPagas),
        status: i <= parcelasPagas ? 'Pago' : 'Pendente',
      );

      setState(() {
        parcelasFinanceiras.add(novaParcela);
      });

      await firestore.collection('parcelas').add(novaParcela);
    }
  }

  Future<void> carregarParcelasFirestore() async {
    try {
      final resultado = await firestore.collection('parcelas').get();

      final listaFirebase = resultado.docs.map((doc) {
        final dados = doc.data();

        final mapa = dados.map((chave, valor) {
          return MapEntry(chave, valor.toString());
        });

        mapa['id'] = doc.id;

        return mapa;
      }).toList();

      setState(() {
        parcelasFinanceiras.clear();
        parcelasFinanceiras.addAll(listaFirebase);
      });

      debugPrint('✅ Parcelas carregadas do Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao carregar parcelas: $e');
      mostrarMensagem('Erro ao carregar parcelas');
    }
  }

  String gerarVencimentoEntradaHistorico(int parcelasPagas) =>
      fincalc.gerarVencimentoEntradaHistorico(parcelasPagas);

  String rotuloParcelaFinanceira(Map<String, String> parcela) =>
      fincalc.rotuloParcelaFinanceira(parcela);

  String textoStatusAsaas(Map<String, String> parcela) =>
      fincalc.textoStatusAsaas(parcela);

  String detalheWebhookAsaas(Map<String, String> parcela) {
    final atualizadoPorWebhook =
        (parcela['asaasAtualizadoPorWebhook'] ?? 'false').trim() == 'true';
    final evento = (parcela['asaasWebhookEvento'] ?? '').trim();
    final recebidoEm = (parcela['asaasWebhookRecebidoEm'] ?? '').trim();

    if (!atualizadoPorWebhook && evento.isEmpty && recebidoEm.isEmpty) {
      return '';
    }

    final partes = <String>[];

    if (evento.isNotEmpty) {
      partes.add('Evento: $evento');
    }

    if (recebidoEm.isNotEmpty) {
      partes.add('Atualizado em: $recebidoEm');
    }

    if (partes.isEmpty) {
      return 'Webhook Asaas: atualização automática recebida';
    }

    return 'Webhook Asaas: ${partes.join(' • ')}';
  }

  Color corStatusAsaas(Map<String, String> parcela) {
    final status = (parcela['asaasStatus'] ?? 'NAO_GERADA').trim();

    switch (status) {
      case 'PREPARADA':
      case 'PROCESSANDO':
        return Colors.orange;
      case 'GERADA':
      case 'PENDING':
        return Colors.blue;
      case 'PAGA':
      case 'RECEIVED':
      case 'CONFIRMED':
        return Colors.green;
      case 'VENCIDA':
      case 'OVERDUE':
      case 'ERRO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, String>> parcelasDaGestanteFicha(Map<String, String> g) {
    final nomeGestante = (g['nomeGestante'] ?? '').trim();
    final gestanteId = (g['id'] ?? '').trim();

    final lista = parcelasFinanceiras.where((p) {
      final parcelaGestante = (p['gestante'] ?? '').trim();
      final parcelaGestanteId = (p['gestanteId'] ?? '').trim();

      return (nomeGestante.isNotEmpty && parcelaGestante == nomeGestante) ||
          (gestanteId.isNotEmpty && parcelaGestanteId == gestanteId);
    }).toList();

    lista.sort((a, b) {
      final numeroA = int.tryParse(a['numero'] ?? '0') ?? 0;
      final numeroB = int.tryParse(b['numero'] ?? '0') ?? 0;

      if (numeroA != numeroB) {
        return numeroA.compareTo(numeroB);
      }

      return converterDataBr(
        a['vencimento'] ?? '',
      ).compareTo(converterDataBr(b['vencimento'] ?? ''));
    });

    return lista;
  }

  double totalParcelasPorStatusGestante(
    List<Map<String, String>> parcelas,
    bool Function(Map<String, String> parcela) filtro,
  ) {
    double total = 0;

    for (final parcela in parcelas) {
      if (filtro(parcela)) {
        total += converterValor(parcela['valor'] ?? '0');
      }
    }

    return total;
  }

  String textoStatusParcelaPremium(Map<String, String> parcela) {
    final pago = (parcela['status'] ?? '') == 'Pago';
    final atrasado = parcelaEstaAtrasada(parcela);

    if (pago) return 'Paga';
    if (atrasado) return 'Vencida';
    if (parcelaTemCobrancaAsaas(parcela)) return 'Gerada';

    return 'Pendente';
  }

  Color corStatusParcelaPremium(Map<String, String> parcela) {
    final status = textoStatusParcelaPremium(parcela);

    if (status == 'Paga') return Colors.green;
    if (status == 'Vencida') return Colors.red;
    if (status == 'Gerada') return Colors.blue;

    return Colors.orange;
  }

  IconData iconeStatusParcelaPremium(Map<String, String> parcela) {
    final status = textoStatusParcelaPremium(parcela);

    if (status == 'Paga') return Icons.check_circle;
    if (status == 'Vencida') return Icons.warning_rounded;
    if (status == 'Gerada') return Icons.account_balance_wallet_outlined;

    return Icons.schedule_rounded;
  }

  Widget miniCardFinanceiroGestante(
    String titulo,
    String valor,
    IconData icone,
    Color cor,
  ) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: cor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: NatusApp.textoSuave,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget linhaTimelineFinanceira(String texto, IconData icone, Color cor) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, color: NatusApp.textoSuave),
            ),
          ),
        ],
      ),
    );
  }

  Widget cardParcelaFinanceiraGestante(Map<String, String> parcela) {
    final cor = corStatusParcelaPremium(parcela);
    final status = textoStatusParcelaPremium(parcela);
    final detalheWebhook = detalheWebhookAsaas(parcela);
    final temCobranca = parcelaTemCobrancaAsaas(parcela);
    final pago = (parcela['status'] ?? '') == 'Pago';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(iconeStatusParcelaPremium(parcela), color: cor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rotuloParcelaFinanceira(parcela)} • ${parcela['valor'] ?? 'R\$ 0,00'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vencimento: ${parcela['vencimento'] ?? 'Não informado'}',
                      style: TextStyle(color: NatusApp.textoSuave),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: cor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          linhaTimelineFinanceira(
            'Asaas: ${textoStatusAsaas(parcela)}',
            Icons.account_balance_wallet_outlined,
            corStatusAsaas(parcela),
          ),
          if ((parcela['asaasGeradoEm'] ?? '').isNotEmpty)
            linhaTimelineFinanceira(
              'Cobrança gerada em ${parcela['asaasGeradoEm']}',
              Icons.pix,
              Colors.blue,
            ),
          if ((parcela['asaasConsultadoEm'] ?? '').isNotEmpty)
            linhaTimelineFinanceira(
              'Status consultado em ${parcela['asaasConsultadoEm']}',
              Icons.sync,
              NatusApp.vinho,
            ),
          if (detalheWebhook.isNotEmpty)
            linhaTimelineFinanceira(
              detalheWebhook,
              Icons.bolt_rounded,
              Colors.green,
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!pago)
                ElevatedButton.icon(
                  onPressed: temCobranca
                      ? null
                      : () async {
                          await gerarCobrancaAsaas(parcela);
                        },
                  icon: const Icon(Icons.pix, size: 17),
                  label: Text(
                    temCobranca ? 'Cobrança gerada' : 'Gerar cobrança',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NatusApp.vinho,
                    foregroundColor: (NatusApp.escuro
                        ? NatusApp.fundo
                        : NatusApp.offWhite),
                  ),
                ),
              if (temCobranca)
                OutlinedButton.icon(
                  onPressed: () async {
                    await consultarStatusCobrancaAsaas(parcela);
                  },
                  icon: const Icon(Icons.sync, size: 17),
                  label: const Text('Consultar status'),
                ),
              if (temCobranca)
                OutlinedButton.icon(
                  onPressed: () async {
                    await abrirLinkCobrancaAsaas(parcela);
                  },
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('Abrir cobrança'),
                ),
              if ((parcela['asaasPixCopiaCola'] ?? '').trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    await copiarTexto(
                      parcela['asaasPixCopiaCola'] ?? '',
                      'Pix copia e cola copiado.',
                    );
                  },
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('Copiar Pix'),
                ),
              if ((parcela['asaasBankSlipUrl'] ?? '').trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    await abrirBoletoAsaas(parcela);
                  },
                  icon: const Icon(Icons.receipt_long, size: 17),
                  label: const Text('Boleto'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget financeiroGestantePremium(Map<String, String> g) {
    final parcelas = parcelasDaGestanteFicha(g);
    final totalPlano = converterValor(g['valorPlano'] ?? '0');
    final totalParcelas = totalParcelasPorStatusGestante(parcelas, (_) => true);
    final totalBase = totalPlano > 0 ? totalPlano : totalParcelas;
    final totalPago = totalParcelasPorStatusGestante(
      parcelas,
      (p) => (p['status'] ?? '') == 'Pago',
    );
    final totalVencido = totalParcelasPorStatusGestante(
      parcelas,
      (p) => (p['status'] ?? '') != 'Pago' && parcelaEstaAtrasada(p),
    );
    final totalPendente = totalParcelasPorStatusGestante(
      parcelas,
      (p) => (p['status'] ?? '') != 'Pago' && !parcelaEstaAtrasada(p),
    );

    return blocoFicha('Financeiro da gestante', [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          miniCardFinanceiroGestante(
            'Total do plano',
            formatarMoeda(totalBase),
            Icons.summarize_rounded,
            NatusApp.vinho,
          ),
          miniCardFinanceiroGestante(
            'Total pago',
            formatarMoeda(totalPago),
            Icons.check_circle,
            Colors.green,
          ),
          miniCardFinanceiroGestante(
            'Pendente',
            formatarMoeda(totalPendente),
            Icons.schedule_rounded,
            Colors.orange,
          ),
          miniCardFinanceiroGestante(
            'Vencido',
            formatarMoeda(totalVencido),
            Icons.warning_rounded,
            Colors.red,
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (parcelas.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NatusApp.rose.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Nenhuma parcela encontrada para esta gestante.',
            style: TextStyle(color: NatusApp.textoSuave),
          ),
        )
      else
        ...parcelas.map(cardParcelaFinanceiraGestante),
    ]);
  }

  Future<void> gerarCobrancaAsaas(Map<String, String> parcela) async {
    final id = parcela['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem(
        'Parcela sem ID. Recarregue a tela antes de gerar a cobrança.',
      );
      return;
    }

    if ((parcela['status'] ?? '') == 'Pago') {
      mostrarMensagem(
        'Esta parcela já está paga. Não é necessário gerar cobrança Asaas.',
      );
      return;
    }

    final asaasStatusAtual = (parcela['asaasStatus'] ?? 'NAO_GERADA').trim();
    final asaasPaymentIdAtual = (parcela['asaasPaymentId'] ?? '').trim();

    if (asaasStatusAtual == 'GERADA' && asaasPaymentIdAtual.isNotEmpty) {
      mostrarMensagem('Esta parcela já possui cobrança Asaas gerada.');
      return;
    }

    try {
      mostrarMensagem('Gerando cobrança Asaas...');

      await firestore.collection('parcelas').doc(id).update({
        'asaasStatus': 'PROCESSANDO',
        'asaasBillingType': 'PIX_BOLETO',
        'asaasProcessandoEm': formatarDataHora(DateTime.now()),
      });

      setState(() {
        parcela['asaasStatus'] = 'PROCESSANDO';
        parcela['asaasBillingType'] = 'PIX_BOLETO';
        parcela['asaasProcessandoEm'] = formatarDataHora(DateTime.now());
      });

      final callable = FirebaseFunctions.instance.httpsCallable(
        'gerarCobrancaAsaas',
      );
      final resposta = await callable.call({
        'parcelaId': id,
        'gestanteId': parcela['gestanteId'] ?? '',
      });

      final data = Map<String, dynamic>.from(resposta.data as Map);
      final dadosAtualizados = <String, String>{
        'asaasStatus': (data['asaasStatus'] ?? 'GERADA').toString(),
        'asaasBillingType': (data['asaasBillingType'] ?? 'PIX_BOLETO')
            .toString(),
        'asaasCustomerId': (data['asaasCustomerId'] ?? '').toString(),
        'asaasPaymentId': (data['asaasPaymentId'] ?? '').toString(),
        'asaasInvoiceUrl': (data['asaasInvoiceUrl'] ?? '').toString(),
        'asaasBankSlipUrl': (data['asaasBankSlipUrl'] ?? '').toString(),
        'asaasPixQrCode': (data['asaasPixQrCode'] ?? '').toString(),
        'asaasPixCopiaCola': (data['asaasPixCopiaCola'] ?? '').toString(),
        'asaasGeradoEm': formatarDataHora(DateTime.now()),
      };

      setState(() {
        dadosAtualizados.forEach((chave, valor) {
          parcela[chave] = valor;
        });
      });

      mostrarMensagem('Cobrança Asaas gerada com sucesso.');
    } on FirebaseFunctionsException catch (e) {
      await firestore.collection('parcelas').doc(id).update({
        'asaasStatus': 'ERRO',
        'asaasErro': e.message ?? e.code,
      });

      setState(() {
        parcela['asaasStatus'] = 'ERRO';
        parcela['asaasErro'] = e.message ?? e.code;
      });

      debugPrint('❌ Erro Firebase Functions Asaas: ${e.code} - ${e.message}');
      mostrarMensagem(e.message ?? 'Erro ao gerar cobrança Asaas.');
    } catch (e) {
      await firestore.collection('parcelas').doc(id).update({
        'asaasStatus': 'ERRO',
        'asaasErro': e.toString(),
      });

      setState(() {
        parcela['asaasStatus'] = 'ERRO';
        parcela['asaasErro'] = e.toString();
      });

      debugPrint('❌ Erro ao gerar cobrança Asaas: $e');
      mostrarMensagem('Erro ao gerar cobrança Asaas.');
    }
  }

  Future<void> consultarStatusCobrancaAsaas(Map<String, String> parcela) async {
    final id = parcela['id'];
    final asaasPaymentId = (parcela['asaasPaymentId'] ?? '').trim();

    if (id == null || id.isEmpty) {
      mostrarMensagem(
        'Parcela sem ID. Recarregue a tela antes de consultar a cobrança.',
      );
      return;
    }

    if (asaasPaymentId.isEmpty) {
      mostrarMensagem(
        'Esta parcela ainda não possui cobrança Asaas para consultar.',
      );
      return;
    }

    try {
      mostrarMensagem('Consultando status no Asaas...');

      await firestore.collection('parcelas').doc(id).update({
        'asaasConsultandoEm': formatarDataHora(DateTime.now()),
      });

      final callable = FirebaseFunctions.instance.httpsCallable(
        'consultarCobrancaAsaas',
      );
      final resposta = await callable.call({
        'parcelaId': id,
        'asaasPaymentId': asaasPaymentId,
      });

      final data = Map<String, dynamic>.from(resposta.data as Map);
      final asaasStatus =
          (data['asaasStatus'] ?? parcela['asaasStatus'] ?? 'GERADA')
              .toString();
      final statusParcela = (data['statusParcela'] ?? '').toString();

      final dadosAtualizados = <String, String>{
        'asaasStatus': asaasStatus,
        'asaasBillingType':
            (data['asaasBillingType'] ?? parcela['asaasBillingType'] ?? '')
                .toString(),
        'asaasCustomerId':
            (data['asaasCustomerId'] ?? parcela['asaasCustomerId'] ?? '')
                .toString(),
        'asaasPaymentId':
            (data['asaasPaymentId'] ?? parcela['asaasPaymentId'] ?? '')
                .toString(),
        'asaasInvoiceUrl':
            (data['asaasInvoiceUrl'] ?? parcela['asaasInvoiceUrl'] ?? '')
                .toString(),
        'asaasBankSlipUrl':
            (data['asaasBankSlipUrl'] ?? parcela['asaasBankSlipUrl'] ?? '')
                .toString(),
        'asaasPixQrCode':
            (data['asaasPixQrCode'] ?? parcela['asaasPixQrCode'] ?? '')
                .toString(),
        'asaasPixCopiaCola':
            (data['asaasPixCopiaCola'] ?? parcela['asaasPixCopiaCola'] ?? '')
                .toString(),
        'asaasConsultadoEm': formatarDataHora(DateTime.now()),
      };

      if (statusParcela.isNotEmpty) {
        dadosAtualizados['status'] = statusParcela;
      } else if (asaasStatus == 'PAGA') {
        dadosAtualizados['status'] = 'Pago';
        dadosAtualizados['dataPagamento'] = formatarDataHora(DateTime.now());
      } else if (asaasStatus == 'VENCIDA') {
        dadosAtualizados['status'] = 'Pendente';
      }

      await firestore.collection('parcelas').doc(id).update(dadosAtualizados);

      setState(() {
        dadosAtualizados.forEach((chave, valor) {
          parcela[chave] = valor;
        });
      });

      mostrarMensagem('Status da cobrança atualizado.');
    } on FirebaseFunctionsException catch (e) {
      await firestore.collection('parcelas').doc(id).update({
        'asaasErroConsulta': e.message ?? e.code,
        'asaasConsultadoEm': formatarDataHora(DateTime.now()),
      });

      debugPrint(
        '❌ Erro Firebase Functions consulta Asaas: ${e.code} - ${e.message}',
      );
      mostrarMensagem(e.message ?? 'Erro ao consultar cobrança Asaas.');
    } catch (e) {
      await firestore.collection('parcelas').doc(id).update({
        'asaasErroConsulta': e.toString(),
        'asaasConsultadoEm': formatarDataHora(DateTime.now()),
      });

      debugPrint('❌ Erro ao consultar cobrança Asaas: $e');
      mostrarMensagem('Erro ao consultar cobrança Asaas.');
    }
  }

  Future<void> salvarContracaoFirestore(Map<String, String> contracao) async {
    try {
      await firestore.collection('contracoes').add(contracao);

      debugPrint('✅ Contração salva no Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao salvar contração: $e');
      mostrarMensagem('Erro ao salvar contração no Firebase');
    }
  }

  Future<void> abrirQuitacaoAntecipada(Map<String, String> parcela) async {
    final nomeGestante = parcela['gestante'] ?? '';

    final pendentes = fincalc.parcelasPendentesDaGestante(
      parcelasFinanceiras,
      nomeGestante,
    );

    if (pendentes.isEmpty) {
      mostrarMensagem('Nenhuma parcela pendente para $nomeGestante.');
      return;
    }

    final total = fincalc.somarValorParcelas(pendentes);
    final temCobrancaAsaas = pendentes.any(parcelaTemCobrancaAsaas);

    String descontoSelecionado = '0%';

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final percentual =
                double.tryParse(descontoSelecionado.replaceAll('%', '')) ?? 0;
            final valorFinal = fincalc.valorQuitacaoComDesconto(
              total,
              percentual,
            );

            return AlertDialog(
              title: const Text('Quitação antecipada'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeGestante,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: NatusApp.vinho,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${pendentes.length} parcela(s) pendente(s) • Total: ${formatarMoeda(total)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: NatusApp.textoSuave,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: descontoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Desconto pela quitação',
                      ),
                      items: [
                        for (final d in [
                          '0%',
                          '1%',
                          '2%',
                          '3%',
                          '4%',
                          '5%',
                          '6%',
                          '7%',
                          '8%',
                          '9%',
                          '10%',
                        ])
                          DropdownMenuItem(value: d, child: Text(d)),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          descontoSelecionado = v ?? '0%';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NatusApp.douradoClaro.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VALOR DA QUITAÇÃO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: NatusApp.douradoEscuro,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatarMoeda(valorFinal),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: NatusApp.vinho,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (temCobrancaAsaas) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Atenção: há cobranças Asaas geradas para parcelas '
                        'desta gestante. Cancele-as no painel do Asaas para '
                        'evitar cobrança em duplicidade.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC07A3D),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar quitação'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmou != true) return;

    final percentual =
        double.tryParse(descontoSelecionado.replaceAll('%', '')) ?? 0;

    await quitarParcelasGestante(
      pendentes,
      nomeGestante,
      percentual,
      fincalc.valorQuitacaoComDesconto(total, percentual),
    );
  }

  Future<void> quitarParcelasGestante(
    List<Map<String, String>> pendentes,
    String nomeGestante,
    double percentualDesconto,
    double valorFinal,
  ) async {
    final agora = formatarDataHora(DateTime.now());
    final descontoTexto = '${percentualDesconto.toStringAsFixed(0)}%';

    final batch = firestore.batch();
    var comId = 0;

    for (final p in pendentes) {
      final id = p['id'];
      if (id != null && id.isNotEmpty) {
        batch.update(firestore.collection('parcelas').doc(id), {
          'status': 'Pago',
          'dataPagamento': agora,
          'quitacaoAntecipada': 'true',
          'descontoQuitacao': descontoTexto,
        });
        comId++;
      }
    }

    if (comId > 0) {
      await batch.commit();
    }

    setState(() {
      for (final p in pendentes) {
        p['status'] = 'Pago';
        p['dataPagamento'] = agora;
        p['quitacaoAntecipada'] = 'true';
        p['descontoQuitacao'] = descontoTexto;
      }
    });

    mostrarMensagem(
      'Plano de $nomeGestante quitado: ${pendentes.length} parcela(s) '
      'baixada(s) por ${formatarMoeda(valorFinal)} '
      '(desconto de $descontoTexto).',
    );
  }

  Future<void> darBaixaParcela(Map<String, String> parcela) async {
    if (arquivoSelecionado == null) {
      mostrarMensagem('Selecione o comprovante Pix antes de dar baixa.');
      return;
    }

    mostrarMensagem('Enviando comprovante...');

    final urlComprovante = await uploadArquivo(arquivoSelecionado!);

    if (urlComprovante == null) {
      mostrarMensagem('Erro ao enviar comprovante.');
      return;
    }

    final id = parcela['id'];

    final dadosAtualizados = {
      'status': 'Pago',
      'comprovanteNome': arquivoSelecionado!.name,
      'comprovanteUrl': urlComprovante,
      'dataPagamento': formatarDataHora(DateTime.now()),
    };

    if (id != null && id.isNotEmpty) {
      await firestore.collection('parcelas').doc(id).update(dadosAtualizados);
    }

    setState(() {
      parcela['status'] = 'Pago';
      parcela['comprovanteNome'] = arquivoSelecionado!.name;
      parcela['comprovanteUrl'] = urlComprovante;
      parcela['dataPagamento'] = formatarDataHora(DateTime.now());

      arquivoSelecionado = null;
    });

    mostrarMensagem('Parcela baixada com sucesso!');
  }

  String nomeMes(int mes) {
    switch (mes) {
      case 1:
        return 'Janeiro';
      case 2:
        return 'Fevereiro';
      case 3:
        return 'Março';
      case 4:
        return 'Abril';
      case 5:
        return 'Maio';
      case 6:
        return 'Junho';
      case 7:
        return 'Julho';
      case 8:
        return 'Agosto';
      case 9:
        return 'Setembro';
      case 10:
        return 'Outubro';
      case 11:
        return 'Novembro';
      case 12:
        return 'Dezembro';
      default:
        return 'Mês inválido';
    }
  }

  Future<void> exportarFinanceiroExcel() async {
    final arquivoExcel = excel.Excel.createExcel();
    final sheet = arquivoExcel['Financeiro'];
    arquivoExcel.delete('Sheet1');

    sheet.appendRow([
      excel.TextCellValue('Relatório Financeiro - Natus Gestantes'),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Período'),
      excel.TextCellValue('${nomeMes(mesSelecionado)} / $anoSelecionado'),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([excel.TextCellValue('Resumo')]);

    sheet.appendRow([
      excel.TextCellValue('Recebido no mês'),
      excel.TextCellValue(formatarMoeda(calcularValorRecebidoMesAtual())),
    ]);

    sheet.appendRow([
      excel.TextCellValue('A receber no mês'),
      excel.TextCellValue(formatarMoeda(calcularValorAReceberReal())),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Atrasado no mês'),
      excel.TextCellValue(formatarMoeda(calcularValorAtrasadoMesAtual())),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Total previsto no mês'),
      excel.TextCellValue(formatarMoeda(calcularTotalPrevistoMesSelecionado())),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([
      excel.TextCellValue('Gestante'),
      excel.TextCellValue('Parcela'),
      excel.TextCellValue('Valor'),
      excel.TextCellValue('Vencimento'),
      excel.TextCellValue('Status'),
      excel.TextCellValue('Comprovante'),
      excel.TextCellValue('Data pagamento'),
    ]);

    final parcelasDoMes = parcelasFinanceiras.where((p) {
      return parcelaEhDoMesSelecionado(p);
    }).toList();

    for (var p in parcelasDoMes) {
      final atrasado = parcelaEstaAtrasada(p);

      final status = p['status'] == 'Pago'
          ? 'Pago'
          : atrasado
          ? 'Atrasado'
          : 'Pendente';

      sheet.appendRow([
        excel.TextCellValue(p['gestante'] ?? ''),
        excel.TextCellValue(p['numero'] ?? ''),
        excel.TextCellValue(p['valor'] ?? ''),
        excel.TextCellValue(p['vencimento'] ?? ''),
        excel.TextCellValue(status),
        excel.TextCellValue(p['comprovanteNome'] ?? ''),
        excel.TextCellValue(p['dataPagamento'] ?? ''),
      ]);
    }

    final bytes = arquivoExcel.encode();

    if (bytes == null) {
      mostrarMensagem('Erro ao gerar Excel');
      return;
    }

    mostrarMensagem(
      'Exportação de Excel disponível apenas na versão web por enquanto.',
    );
  }

  Widget telaFinanceiro() {
    final parcelasDoMes = parcelasFinanceiras.where((p) {
      return parcelaEhDoMesSelecionado(p);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financeiro',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Text(
                'Período: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: NatusApp.vinho,
                ),
              ),
              const SizedBox(width: 12),

              // MÊS
              DropdownButton<int>(
                value: mesSelecionado,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Janeiro')),
                  DropdownMenuItem(value: 2, child: Text('Fevereiro')),
                  DropdownMenuItem(value: 3, child: Text('Março')),
                  DropdownMenuItem(value: 4, child: Text('Abril')),
                  DropdownMenuItem(value: 5, child: Text('Maio')),
                  DropdownMenuItem(value: 6, child: Text('Junho')),
                  DropdownMenuItem(value: 7, child: Text('Julho')),
                  DropdownMenuItem(value: 8, child: Text('Agosto')),
                  DropdownMenuItem(value: 9, child: Text('Setembro')),
                  DropdownMenuItem(value: 10, child: Text('Outubro')),
                  DropdownMenuItem(value: 11, child: Text('Novembro')),
                  DropdownMenuItem(value: 12, child: Text('Dezembro')),
                ],
                onChanged: (v) {
                  setState(() {
                    mesSelecionado = v!;
                  });
                },
              ),

              const SizedBox(width: 16),

              // ANO
              DropdownButton<int>(
                value: anoSelecionado,
                items: List.generate(5, (index) {
                  final ano = DateTime.now().year - 2 + index;

                  return DropdownMenuItem(
                    value: ano,
                    child: Text(ano.toString()),
                  );
                }),
                onChanged: (v) {
                  setState(() {
                    anoSelecionado = v!;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: exportarFinanceiroExcel,
            icon: const Icon(Icons.table_chart),
            label: const Text('Exportar Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NatusApp.vinho,
              foregroundColor: (NatusApp.escuro
                  ? NatusApp.fundo
                  : NatusApp.offWhite),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              cardResumo(
                'Recebido no mês',
                formatarMoeda(calcularValorRecebidoMesAtual()),
                Icons.check_circle,
              ),
              cardResumo(
                'A receber no mês',
                formatarMoeda(calcularValorAReceberReal()),
                Icons.pending_actions,
              ),
              cardResumo(
                'Atrasado no mês',
                formatarMoeda(calcularValorAtrasadoMesAtual()),
                Icons.warning,
              ),
              cardResumo(
                'Total previsto no mês',
                formatarMoeda(calcularTotalPrevistoMesSelecionado()),
                Icons.summarize,
              ),
            ],
          ),

          Text(
            'Parcelas do mês atual',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),

          const SizedBox(height: 12),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              filtroFinanceiroBotao('Todos'),
              filtroFinanceiroBotao('Pagos'),
              filtroFinanceiroBotao('Pendentes'),
              filtroFinanceiroBotao('Atrasados'),
            ],
          ),

          const SizedBox(height: 18),

          if (parcelasDoMes.isEmpty)
            if (parcelasDoMes.isEmpty)
              const Text('Nenhuma parcela encontrada para este mês.'),

          ...parcelasDoMes
              .where((p) {
                final pago = p['status'] == 'Pago';
                final atrasado = parcelaEstaAtrasada(p);

                if (filtroFinanceiro == 'Pagos') {
                  return pago;
                }

                if (filtroFinanceiro == 'Pendentes') {
                  return !pago && !atrasado;
                }

                if (filtroFinanceiro == 'Atrasados') {
                  return atrasado;
                }

                return true;
              })
              .map((p) {
                final pago = p['status'] == 'Pago';
                final atrasado = parcelaEstaAtrasada(p);

                return NatusParcelaItem(
                  parcela: p,
                  rotulo: rotuloParcelaFinanceira(p),
                  pago: pago,
                  atrasado: atrasado,
                  statusAsaasTexto: textoStatusAsaas(p),
                  statusAsaasCor: corStatusAsaas(p),
                  temCobrancaAsaas: parcelaTemCobrancaAsaas(p),
                  onAbrirCobranca: () async {
                    await abrirLinkCobrancaAsaas(p);
                  },
                  onConsultarStatus: () async {
                    await consultarStatusCobrancaAsaas(p);
                  },
                  onCopiarPix: () async {
                    await copiarTexto(
                      p['asaasPixCopiaCola'] ?? '',
                      'Pix copia e cola copiado.',
                    );
                  },
                  onAbrirBoleto: () async {
                    await abrirBoletoAsaas(p);
                  },
                  onAbrirComprovante: () async {
                    final url = p['comprovanteUrl'];

                    if (url != null && url.isNotEmpty) {
                      await abrirDocumento(url);
                    } else {
                      mostrarMensagem('Comprovante não encontrado.');
                    }
                  },
                  onGerarCobranca: () async {
                    await gerarCobrancaAsaas(p);
                  },
                  onSelecionarComprovante: () async {
                    await selecionarArquivo();
                  },
                  onDarBaixa: () async {
                    await darBaixaParcela(p);
                  },
                  onQuitarPlano: () async {
                    await abrirQuitacaoAntecipada(p);
                  },
                );
              }),
        ],
      ),
    );
  }

  Widget telaDashboard() {
    final amamentacaoDados = contarAmamentacao();
    final crescimentoNascimentos = calcularCrescimentoNascimentos();

    final estoqueBaixo = materiaisComEstoqueBaixo();
    final viaNascimentoDados = contarViaNascimento();
    final riscoDados = contarRiscoGestacional();
    final dgDados = contarDiabetesGestacional();

    List<MapEntry<String, int>> top5Maternidades() {
      final dados = mregras.contarPacientesPorMaternidade(gestantes);

      final lista = dados.entries.toList();

      lista.sort((a, b) => b.value.compareTo(a.value));

      return lista.take(5).toList();
    }

    final recebidoMes = calcularValorRecebidoMesAtual();
    final aReceberMes = calcularValorAReceberReal();
    final atrasadoMes = calcularValorAtrasadoMesAtual();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NatusSaudacaoDashboard(
            nomeEoLogada().trim().isEmpty ? 'equipe Natus' : nomeEoLogada(),
            subtitulo: 'Período: ${nomeMes(mesSelecionado)} / $anoSelecionado',
          ),

          const SizedBox(height: 20),

          if (usuarioEhAdmin())
            blocoDashboard('Central de alertas', [
              Row(
                children: [
                  Expanded(
                    child: cardAlertaDashboard(
                      'DPP próxima',
                      '${contarGestantesProximasDpp()} gestante(s)',
                      Icons.warning,
                      Colors.orange,
                      onTap: () => abrirPacientesDoDashboard(
                        const FiltroDashboardPacientes(
                          tipo: TipoFiltroDashboardPacientes.dppProxima,
                          titulo: 'DPP próxima',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: cardAlertaDashboard(
                      'Parcelas atrasadas',
                      '${contarParcelasAtrasadasMesSelecionado()} parcela(s)',
                      Icons.warning_amber,
                      Colors.red,
                      onTap: () => abrirFinanceiroDoDashboard('Atrasados'),
                    ),
                  ),
                ],
              ),
            ]),

          const SizedBox(height: 12),

          blocoDashboard('Status das gestantes', [
            Row(
              children: [
                Expanded(
                  child: cardContagemResumo(
                    'Gestantes',
                    contarGestantesPorStatusNoPeriodoDpp('Gestante'),
                    Colors.pink,
                    Icons.pregnant_woman,
                    onTap: () => abrirPacientesDoDashboard(
                      FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.statusNoPeriodo,
                        titulo:
                            'Gestantes em ${nomeMes(mesSelecionado)} / $anoSelecionado',
                        valor: 'Gestante',
                        mes: mesSelecionado,
                        ano: anoSelecionado,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cardContagemResumo(
                    'Puérperas',
                    contarGestantesPorStatusNoPeriodoDpp('Puérpera'),
                    Colors.orange,
                    Icons.child_friendly,
                    onTap: () => abrirPacientesDoDashboard(
                      FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.statusNoPeriodo,
                        titulo:
                            'Puérperas em ${nomeMes(mesSelecionado)} / $anoSelecionado',
                        valor: 'Puérpera',
                        mes: mesSelecionado,
                        ano: anoSelecionado,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cardContagemResumo(
                    'Encerradas',
                    contarEncerradasOuHistoricoNoPeriodoDpp(),
                    Colors.green,
                    Icons.check_circle,
                    onTap: () => abrirPacientesDoDashboard(
                      FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes
                            .encerradasOuHistoricoNoPeriodo,
                        titulo:
                            'Encerradas em ${nomeMes(mesSelecionado)} / $anoSelecionado',
                        mes: mesSelecionado,
                        ano: anoSelecionado,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          blocoDashboard('Risco gestacional (pré-natal)', [
            Row(
              children: [
                Expanded(
                  child: cardContagemResumo(
                    'Risco habitual',
                    riscoDados['Habitual'] ?? 0,
                    Colors.green,
                    Icons.verified_user,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.riscoGestacional,
                        titulo: 'Risco habitual',
                        valor: 'Habitual',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cardContagemResumo(
                    'Risco intermediário',
                    riscoDados['Intermediário'] ?? 0,
                    Colors.orange,
                    Icons.report_problem,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.riscoGestacional,
                        titulo: 'Risco intermediário',
                        valor: 'Intermediário',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cardContagemResumo(
                    'Alto risco',
                    riscoDados['Alto Risco'] ?? 0,
                    Colors.red,
                    Icons.emergency,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.riscoGestacional,
                        titulo: 'Alto risco',
                        valor: 'Alto Risco',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          blocoDashboard('Diabetes gestacional', [
            Row(
              children: [
                Expanded(
                  child: cardContagemResumo(
                    'Com diabetes gestacional',
                    dgDados['Sim'] ?? 0,
                    Colors.red,
                    Icons.bloodtype,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.diabetesGestacional,
                        titulo: 'Com diabetes gestacional',
                        valor: 'Sim',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cardContagemResumo(
                    'Sem diabetes gestacional',
                    dgDados['Não'] ?? 0,
                    Colors.green,
                    Icons.health_and_safety,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.diabetesGestacional,
                        titulo: 'Sem diabetes gestacional',
                        valor: 'Não',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          blocoDashboard('Nascimentos', [
            Row(
              children: [
                Expanded(
                  child: cardContagemResumo(
                    'Nascimentos do mês',
                    contarBebesNoPeriodoSelecionado(),
                    Colors.purple,
                    Icons.baby_changing_station,
                    onTap: () => abrirPacientesDoDashboard(
                      FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.nascimentoNoPeriodo,
                        titulo:
                            'Nascimentos em ${nomeMes(mesSelecionado)} / $anoSelecionado',
                        mes: mesSelecionado,
                        ano: anoSelecionado,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cardContagemResumo(
                    'Bebês $anoSelecionado',
                    contarBebesPorAno(anoSelecionado.toString()),
                    NatusApp.vinho,
                    Icons.child_care,
                    onTap: () => abrirPacientesDoDashboard(
                      FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.nascimentoNoAno,
                        titulo: 'Bebês $anoSelecionado',
                        ano: anoSelecionado,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cardContagemResumo(
                    'Bebês 2025',
                    contarBebesPorAno('2025'),
                    Colors.grey,
                    Icons.child_care,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.nascimentoNoAno,
                        titulo: 'Bebês 2025',
                        ano: 2025,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              blocoDashboard('Crescimento anual', [
                Text(
                  ' ',
                  style: TextStyle(fontSize: 12.5, color: NatusApp.textoSuave),
                ),

                const SizedBox(height: 16),

                NatusPainelCrescimento(crescimentoNascimentos),

                const SizedBox(height: 22),

                NatusGraficoLinhaCrescimento(
                  anos: crescimentoNascimentos.anosDisponiveis,
                  dadosPorAno: {
                    for (final ano in crescimentoNascimentos.anosDisponiveis)
                      ano: contarBebesPorMes(ano.toString()),
                  },
                ),
              ]),
            ],
          ),

          const SizedBox(height: 24),

          if (usuarioEhAdmin())
            blocoDashboard('Financeiro do mês', [
              Row(
                children: [
                  Expanded(
                    child: cardFinanceiroResumo(
                      'Recebido',
                      recebidoMes,
                      Colors.green,
                      Icons.check_circle,
                      onTap: () => abrirFinanceiroDoDashboard('Pagos'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: cardFinanceiroResumo(
                      'A receber',
                      aReceberMes,
                      Colors.orange,
                      Icons.pending_actions,
                      onTap: () => abrirFinanceiroDoDashboard('Pendentes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: cardFinanceiroResumo(
                      'Atrasado',
                      atrasadoMes,
                      Colors.red,
                      Icons.warning,
                      onTap: () => abrirFinanceiroDoDashboard('Atrasados'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: cardFinanceiroResumo(
                      'Inadimplência',
                      calcularPercentualInadimplencia(),
                      corInadimplencia(calcularPercentualInadimplencia()),
                      Icons.percent,
                      sufixo: '%',
                      onTap: () => abrirFinanceiroDoDashboard('Atrasados'),
                    ),
                  ),
                ],
              ),
            ]),

          const SizedBox(height: 8),

          blocoDashboard('Amamentação', [
            NatusGraficoAmamentacao(amamentacaoDados),
          ]),

          blocoDashboard('Partos e cesáreas', [
            Row(
              children: [
                Expanded(
                  child: cardContagemResumo(
                    'Partos normais',
                    (viaNascimentoDados['Vaginal'] ?? 0) +
                        (viaNascimentoDados['Parto'] ?? 0) +
                        (viaNascimentoDados['Normal'] ?? 0),
                    Colors.green,
                    Icons.favorite,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.viaNascimento,
                        titulo: 'Partos normais',
                        valor: 'Normal',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: cardContagemResumo(
                    'Cesáreas',
                    (viaNascimentoDados['Cesárea'] ?? 0) +
                        (viaNascimentoDados['Cesareana'] ?? 0),
                    Colors.orange,
                    Icons.local_hospital,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.viaNascimento,
                        titulo: 'Cesáreas',
                        valor: 'Cesárea',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: cardContagemResumo(
                    'Não informado',
                    viaNascimentoDados['Não informado'] ?? 0,
                    Colors.grey,
                    Icons.help_outline,
                    onTap: () => abrirPacientesDoDashboard(
                      const FiltroDashboardPacientes(
                        tipo: TipoFiltroDashboardPacientes.viaNascimento,
                        titulo: 'Partos sem via informada',
                        valor: 'Não informado',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          if (widget.tipoUsuario == 'obstetra')
            NatusBlocoMetricasObstetra(metricasDoObstetraLogado())
          else
            blocoDashboard('Top 5 obstetras — base total de pacientes', [
              podiumTop5(
                dados: () {
                  final lista = metricasDeTodosObstetras()
                      .map((m) => MapEntry(m.nomeObstetra, m.totalCarteira))
                      .where((e) => e.value > 0)
                      .toList();

                  lista.sort((a, b) => b.value.compareTo(a.value));

                  return lista.take(5).toList();
                }(),
                icone: Icons.medical_services,
                cor: NatusApp.vinho,
                rotulo: 'pacientes',
                onSelecionar: (nome) => abrirPacientesDoDashboard(
                  FiltroDashboardPacientes(
                    tipo: TipoFiltroDashboardPacientes.obstetra,
                    titulo: 'Pacientes de $nome',
                    valor: nome,
                  ),
                ),
              ),
            ]),

          blocoDashboard('Top 5 maternidades mais atendidas', [
            podiumTop5(
              dados: top5Maternidades(),
              icone: Icons.local_hospital,
              cor: NatusApp.marsalaSuave,
              onSelecionar: (nome) => abrirPacientesDoDashboard(
                FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.maternidade,
                  titulo: 'Pacientes em $nome',
                  valor: nome,
                ),
              ),
            ),
          ]),

          if (usuarioEhAdmin())
            blocoDashboard(
              'Estoque baixo detalhado',
              estoqueBaixo.isEmpty
                  ? [const Text('Nenhum material em estoque baixo.')]
                  : estoqueBaixo.map((m) {
                      return itemRanking(
                        '${m['nome']} | Qtd: ${m['quantidade']} | Mínimo: ${m['minimo']}',
                        0,
                      );
                    }).toList(),
            ),
        ],
      ),
    );
  }

  void mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}
