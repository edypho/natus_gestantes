import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'shared/natus_app.dart';
import 'shared/natus_logo.dart';
import 'shared/natus_premium_visual.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as excel;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'super_admin/super_admin_access_guard.dart';
import 'super_admin/super_admin_shell.dart';
import 'super_admin/primeiro_login_saas_dialog.dart';
import 'super_admin/primeiro_login_saas_guard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'agenda/agenda_page.dart';
import 'core/firebase_globals.dart';
import 'core/natus_breakpoints.dart';
import 'core/natus_especialidades.dart';
import 'core/natus_terminologia.dart';
import 'core/sessao_idempotencia.dart';
import 'financeiro/financeiro_calculos.dart' as fincalc;
import 'gestantes/gestantes_regras.dart' as gregras;
import 'gestantes/maternidades_regras.dart' as mregras;
import 'kpis/kpis_calculos.dart' as kpis;
import 'dashboard/dashboard_cards_natus.dart';
import 'dashboard/dashboard_clinica_resumo.dart';
import 'dashboard/dashboard_destino_filtros.dart';
import 'dados/natus_data_source.dart' as dados;
import 'exames/exame_arquivo.dart';
import 'gestantes/card_gestante_lista.dart';
import 'financeiro/parcela_item.dart';
import 'auth/tela_login.dart';
import 'auth/acesso_paciente_mensagem.dart';
import 'auth/autenticacao_mensagens.dart';
import 'features/contratos/contratos.dart';
import 'navigation/menu_inferior_coracao.dart';
import 'notificacoes/notificacoes_central_page.dart';
import 'pacientes/paciente_identidade.dart';
import 'prontuario/atendimento_prontuario_apresentacao.dart';
import 'prontuario/prontuario_identidade.dart';
import 'shared/gestacao_helpers.dart' as gestacao;
import 'services/push_notifications_service.dart';
import 'services/arquivo_download_service.dart';
import 'services/google_maps_web_loader.dart';
import 'services/cep_service.dart';
import 'services/tenant_firestore_service.dart';
import 'saas/contexto_saas.dart';
import 'saas/tenant_access_scope.dart';
import 'seguranca/arquivo_upload_seguro.dart';
import 'seguranca/erro_publico.dart';
import 'seguranca/firebase_app_check_config.dart';
import 'seguranca/log_seguro.dart';
import 'seguranca/url_externa_segura.dart';
import 'uploads/arquivo_upload_resultado.dart';
import 'uploads/upload_erro_mensagem.dart';
import 'uploads/upload_progress_dialog.dart';

export 'core/firebase_globals.dart';
export 'core/usuario_tipos.dart';
export 'auth/tela_login.dart';
import 'core/usuario_tipos.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    } catch (erro) {
      logErroSeguro(
        'Não foi possível limitar a persistência da sessão Web.',
        erro,
      );
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ativarFirebaseAppCheck();

  if (PushNotificationsService.plataformaSuportada) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const NatusApp(home: AuthGate()));

  if (kIsWeb) {
    unawaited(_carregarGoogleMapsWebEmSegundoPlano());
  }
}

Future<void> _carregarGoogleMapsWebEmSegundoPlano() async {
  final mapasWebConfigurado = await carregarGoogleMapsWeb();
  if (!mapasWebConfigurado) {
    logInfoSeguro(
      'Google Maps Web aguardando uma chave publica configurada no build.',
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      initialData: FirebaseAuth.instance.currentUser,
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final user = snapshot.data!;

          return FutureBuilder<List<dynamic>>(
            future: Future.wait<dynamic>([
              firestore.collection('usuarios').doc(user.uid).get(),
              user.getIdTokenResult(true),
            ]),
            builder: (context, snapshotUser) {
              if (snapshotUser.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshotUser.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text('Não foi possível validar o acesso.'),
                  ),
                );
              }

              final dadosSessao = snapshotUser.data;
              final usuarioDoc = dadosSessao == null
                  ? null
                  : dadosSessao[0] as DocumentSnapshot;

              if (usuarioDoc == null || !usuarioDoc.exists) {
                return const Scaffold(
                  body: Center(
                    child: Text('Usuário não configurado no sistema'),
                  ),
                );
              }

              final token = dadosSessao![1] as IdTokenResult;
              final dados = usuarioDoc.data() as Map<String, dynamic>;
              final contextoSaaS = ContextoSaaS.fromUsuario(
                uidUsuario: user.uid,
                emailUsuario: user.email ?? '',
                dados: dados,
                superAdminVerificado: token.claims?['superAdmin'] == true,
              );

              late final TenantAccessScope escopoTenant;
              try {
                escopoTenant = TenantAccessScope.fromContexto(contextoSaaS);
              } on TenantScopeException catch (e) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(e.message, textAlign: TextAlign.center),
                    ),
                  ),
                );
              }

              return FutureBuilder<bool>(
                future: SuperAdminAccessGuard.usuarioPodeAcessar(
                  uid: user.uid,
                  superAdminVerificado: contextoSaaS.superAdmin,
                ),
                builder: (context, snapshotAcesso) {
                  if (snapshotAcesso.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshotAcesso.data != true) {
                    return const Scaffold(
                      body: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            SuperAdminAccessGuard.mensagemAcessoBloqueado,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }

                  final Widget telaPrincipal = contextoSaaS.superAdmin
                      ? SuperAdminShell(
                          nomeUsuario: contextoSaaS.nomeUsuario,
                          emailUsuario: contextoSaaS.emailUsuario,
                        )
                      : TelaPrincipal(
                          tipoUsuario: contextoSaaS.perfil,
                          nomeUsuario: contextoSaaS.nomeUsuario,
                          contextoSaaS: contextoSaaS,
                          escopoTenant: escopoTenant,
                        );

                  if (PrimeiroLoginSaaSGuard.deveTrocarSenha(dados)) {
                    return PrimeiroLoginSaaSGate(
                      uid: user.uid,
                      child: telaPrincipal,
                    );
                  }

                  return telaPrincipal;
                },
              );
            },
          );
        }

        return const TelaLogin();
      },
    );
  }
}

class PrimeiroLoginSaaSGate extends StatefulWidget {
  const PrimeiroLoginSaaSGate({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<PrimeiroLoginSaaSGate> createState() => _PrimeiroLoginSaaSGateState();
}

class _PrimeiroLoginSaaSGateState extends State<PrimeiroLoginSaaSGate> {
  bool _alterando = false;
  bool _concluido = false;

  Future<void> _alterarSenha() async {
    if (_alterando) return;
    setState(() => _alterando = true);

    try {
      final senhaAlterada = await abrirTrocaSenhaPrimeiroLoginSaaS(
        context: context,
        uid: widget.uid,
      );
      if (!senhaAlterada) return;
      if (!mounted) return;
      setState(() => _concluido = true);
    } catch (e) {
      logErroSeguro('Erro ao alterar a senha inicial.', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível alterar a senha.')),
      );
    } finally {
      if (mounted) setState(() => _alterando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_concluido) return widget.child;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_reset_rounded, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Proteja seu acesso',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Antes de continuar, substitua a senha temporária por '
                      'uma senha pessoal e exclusiva.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _alterando ? null : _alterarSenha,
                      icon: _alterando
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.password_rounded),
                      label: Text(
                        _alterando ? 'Alterando...' : 'Definir nova senha',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  final String tipoUsuario;
  final String nomeUsuario;
  final ContextoSaaS contextoSaaS;
  final TenantAccessScope escopoTenant;

  const TelaPrincipal({
    super.key,
    required this.tipoUsuario,
    this.nomeUsuario = '',
    required this.contextoSaaS,
    required this.escopoTenant,
  });

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  late final TenantFirestoreService tenantFirestore;
  final CepService cepService = CepService();
  bool alertaPushAberto = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  notificacoesSubscription;
  int notificacoesNaoLidas = 0;

  String nomeArquivoSeguro(String nome) {
    final sanitizado = nome.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitizado.isEmpty ? 'arquivo' : sanitizado;
  }

  String? tipoMimeArquivo(PlatformFile arquivo) {
    final extensao = (arquivo.extension ?? arquivo.name.split('.').last)
        .trim()
        .toLowerCase();

    return switch (extensao) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' => 'video/mp4',
      _ => null,
    };
  }

  SettableMetadata metadadosUpload(
    PlatformFile arquivo, {
    String? pacienteId,
    bool permitirVideo = false,
    int limiteBytes = 25 * 1024 * 1024,
  }) {
    final contentType = tipoMimeArquivo(arquivo);
    if (contentType == null) {
      throw const FormatException(
        'Tipo de arquivo não permitido. Use PDF, JPG, PNG, WebP, HEIC, '
        'HEIF ou MP4.',
      );
    }
    final bytes = arquivo.bytes;
    if (bytes == null ||
        !arquivoPossuiAssinaturaPermitida(bytes, contentType)) {
      throw const FormatException(
        'O conteúdo do arquivo não corresponde ao tipo permitido.',
      );
    }
    if (contentType == 'video/mp4' && !permitirVideo) {
      throw const FormatException(
        'Vídeos em MP4 são aceitos apenas na biblioteca.',
      );
    }

    final limiteEfetivoBytes = contentType == 'video/mp4' && permitirVideo
        ? 250 * 1024 * 1024
        : limiteBytes;
    if (arquivo.size >= limiteEfetivoBytes) {
      final limiteMegabytes = limiteEfetivoBytes ~/ (1024 * 1024);
      throw FormatException(
        'O arquivo excede o limite de $limiteMegabytes MB.',
      );
    }

    final tenantId = widget.escopoTenant.clinicaId;
    if (tenantId.isEmpty) {
      throw const TenantScopeException(
        'O upload exige uma clínica de destino.',
      );
    }

    final uidAutenticado = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uidAutenticado.isEmpty) {
      throw const TenantScopeException(
        'Sua sessão não está disponível para enviar arquivos.',
      );
    }
    if (widget.escopoTenant.uidUsuario.trim() != uidAutenticado) {
      throw const TenantScopeException(
        'A sessão mudou. Atualize a página antes de enviar o arquivo.',
      );
    }

    final idPaciente = (pacienteId ?? '').trim();
    return SettableMetadata(
      contentType: contentType,
      customMetadata: <String, String>{
        'clinicaId': tenantId,
        'adminDonoId': tenantId,
        'enviadoPorUid': uidAutenticado,
        if (idPaciente.isNotEmpty) 'pacienteId': idPaciente,
      },
    );
  }

  Future<void> alterarTipoUsuario(String uid, String tipoAtual) async {
    const tiposAlteraveis = <String>[
      'admin',
      'enfermeira',
      'obstetra',
      'profissional',
      'gestante',
    ];
    final tipoInicial = tiposAlteraveis.contains(tipoAtual) ? tipoAtual : null;
    String novoTipo = tipoInicial ?? '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Alterar tipo de usuário'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mudanças que exigem outro vínculo de paciente ou profissional '
                'são bloqueadas por segurança.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipoInicial,
                items: tiposAlteraveis
                    .map(
                      (tipo) => DropdownMenuItem(
                        value: tipo,
                        child: Text(NatusTermos.rotuloPerfil(tipo)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  novoTipo = value!;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (novoTipo.isEmpty) {
                  mostrarMensagem('Selecione um tipo de usuário válido.');
                  return;
                }

                if (novoTipo == tipoAtual) {
                  Navigator.pop(dialogContext);
                  return;
                }

                try {
                  final callable = FirebaseFunctions.instanceFor(
                    region: 'us-central1',
                  ).httpsCallable('alterarTipoUsuarioClinica');
                  await callable.call({
                    'uidUsuario': uid,
                    'tipoUsuario': novoTipo,
                  });

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  mostrarMensagem('Tipo de usuário atualizado.');
                } on FirebaseFunctionsException catch (e) {
                  mostrarMensagem(
                    mensagemErroFunctionsSeguro(
                      e,
                      fallback: 'Não foi possível alterar o tipo de usuário.',
                    ),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> reenviarConviteUsuario(String email) async {
    final emailNormalizado = email.trim().toLowerCase();
    if (emailNormalizado.isEmpty || !emailNormalizado.contains('@')) {
      mostrarMensagem('Usuário sem e-mail válido para redefinição de senha.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailNormalizado,
      );
      mostrarMensagem('E-mail de definição de senha enviado.');
    } on FirebaseAuthException catch (e) {
      logErroSeguro('Erro ao enviar e-mail de acesso.', e.code);
      mostrarMensagem(mensagemErroEnvioAcessoParaEquipe(e.code));
    } catch (e) {
      logErroSeguro('Erro ao enviar e-mail de acesso.', e);
      mostrarMensagem('Não foi possível enviar o e-mail de acesso.');
    }
  }

  Future<void> carregarContracoesFirestore() async {
    try {
      final listaFirebase = await dados.buscarContracoes(widget.escopoTenant);

      setState(() {
        contracoes.clear();
        contracoes.addAll(listaFirebase);
      });

      logInfoSeguro('Contracoes carregadas do Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao carregar contracoes.', e);
      mostrarMensagem('Erro ao carregar contrações');
    }
  }

  Future<void> salvarEO() async {
    if (eoNomeController.text.trim().isEmpty) {
      mostrarMensagem('Informe o nome da enfermeira.');
      return;
    }

    try {
      await firestore
          .collection('enfermeiras')
          .add(
            tenantFirestore.prepararCriacao({
              'nome': eoNomeController.text.trim(),
              'telefone': eoTelefoneController.text.trim(),
              'email': eoEmailController.text.trim(),
              'coren': eoCorenController.text.trim(),
              'especialidade': eoEspecialidadeController.text.trim(),
              'uidEnfermeira': '',
              'criadoEm': DateTime.now().toIso8601String(),
            }),
          );

      eoNomeController.clear();
      eoTelefoneController.clear();
      eoEmailController.clear();
      eoCorenController.clear();
      eoEspecialidadeController.clear();

      await carregarEnfermeirasFirestore();

      mostrarMensagem('Enfermeira cadastrada com sucesso!');
    } catch (e) {
      logErroSeguro('Erro ao salvar profissional.', e);
      mostrarMensagem('Erro ao salvar profissional.');
    }
  }

  Future<void> salvarObstetra() async {
    if (obNomeController.text.trim().isEmpty) {
      mostrarMensagem('Informe o nome do obstetra.');
      return;
    }

    try {
      await firestore
          .collection('obstetras')
          .add(
            tenantFirestore.prepararCriacao({
              'nome': obNomeController.text.trim(),
              'telefone': obTelefoneController.text.trim(),
              'email': obEmailController.text.trim(),
              'crm': obCrmController.text.trim(),
              'especialidade': obEspecialidadeController.text.trim(),
              'uidObstetra': '',
              'criadoEm': DateTime.now().toIso8601String(),
            }),
          );

      obNomeController.clear();
      obTelefoneController.clear();
      obEmailController.clear();
      obCrmController.clear();
      obEspecialidadeController.clear();

      await carregarObstetrasFirestore();

      mostrarMensagem('Obstetra cadastrado com sucesso!');
    } catch (e) {
      logErroSeguro('Erro ao salvar profissional.', e);
      mostrarMensagem('Erro ao salvar profissional.');
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
        mostrarMensagem('Erro: paciente sem ID do Firebase.');
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
      logErroSeguro('Erro ao salvar dados do procedimento.', e);
      mostrarMensagem('Erro ao salvar dados do procedimento.');
    }
  }

  bool usuarioEhAdmin() {
    return widget.tipoUsuario == 'admin';
  }

  String rotuloPerfilUsuario() {
    return NatusTermos.rotuloPerfil(widget.tipoUsuario);
  }

  String iniciaisPerfilUsuario() {
    final nome = widget.nomeUsuario.trim();
    if (nome.isEmpty) return 'N';

    final partes = nome
        .split(RegExp(r'\s+'))
        .where((parte) => parte.trim().isNotEmpty)
        .toList();

    if (partes.isEmpty) return 'N';
    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }

    return '${partes.first.substring(0, 1)}${partes.last.substring(0, 1)}'
        .toUpperCase();
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

    tenantFirestore = TenantFirestoreService(
      firestore: firestore,
      escopo: widget.escopoTenant,
    );

    NatusTema.atual.addListener(aoMudarTema);

    if (widget.tipoUsuario == 'gestante') {
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
    carregarPerfilUsuarioLogado();
    Future.microtask(inicializarPushOperacional);
    Future.microtask(iniciarEscutaNotificacoes);
  }

  void aoMudarTema() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    notificacoesSubscription?.cancel();
    NatusTema.atual.removeListener(aoMudarTema);
    buscaBibliotecaController.dispose();
    super.dispose();
  }

  bool get podeReceberNotificacoesInternas {
    return widget.tipoUsuario == 'admin' ||
        widget.tipoUsuario == 'enfermeira' ||
        widget.tipoUsuario == 'obstetra';
  }

  String tipoNotificacaoConsulta() {
    return widget.tipoUsuario;
  }

  Future<void> iniciarEscutaNotificacoes() async {
    notificacoesSubscription?.cancel();

    if (!podeReceberNotificacoesInternas) {
      if (mounted && notificacoesNaoLidas != 0) {
        setState(() {
          notificacoesNaoLidas = 0;
        });
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    notificacoesSubscription = tenantFirestore
        .consultaClinica('notificacoesCentral')
        .where('destinatariosTipos', arrayContains: tipoNotificacaoConsulta())
        .orderBy('criadoEm', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) {
            final totalNaoLidas = snapshot.docs.where((doc) {
              final dados = doc.data();
              final lidasPor = ((dados['lidasPor'] as List?) ?? const [])
                  .map((item) => item.toString())
                  .toList();
              return !lidasPor.contains(uid);
            }).length;

            if (!mounted) return;
            setState(() {
              notificacoesNaoLidas = totalNaoLidas;
            });
          },
          onError: (Object erro, StackTrace stackTrace) {
            logErroSeguro('Erro ao escutar notificacoes.', erro);
            if (!mounted || notificacoesNaoLidas == 0) return;
            setState(() {
              notificacoesNaoLidas = 0;
            });
          },
        );
  }

  Future<void> abrirPainelNotificacoes() async {
    if (!podeReceberNotificacoesInternas || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notificações',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, isMobile ? 72 : 22, 16, 16),
              child: NatusPainelNotificacoesFlutuante(
                tipoUsuario: widget.tipoUsuario,
                uidUsuario: uid,
                escopoTenant: widget.escopoTenant,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curva = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curva,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curva),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  Widget botaoSinoNotificacoes() {
    if (!podeReceberNotificacoesInternas) {
      return const SizedBox.shrink();
    }

    final exibirBadge = notificacoesNaoLidas > 0;
    final textoBadge = notificacoesNaoLidas > 9
        ? '9+'
        : '$notificacoesNaoLidas';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: abrirPainelNotificacoes,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: NatusApp.offWhite.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: NatusApp.vinho,
                    size: 24,
                  ),
                ),
                if (exibirBadge)
                  Positioned(
                    bottom: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD94A4A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        textoBadge,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
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
      final lista = await dados.buscarPlanos(widget.escopoTenant);

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
        }
      });
    } catch (e) {
      logErroSeguro('Erro ao carregar planos.', e);
      mostrarMensagem('Erro ao carregar planos.');
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
      await firestore
          .collection('planos')
          .add(
            tenantFirestore.prepararCriacao({
              'nomePlano': nome,
              'valor': valor,
              'valorFormatado': formatarMoeda(valor),
              'parcelas': qtdParcelas.toString(),
              'descricaoComercial': planoDescricaoComercialController.text
                  .trim(),
              'ativo': true,
              'criadoEm': DateTime.now().toIso8601String(),
              'atualizadoEm': DateTime.now().toIso8601String(),
            }),
          );

      planoNomeController.clear();
      planoValorController.clear();
      planoParcelasController.text = '1';
      planoDescricaoComercialController.clear();

      await carregarPlanosFirestore();
      mostrarMensagem('Plano cadastrado com sucesso!');
    } catch (e) {
      logErroSeguro('Erro ao salvar plano.', e);
      mostrarMensagem('Erro ao salvar plano.');
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
      logErroSeguro('Erro ao atualizar plano.', e);
      mostrarMensagem('Erro ao atualizar plano.');
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
        'atualizadoEm': DateTime.now().toIso8601String(),
      });
      await carregarPlanosFirestore();
      mostrarMensagem('Plano atualizado com sucesso!');
    } catch (e) {
      logErroSeguro('Erro ao editar plano.', e);
      mostrarMensagem('Erro ao editar plano.');
    }
  }

  Future<void> abrirArquivo(String url) async {
    if (url.trim().isEmpty) {
      mostrarMensagem('Link do material não encontrado.');
      return;
    }

    final uri = uriHttpsExternaSegura(url);
    if (uri == null) {
      mostrarMensagem('Link externo inválido ou não seguro.');
      return;
    }

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
      final listaFirebase = await dados.buscarEnfermeiras(widget.escopoTenant);

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
      final listaFirebase = await dados.buscarObstetras(widget.escopoTenant);

      setState(() {
        obstetras.clear();
        obstetras.addAll(listaFirebase);
      });
    } catch (e) {
      mostrarMensagem('Erro ao carregar obstetras.');
    }
  }

  Future<void> carregarPerfilUsuarioLogado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      final docUsuario = await firestore.collection('usuarios').doc(uid).get();
      String foto = '';
      String email = '';

      if (docUsuario.exists) {
        final dadosUsuario = docUsuario.data() ?? {};
        foto = (dadosUsuario['fotoUrl'] ?? '').toString().trim();
        email = (dadosUsuario['email'] ?? '').toString().trim();
      }

      if (foto.isEmpty) {
        foto = await buscarFotoPerfilVinculada(uid);
      }

      if (!mounted) return;
      setState(() {
        fotoPerfilUrl = foto;
        emailPerfilLogado = email;
      });
    } catch (e) {
      logErroSeguro('Erro ao carregar perfil do usuario.', e);
    }
  }

  Future<String> buscarFotoPerfilVinculada(String uid) async {
    Future<String> buscarEmColecao(String colecao, String campoUid) async {
      final resultado = await tenantFirestore
          .consultaClinica(colecao)
          .where(campoUid, isEqualTo: uid)
          .limit(1)
          .get();

      if (resultado.docs.isEmpty) return '';
      final dados = resultado.docs.first.data();
      return (dados['fotoUrl'] ?? '').toString().trim();
    }

    if (widget.tipoUsuario == 'gestante') {
      return buscarEmColecao('gestantes', 'uidGestante');
    }

    if (widget.tipoUsuario == 'enfermeira') {
      return buscarEmColecao('enfermeiras', 'uidEnfermeira');
    }

    if (widget.tipoUsuario == 'obstetra') {
      return buscarEmColecao('obstetras', 'uidObstetra');
    }

    return '';
  }

  Future<void> atualizarFotoPerfilVinculada(String uid, String fotoUrl) async {
    Future<void> atualizarColecao(String colecao, String campoUid) async {
      final resultado = await tenantFirestore
          .consultaClinica(colecao)
          .where(campoUid, isEqualTo: uid)
          .limit(1)
          .get();

      if (resultado.docs.isEmpty) return;
      await resultado.docs.first.reference.update({'fotoUrl': fotoUrl});
    }

    if (widget.tipoUsuario == 'gestante') {
      await atualizarColecao('gestantes', 'uidGestante');
    } else if (widget.tipoUsuario == 'enfermeira') {
      await atualizarColecao('enfermeiras', 'uidEnfermeira');
    } else if (widget.tipoUsuario == 'obstetra') {
      await atualizarColecao('obstetras', 'uidObstetra');
    }
  }

  Future<void> selecionarFotoPerfil() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      mostrarMensagem('Usuário não identificado para alterar a foto.');
      return;
    }

    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (resultado == null || resultado.files.isEmpty) return;

    final arquivo = resultado.files.first;
    if (arquivo.bytes == null) {
      mostrarMensagem('Não foi possível ler a imagem selecionada.');
      return;
    }

    setState(() {
      carregandoFotoPerfil = true;
    });

    try {
      final nomeArquivo =
          '${DateTime.now().millisecondsSinceEpoch}_${nomeArquivoSeguro(arquivo.name)}';
      final ref = storage.ref().child(
        tenantFirestore.caminhoStorage('usuarios/$uid/perfil/$nomeArquivo'),
      );

      await ref.putData(
        arquivo.bytes!,
        metadadosUpload(arquivo, limiteBytes: 10 * 1024 * 1024),
      );
      final url = await ref.getDownloadURL();

      await firestore.collection('usuarios').doc(uid).update({
        'fotoUrl': url,
        'fotoAtualizadaEm': DateTime.now().toIso8601String(),
      });

      await atualizarFotoPerfilVinculada(uid, url);

      if (!mounted) return;
      setState(() {
        fotoPerfilUrl = url;
      });

      mostrarMensagem('Foto de perfil atualizada com sucesso.');
    } catch (e) {
      logErroSeguro('Erro ao enviar foto de perfil.', e);
      mostrarMensagem('Erro ao atualizar a foto de perfil.');
    } finally {
      if (mounted) {
        setState(() {
          carregandoFotoPerfil = false;
        });
      }
    }
  }

  Future<void> inicializarPushOperacional() async {
    try {
      await PushNotificationsService.instance.inicializarParaUsuario(
        tipoUsuario: widget.tipoUsuario,
        nomeUsuario: widget.nomeUsuario,
        onForegroundMessage: tratarPushForeground,
      );
    } catch (e) {
      logErroSeguro('Erro ao inicializar push.', e);
    }
  }

  void tratarPushForeground(RemoteMessage message) {
    final tipo = (message.data['tipo'] ?? '').toString().trim();

    if (tipo != 'alerta_contracao' && tipo != 'atualizacao_clinica') {
      return;
    }

    SystemSound.play(SystemSoundType.alert);
    Future.delayed(const Duration(milliseconds: 350), () {
      SystemSound.play(SystemSoundType.alert);
    });

    if (!mounted) return;

    mostrarMensagem('Nova atualização clínica disponível.');

    if (alertaPushAberto) return;

    alertaPushAberto = true;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova atualização clínica'),
          content: const Text(
            'Abra a central de notificações do Natus para consultar os '
            'detalhes com segurança.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      alertaPushAberto = false;
    });
  }

  Future<void> abrirPerfilUsuarioMenu() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Meu perfil'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatarPerfilUsuario(radius: 42),
                const SizedBox(height: 16),
                Text(
                  widget.nomeUsuario.trim().isEmpty
                      ? 'Usuário Natus'
                      : widget.nomeUsuario,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.vinho,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rotuloPerfilUsuario(),
                  style: TextStyle(
                    fontSize: 14,
                    color: NatusApp.textoSuave,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (emailPerfilLogado.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    emailPerfilLogado,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: NatusApp.textoSuave),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: carregandoFotoPerfil
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await selecionarFotoPerfil();
                          },
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      carregandoFotoPerfil
                          ? 'Enviando foto...'
                          : 'Alterar foto',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NatusApp.vinho,
                      foregroundColor: (NatusApp.escuro
                          ? NatusApp.fundo
                          : NatusApp.offWhite),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await abrirSeletorTemaUsuario();
                    },
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Personalizar tema'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NatusApp.vinho,
                      side: BorderSide(
                        color: NatusApp.rose.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Widget avatarPerfilUsuario({double radius = 24}) {
    final imagemUrl = fotoPerfilUrl.trim();
    final imagemUri = uriMidiaNatusSegura(imagemUrl);

    Widget iniciais() => Text(
      iniciaisPerfilUsuario(),
      style: TextStyle(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.bold,
        color: NatusApp.vinho,
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: NatusApp.rose.withValues(alpha: 0.35),
      child: imagemUri == null
          ? iniciais()
          : ClipOval(
              child: Image.network(
                imagemUri.toString(),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: iniciais()),
              ),
            ),
    );
  }

  Future<void> abrirSeletorTemaUsuario() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final paletaAtiva = NatusTema.paleta;
        final largura = MediaQuery.of(context).size.width;
        final cardWidth = largura < 520 ? largura - 48 : 220.0;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: NatusApp.rose.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Tema do aplicativo',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: NatusApp.vinho,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Escolha a aparência do Natus para o seu login. A mudança fica salva para as próximas sessões.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: NatusApp.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: NatusTema.paletas.map((p) {
                      return SizedBox(
                        width: cardWidth,
                        child: cartaoTema(p, p.chave == paletaAtiva.chave),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> carregarBibliotecaFirestore() async {
    try {
      final listaFirebase = await dados.buscarBiblioteca(widget.escopoTenant);

      setState(() {
        biblioteca.clear();
        biblioteca.addAll(listaFirebase);
      });

      logInfoSeguro('Biblioteca carregada do Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao carregar biblioteca.', e);
      mostrarMensagem('Erro ao carregar biblioteca');
    }
  }

  Future<void> salvarItemBibliotecaFirestore(
    Map<String, String> material,
  ) async {
    try {
      final docRef = await firestore
          .collection('biblioteca')
          .add(tenantFirestore.prepararCriacaoTexto(material));
      material['id'] = docRef.id;

      await carregarBibliotecaFirestore();
      mostrarMensagem('Material adicionado à biblioteca.');
    } catch (e) {
      logErroSeguro('Erro ao salvar material da biblioteca.', e);
      mostrarMensagem('Erro ao adicionar material à biblioteca.');
    }
  }

  Future<void> atualizarItemBibliotecaFirestore(
    Map<String, String> material,
  ) async {
    final id = (material['id'] ?? '').trim();

    if (id.isEmpty) {
      mostrarMensagem('Material sem ID. Recarregue a biblioteca.');
      return;
    }

    try {
      final dadosAtualizados = Map<String, String>.from(material)..remove('id');
      await firestore.collection('biblioteca').doc(id).update(dadosAtualizados);
      await carregarBibliotecaFirestore();
      mostrarMensagem('Material atualizado com sucesso.');
    } catch (e) {
      logErroSeguro('Erro ao atualizar material da biblioteca.', e);
      mostrarMensagem('Erro ao atualizar material da biblioteca.');
    }
  }

  Future<void> confirmarExcluirItemBiblioteca(
    Map<String, String> material,
  ) async {
    if (!usuarioEhAdmin()) return;

    final id = (material['id'] ?? '').trim();
    final titulo = (material['titulo'] ?? 'Material').trim();

    if (id.isEmpty) {
      mostrarMensagem('Material sem ID. Recarregue a biblioteca.');
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir material'),
          content: Text(
            'Tem certeza que deseja excluir "$titulo" da biblioteca?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Excluir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmou != true) return;

    try {
      await firestore.collection('biblioteca').doc(id).delete();
      await carregarBibliotecaFirestore();
      mostrarMensagem('Material excluído da biblioteca.');
    } catch (e) {
      logErroSeguro('Erro ao excluir material da biblioteca.', e);
      mostrarMensagem('Erro ao excluir material da biblioteca.');
    }
  }

  Future<void> carregarAtendimentosFirestore() async {
    try {
      final listaFirebase = await dados.buscarAtendimentos(widget.escopoTenant);

      setState(() {
        atendimentos.clear();
        atendimentos.addAll(listaFirebase);
      });

      logInfoSeguro('Atendimentos carregados do Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao carregar atendimentos.', e);
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
          logErroSeguro('Erro ao ler arquivo XLSX.', erroExcel);
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
          'Não encontrei cabeçalhos reconhecíveis na planilha. Verifique se existe uma linha com nomes como Paciente, Nome da Gestante, Telefone, DPP ou Nascimento.',
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
            .add(tenantFirestore.prepararCriacaoTexto(novaGestante));
        novaGestante['id'] = docRef.id;

        if (gerarFinanceiro &&
            converterValor(novaGestante['valorPlano'] ?? '0') > 0 &&
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
          ? ' e parcelas de $parcelasCriadas pacientes geradas'
          : '';

      mostrarMensagem(
        'Importação concluída: $importadas importadas, $ignoradas ignoradas$mensagemFinanceiro. Cabeçalho encontrado na linha ${linhaCabecalhoIndex + 1}.',
      );
    } catch (e) {
      logErroSeguro('Erro ao importar pacientes.', e);
      mostrarMensagem('Erro ao importar pacientes.');
    }
  }

  String telaAtual = 'Dashboard';

  String filtroStatusGestante = 'Ativas';
  String filtroPlanoGestante = 'Todos';
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
  final buscaBibliotecaController = TextEditingController();
  String filtroCategoriaBiblioteca = 'Todos';
  String filtroTipoBiblioteca = 'Todos';
  int indiceDestaqueBiblioteca = 0;

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
  final _sessaoCriacaoUsuario = SessaoIdempotencia();

  String novoTipoUsuario = 'gestante';
  String? gestanteSelecionadaLogin;
  String? enfermeiraSelecionadaLogin;
  String? obstetraSelecionadoLogin;
  String fotoPerfilUrl = '';
  String emailPerfilLogado = '';
  bool carregandoFotoPerfil = false;

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
  String especialidadePaciente = NatusEspecialidades.clinicaGeral;
  bool salvandoPaciente = false;

  bool get especialidadePacienteEhObstetricia =>
      NatusEspecialidades.ehObstetricia(especialidadePaciente);

  String get tituloContatoCadastroPaciente =>
      NatusEspecialidades.tituloContato(especialidadePaciente);

  final eoNomeController = TextEditingController();
  final eoTelefoneController = TextEditingController();
  final eoEmailController = TextEditingController();
  final eoCorenController = TextEditingController();
  final eoEspecialidadeController = TextEditingController();
  String tipoProfissionalCadastro = 'EO';

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

  String filtroFinanceiro = 'Pendentes';

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

  String especialidadeDoPaciente(Map<String, String> paciente) {
    final especialidade =
        (paciente['especialidadeAcompanhamento'] ??
                paciente['tipoCadastroPaciente'] ??
                '')
            .trim();
    if (especialidade.isNotEmpty) return especialidade;

    return pacienteTemModuloObstetrico(paciente)
        ? 'Obstetrícia'
        : 'Clínica geral';
  }

  bool pacienteTemModuloObstetrico(Map<String, String> paciente) {
    return pacienteTemModuloObstetriciaDashboard(paciente);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);
    final mostrarMenuInferior = isMobile && exibirMenuInferiorCoracao();
    final telaCoracao = telaCentralMenuCoracao();
    final itensEsquerda = itensMenuInferiorEsquerda();
    final itensDireita = itensMenuInferiorDireita();

    return PremiumNatusBackground(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        drawer: isMobile && !mostrarMenuInferior
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
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: mostrarMenuInferior
                              ? 88.0 + MediaQuery.viewPaddingOf(context).bottom
                              : 0,
                        ),
                        child: telaConteudo(),
                      ),
                      if (!mostrarMenuInferior)
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
                      Align(
                        alignment: Alignment.topRight,
                        child: botaoSinoNotificacoes(),
                      ),
                    ],
                  );
                },
              )
            : Row(
                children: [
                  menuLateral(),
                  Expanded(
                    child: Stack(
                      children: [
                        telaConteudo(),
                        Align(
                          alignment: Alignment.topRight,
                          child: botaoSinoNotificacoes(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: mostrarMenuInferior
            ? NatusMenuInferiorCoracao(
                itensEsquerda: itensEsquerda,
                itensDireita: itensDireita,
                telaAtual: telaAtual,
                onSelecionarTela: selecionarTelaPrincipal,
              )
            : null,
        floatingActionButton: mostrarMenuInferior
            ? NatusFabCoracao(
                ativo: widget.tipoUsuario == 'gestante'
                    ? telaAtual == telaCoracao
                    : false,
                tooltip: widget.tipoUsuario == 'gestante'
                    ? 'Abrir ${NatusTermos.rotuloMenu(telaCoracao)}'
                    : 'Abrir mais opções',
                onTap: () {
                  if (widget.tipoUsuario == 'gestante') {
                    selecionarTelaPrincipal(telaCoracao);
                    return;
                  }

                  abrirMenuSecundarioMobile();
                },
              )
            : null,
        floatingActionButtonLocation: mostrarMenuInferior
            ? FloatingActionButtonLocation.centerDocked
            : null,
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
        'Biblioteca',
        'Documentos',
        'Exames',
        'Usuários',
        'Cadastrar Profissional',
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

    Widget cardPerfilLateral() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: abrirPerfilUsuarioMenu,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      avatarPerfilUsuario(),
                      if (carregandoFotoPerfil)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nomeUsuario.trim().isEmpty
                              ? 'Usuário Natus'
                              : widget.nomeUsuario,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rotuloPerfilUsuario(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opções do perfil',
                    onSelected: (value) async {
                      if (value == 'perfil') {
                        await abrirPerfilUsuarioMenu();
                        return;
                      }
                      if (value == 'foto') {
                        await selecionarFotoPerfil();
                        return;
                      }
                      if (value == 'sair') {
                        NatusTema.restaurarPadrao();
                        await FirebaseAuth.instance.signOut();
                      }
                    },
                    color: NatusApp.offWhite,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'perfil',
                        child: Text('Meu perfil'),
                      ),
                      PopupMenuItem<String>(
                        value: 'foto',
                        child: Text('Alterar foto'),
                      ),
                      PopupMenuItem<String>(value: 'sair', child: Text('Sair')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
      if (menusDoUsuario.contains('Dashboard'))
        itemMenu(Icons.dashboard, 'Dashboard'),
      if (menusDoUsuario.contains('Agenda'))
        itemMenu(Icons.calendar_month_rounded, 'Agenda'),
      if (menusDoUsuario.contains('Mapa')) itemMenu(Icons.map, 'Mapa'),
      if (menusDoUsuario.contains('Cadastro'))
        itemMenu(Icons.person_add_alt_1, 'Cadastro'),
      if (menusDoUsuario.contains('Gestantes'))
        itemMenu(Icons.people_alt_rounded, 'Gestantes'),
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
      if (menusDoUsuario.contains('Centro de custo'))
        itemMenu(Icons.account_balance_wallet, 'Centro de custo'),
      if (menusDoUsuario.contains('Biblioteca'))
        itemMenu(Icons.menu_book, 'Biblioteca'),
      if (menusDoUsuario.contains('Prontuário'))
        itemMenu(Icons.assignment, 'Prontuário'),
      if (menusDoUsuario.contains('Documentos'))
        itemMenu(Icons.description, 'Documentos'),
      if (menusDoUsuario.contains('Exames')) itemMenu(Icons.biotech, 'Exames'),
      if (menusDoUsuario.contains('Cadastrar Profissional'))
        itemMenu(Icons.badge_rounded, 'Cadastrar Profissional'),
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NatusApp.menuTopo, NatusApp.menuMeio, NatusApp.menuBase],
          stops: [0.0, 0.56, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -10,
            offset: const Offset(10, 0),
          ),
        ],
      ),
      child: SafeArea(
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
            cardPerfilLateral(),
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
            final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
                    NatusTermos.rotuloMenu(titulo),
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

  void selecionarTelaPrincipal(String titulo) {
    if (titulo == 'Mais') {
      abrirMenuSecundarioMobile();
      return;
    }

    setState(() {
      telaAtual = titulo;
      gestanteSelecionada = null;
      if (titulo == 'Gestantes') {
        filtroDashboardPacientes = null;
      }
    });
  }

  bool exibirMenuInferiorCoracao() {
    return true;
  }

  List<String> menusPermitidosUsuarioMobile() {
    if (widget.tipoUsuario == 'admin') {
      return const [
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
        'Biblioteca',
        'Documentos',
        'Exames',
        'Usuários',
        'Cadastrar Profissional',
        'Configurações',
      ];
    }

    if (widget.tipoUsuario == 'gestante') {
      return const [
        'Área da gestante',
        'Agenda',
        'Biblioteca',
        'Exames',
        'Documentos',
        'Contrações',
      ];
    }

    return const [
      'Dashboard',
      'Agenda',
      'Mapa',
      'Gestantes',
      'Prontuário',
      'Calculadora de IG',
      'Contrações',
      'Biblioteca',
      'Exames',
    ];
  }

  String telaCentralMenuCoracao() {
    if (widget.tipoUsuario == 'gestante') {
      return 'Área da gestante';
    }
    return 'Dashboard';
  }

  List<ItemMenuInferior> itensMenuInferiorEsquerda() {
    if (widget.tipoUsuario == 'gestante') {
      return const [
        ItemMenuInferior('Agenda', Icons.event_note_rounded),
        ItemMenuInferior('Biblioteca', Icons.auto_stories_rounded),
      ];
    }

    return const [
      ItemMenuInferior('Agenda', Icons.event_note_rounded),
      ItemMenuInferior('Gestantes', Icons.people_alt_rounded),
    ];
  }

  List<ItemMenuInferior> itensMenuInferiorDireita() {
    if (widget.tipoUsuario == 'gestante') {
      return const [
        ItemMenuInferior('Exames', Icons.biotech_rounded),
        ItemMenuInferior('Mais', Icons.apps_rounded),
      ];
    }

    return const [
      ItemMenuInferior('Mapa', Icons.map_rounded),
      ItemMenuInferior('Exames', Icons.biotech_rounded),
    ];
  }

  List<String> menusOcultosMobile() {
    final menus = menusPermitidosUsuarioMobile();
    final atalhos = <String>{
      ...itensMenuInferiorEsquerda().map((item) => item.titulo),
      ...itensMenuInferiorDireita()
          .where((item) => item.titulo != 'Mais')
          .map((item) => item.titulo),
    };

    if (widget.tipoUsuario == 'gestante') {
      atalhos.add(telaCentralMenuCoracao());
    }

    return menus.where((item) => !atalhos.contains(item)).toList();
  }

  IconData iconeMenuPorTitulo(String titulo) {
    switch (titulo) {
      case 'Dashboard':
      case 'Dashboard SaaS':
      case 'Área da gestante':
        return Icons.favorite_rounded;
      case 'Agenda':
        return Icons.event_note_rounded;
      case 'Mapa':
        return Icons.map_rounded;
      case 'Cadastro':
        return Icons.person_add_alt_1_rounded;
      case 'Gestantes':
        return Icons.people_alt_rounded;
      case 'Prontuário':
        return Icons.note_alt_rounded;
      case 'Calculadora de IG':
        return Icons.calculate_rounded;
      case 'Contrações':
        return Icons.monitor_heart_rounded;
      case 'Financeiro':
      case 'Financeiro das assinaturas SaaS':
        return Icons.payments_rounded;
      case 'Planos da Natus':
        return Icons.workspace_premium_rounded;
      case 'Biblioteca':
        return Icons.auto_stories_rounded;
      case 'Documentos':
        return Icons.description_rounded;
      case 'Exames':
        return Icons.biotech_rounded;
      case 'Usuários':
      case 'Usuários/clientes SaaS':
        return Icons.group_rounded;
      case 'Cadastrar Profissional':
      case 'Criação de clínica/admin/enfermeira SaaS':
        return Icons.medical_services_rounded;
      case 'Configurações':
        return Icons.settings_rounded;
      case 'Clínicas cadastradas SaaS':
        return Icons.apartment_rounded;
      case 'Mensalidades atrasadas SaaS':
        return Icons.warning_amber_rounded;
      case 'Crescimento de usuários por período SaaS':
        return Icons.trending_up_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  Future<void> abrirMenuSecundarioMobile() async {
    final menus = menusOcultosMobile();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: NatusApp.rose.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.tipoUsuario == 'gestante'
                        ? 'Mais opções'
                        : 'Menu da Natus',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: NatusApp.vinho,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Acesse os módulos que ficaram fora dos atalhos rápidos.',
                    style: TextStyle(fontSize: 13, color: NatusApp.textoSuave),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: menus.map((titulo) {
                      final ativo = telaAtual == titulo;
                      return SizedBox(
                        width: 170,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.of(context).pop();
                              selecionarTelaPrincipal(titulo);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ativo
                                    ? NatusApp.marsala.withValues(alpha: 0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: ativo
                                      ? NatusApp.marsala.withValues(alpha: 0.20)
                                      : NatusApp.rose.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: NatusApp.rose.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      iconeMenuPorTitulo(titulo),
                                      color: NatusApp.vinho,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    NatusTermos.rotuloMenu(titulo),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: NatusApp.texto,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            abrirPerfilUsuarioMenu();
                          },
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Meu perfil'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NatusApp.vinho,
                            side: BorderSide(
                              color: NatusApp.rose.withValues(alpha: 0.55),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            NatusTema.restaurarPadrao();
                            await FirebaseAuth.instance.signOut();
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sair'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NatusApp.vinho,
                            foregroundColor: (NatusApp.escuro
                                ? NatusApp.fundo
                                : NatusApp.offWhite),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
            'Cadastre profissionais que fazem parte da equipe da clínica.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),

          const SizedBox(height: 24),

          bloco('Dados do profissional', [
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
              label: const Text('Salvar profissional'),
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
            'Cadastre profissionais da especialidade obstétrica da clínica.',
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

  Widget telaCadastrarProfissional() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cadastrar Profissional',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Escolha a especialidade e preencha o cadastro do profissional.',
            style: TextStyle(fontSize: 15, color: NatusApp.textoSuave),
          ),
          const SizedBox(height: 24),
          bloco('Tipo de profissional', [
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<String>(
                initialValue: tipoProfissionalCadastro,
                decoration: InputDecoration(
                  labelText: 'Especialidade',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'EO', child: Text('EO')),
                  DropdownMenuItem(value: 'Obstetra', child: Text('Obstetra')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    tipoProfissionalCadastro = value;
                  });
                },
              ),
            ),
          ]),
          bloco(
            tipoProfissionalCadastro == 'EO'
                ? 'Dados da EO'
                : 'Dados do Obstetra',
            tipoProfissionalCadastro == 'EO'
                ? [
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
                      label: const Text('Salvar EO'),
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
                  ]
                : [
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
                      label: const Text('Salvar Obstetra'),
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
                  ],
          ),
        ],
      ),
    );
  }

  Widget telaConteudo() {
    switch (telaAtual) {
      case 'Dashboard':
        return telaDashboard();

      case 'Agenda':
        return AgendaPage(
          gestantes: gestantes,
          enfermeiras: enfermeiras,
          tipoUsuario: widget.tipoUsuario,
          escopoTenant: widget.escopoTenant,
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

      case 'Cadastrar Profissional':
        return telaCadastrarProfissional();

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
      return telaSimples('Paciente não identificado para exibir exames.');
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
                : 'Visualize os exames enviados pelos pacientes.',
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
                    onPressed: () => selecionarArquivoExame(gestante),
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
                ? tenantFirestore
                      .consultaDoPaciente('exames', campoUid: 'uidGestante')
                      .snapshots()
                : tenantFirestore.consultaClinica('exames').snapshots(),

            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final arquivos = <ExameArquivo>[];

              for (final documento in snapshot.data!.docs) {
                try {
                  arquivos.add(
                    ExameArquivo.fromExame(
                      documento.id,
                      documento.data() as Map<String, dynamic>,
                    ),
                  );
                } on FormatException catch (erro) {
                  logErroSeguro(
                    'Exame ignorado por possuir identidade inconsistente.',
                    erro,
                  );
                }
              }

              for (final documento in documentos) {
                if (!ExameArquivo.documentoEhExame(documento)) continue;
                try {
                  arquivos.add(ExameArquivo.fromDocumento(documento));
                } on FormatException catch (erro) {
                  logErroSeguro(
                    'Documento de exame ignorado por possuir identidade inconsistente.',
                    erro,
                  );
                }
              }

              var exames = removerExamesDuplicados(arquivos);
              if (usuarioGestante) {
                exames = exames
                    .where((exame) => exame.pertenceA(gestante))
                    .toList();
              }

              if (exames.isEmpty) {
                return blocoFicha(
                  usuarioGestante ? 'Meus exames' : 'Exames dos pacientes',
                  [const Text('Nenhum exame encontrado.')],
                );
              }

              final examesAgrupados = agruparExamesPorPaciente(
                exames,
                gestantes,
              );

              return blocoFicha(
                usuarioGestante
                    ? 'Meus exames (${exames.length})'
                    : 'Exames dos pacientes (${exames.length})',
                [
                  ...examesAgrupados.map((grupo) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!usuarioGestante)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 10),
                            child: Text(
                              grupo.nomePaciente,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: NatusApp.vinho,
                              ),
                            ),
                          ),

                        ...grupo.exames.map((exame) {
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
                                        exame.nomeArquivo,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: NatusApp.vinho,
                                        ),
                                      ),

                                      if (exame.criadoEm.isNotEmpty)
                                        Text(
                                          'Enviado em: ${exame.dataExibicao}',
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
                                  onPressed: () => abrirArquivo(exame.url),
                                ),

                                if (usuarioEhAdmin())
                                  IconButton(
                                    tooltip: 'Excluir exame',
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await excluirExame(exame);
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

  Future<void> excluirExame(ExameArquivo exame) async {
    if (!usuarioEhAdmin()) {
      mostrarMensagem('Somente o administrador pode excluir exames.');
      return;
    }

    try {
      final colecao = exame.origem == OrigemExameArquivo.exames
          ? 'exames'
          : 'documentos';
      await firestore.collection(colecao).doc(exame.id).delete();

      if (exame.url.isNotEmpty) {
        final ref = storage.refFromURL(exame.url);
        try {
          await ref.delete();
        } catch (e) {
          logErroSeguro('Falha ao remover arquivo orfao do exame.', e);
        }
      }

      if (exame.origem == OrigemExameArquivo.documentos) {
        setState(() {
          documentos.removeWhere((documento) => documento['id'] == exame.id);
        });
      }

      mostrarMensagem('Exame excluído com sucesso.');
    } catch (e) {
      logErroSeguro('Erro ao excluir exame.', e);
      mostrarMensagem('Erro ao excluir exame.');
    }
  }

  Future<void> selecionarArquivoExame(Map<String, String> gestante) async {
    final idGestante = (gestante['id'] ?? '').trim();
    final nomeGestante = (gestante['nomeGestante'] ?? '').trim();
    final uidGestante = widget.escopoTenant.ehPaciente
        ? widget.escopoTenant.uidUsuario
        : (gestante['uidGestante'] ?? '').trim();

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: paciente não identificado.');
      return;
    }

    if (widget.escopoTenant.ehPaciente &&
        idGestante != widget.escopoTenant.pacienteId) {
      mostrarMensagem('Cadastro fora do contexto autenticado.');
      return;
    }

    final arquivo = await escolherArquivoClinico();
    if (arquivo == null) return;
    final nomeArquivo = arquivo.name;
    final upload = await uploadArquivo(
      arquivo,
      pasta: 'pacientes/$idGestante/exames',
      pacienteId: idGestante,
    );
    if (upload == null) return;

    try {
      await firestore
          .collection('exames')
          .add(
            tenantFirestore.prepararCriacao({
              'idGestante': idGestante,
              'pacienteId': idGestante,
              'uidGestante': uidGestante,
              'nomeGestante': nomeGestante,
              'nomeArquivo': nomeArquivo,
              'url': upload.url,
              'arquivoCaminho': upload.caminho,
              'criadoEm': DateTime.now().toIso8601String(),
            }),
          );

      mostrarMensagem('Exame enviado com sucesso!');
    } catch (e) {
      await removerUploadOrfao(upload, 'exame');
      logErroSeguro('Erro ao enviar exame.', e);
      mostrarMensagem('O exame não foi salvo e o envio foi desfeito.');
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

  int contarBebesPorAno(String ano, [List<Map<String, String>>? pacientes]) =>
      kpis.contarBebesPorAno(pacientes ?? gestantes, ano);

  Map<int, int> contarBebesPorMes(
    String ano, [
    List<Map<String, String>>? pacientes,
  ]) => kpis.contarBebesPorMes(pacientes ?? gestantes, ano);

  kpis.CrescimentoNascimentosKpis calcularCrescimentoNascimentos([
    List<Map<String, String>>? pacientes,
  ]) => kpis.calcularCrescimentoNascimentos(pacientes ?? gestantes);

  kpis.ObstetraMetricasCompletas metricasDoObstetraLogado([
    List<Map<String, String>>? pacientes,
  ]) => kpis.calcularMetricasObstetra(pacientes ?? gestantes, nomeEoLogada());

  List<kpis.ObstetraMetricasCompletas> metricasDeTodosObstetras([
    List<Map<String, String>>? pacientes,
  ]) => kpis.calcularMetricasTodosObstetras(pacientes ?? gestantes, obstetras);

  int contarBebesNoPeriodoSelecionado([List<Map<String, String>>? pacientes]) =>
      kpis.contarBebesNoPeriodoSelecionado(
        pacientes ?? gestantes,
        mesSelecionado,
        anoSelecionado,
      );

  int contarEncerradasOuHistoricoNoPeriodoDpp([
    List<Map<String, String>>? pacientes,
  ]) => kpis.contarEncerradasOuHistoricoNoPeriodoDpp(
    pacientes ?? gestantes,
    mesSelecionado,
    anoSelecionado,
  );

  Map<int, int> contarGestantesPorMes(String ano) =>
      kpis.contarGestantesPorMes(gestantes, ano);

  int contarGestantesPorStatus(String status) =>
      kpis.contarGestantesPorStatus(gestantes, status);

  bool gestanteEhDoPeriodoSelecionadoPelaDpp(Map<String, String> g) => kpis
      .gestanteEhDoPeriodoSelecionadoPelaDpp(g, mesSelecionado, anoSelecionado);

  int contarGestantesPorStatusNoPeriodoDpp(
    String status, [
    List<Map<String, String>>? pacientes,
  ]) => kpis.contarGestantesPorStatusNoPeriodoDpp(
    pacientes ?? gestantes,
    status,
    mesSelecionado,
    anoSelecionado,
  );

  int contarGestantesProximasDpp([List<Map<String, String>>? pacientes]) =>
      kpis.contarGestantesProximasDpp(pacientes ?? gestantes);

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

  bool lancamentoFinanceiroVisivelNoPeriodo(Map<String, String> parcela) =>
      fincalc.lancamentoFinanceiroVisivelNoPeriodo(
        parcela,
        mesSelecionado,
        anoSelecionado,
      );

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

  Map<String, int> contarAmamentacao([
    Iterable<Map<String, String>>? pacientes,
  ]) {
    Map<String, int> dados = {'AME': 0, 'Mista': 0, 'Fórmula': 0};

    for (var g in pacientes ?? gestantes) {
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

  List<MapEntry<String, int>> contarGestantesAtivasPorPlano() {
    final dados = <String, int>{};

    for (final g in gestantes) {
      if (!gestanteEstaAtiva(g)) continue;

      var plano = (g['plano'] ?? '').trim();
      if (plano.isEmpty) {
        plano = 'Plano não informado';
      }

      dados[plano] = (dados[plano] ?? 0) + 1;
    }

    final lista = dados.entries.toList();
    lista.sort((a, b) {
      final comparacaoQuantidade = b.value.compareTo(a.value);
      if (comparacaoQuantidade != 0) return comparacaoQuantidade;
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });
    return lista;
  }

  Map<String, int> contarViaNascimento([
    Iterable<Map<String, String>>? pacientes,
  ]) {
    final dados = {
      'Normal': 0,
      'Cesárea': 0,
      'Domiciliar': 0,
      'Não informado': 0,
    };

    for (var g in pacientes ?? gestantes) {
      final via = normalizarViaNascimentoDashboard(g['viaNascimento']);
      dados[via] = (dados[via] ?? 0) + 1;
    }

    return dados;
  }

  Map<String, int> contarRiscoGestacional([
    Iterable<Map<String, String>>? pacientes,
  ]) {
    final dados = {'Habitual': 0, 'Intermediário': 0, 'Alto Risco': 0};

    for (var g in gregras.gestantesAtivas((pacientes ?? gestantes).toList())) {
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

  Map<String, int> contarDiabetesGestacional([
    Iterable<Map<String, String>>? pacientes,
  ]) {
    final dados = {'Sim': 0, 'Não': 0};

    for (var g in gregras.gestantesAtivas((pacientes ?? gestantes).toList())) {
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
      filtroPlanoGestante = 'Todos';
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

  void abrirGestantesPorPlanoDashboard(String planoSelecionado) {
    setState(() {
      filtroDashboardPacientes = null;
      filtroStatusGestante = 'Ativas';
      filtroPlanoGestante = planoSelecionado;
      buscaGestantesController.clear();
      gestanteSelecionada = null;
      telaAtual = 'Gestantes';
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
        final isMobile =
            constraints.maxWidth < 620 || NatusBreakpoints.isPhone(context);

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
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
                                    'Seu bebê está do tamanho de ${artigoFruta(fruta)} $fruta.\n\n${mensagemGestacional(semanas)}',
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
    final layoutCompacto = NatusBreakpoints.usarLayoutCompacto(context);
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
                'Cadastro de pacientes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: NatusApp.vinho,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preencha as informações do paciente para iniciar o acompanhamento',
                style: TextStyle(fontSize: 13, color: NatusApp.textoSuave),
              ),
              const SizedBox(height: 20),
            ],
          ),
          const SizedBox(height: 20),

          bloco('Paciente', [
            dropdownGrande(
              'Tipo / especialidade do acompanhamento',
              especialidadePaciente,
              NatusEspecialidades.opcoes,
              (valor) {
                setState(() {
                  especialidadePaciente = valor;
                });
              },
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                campo(nomeGestante, 'Nome do paciente'),
                campo(cpfGestante, 'CPF', mask: cpfMask),
                campo(telefoneGestante, 'Telefone', mask: telefoneMask),
                campo(emailGestante, 'E-mail'),
              ],
            ),

            Wrap(
              spacing: 12,
              runSpacing: 12,
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
                      final cepConsultado = value.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (cepConsultado.length == 8) {
                        final resultado = await buscarEnderecoPorCep(value);
                        final cepAtual = cepGestante.text.replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        );
                        if (cepAtual != cepConsultado) return;

                        if (resultado != null) {
                          enderecoGestante.text = resultado.logradouro;
                          bairroGestante.text = resultado.bairro;
                          cidadeGestante.text = resultado.cidade;
                          estadoGestante.text = resultado.estado;
                        }
                        mostrarResultadoConsultaCep(resultado);
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: layoutCompacto ? 230 : 480,
                  child: campoFull(enderecoGestante, 'Endereço'),
                ),
              ],
            ),

            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 160,
                  child: campoFull(numeroGestante, 'Número'),
                ),
                SizedBox(
                  width: 230,
                  child: campoFull(complementoGestante, 'Apto / Bloco'),
                ),
                SizedBox(
                  width: 230,
                  child: campoFull(bairroGestante, 'Bairro'),
                ),
                SizedBox(
                  width: 230,
                  child: campoFull(cidadeGestante, 'Cidade'),
                ),
                SizedBox(width: 70, child: campoFull(estadoGestante, 'UF')),
              ],
            ),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                dropdownGrande(
                  'Unidade / Hospital',
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
                campo(obstetraGestante, 'Profissional responsável'),
                dropdownGrande(
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
              ],
            ),
          ]),

          bloco(tituloContatoCadastroPaciente, [
            campo(nomePai, 'Nome'),
            campo(cpfPai, 'CPF', mask: cpfMask),
            campo(telefonePai, 'Telefone', mask: telefoneMask),
            campo(emailPai, 'E-mail'),
          ]),

          if (especialidadePacienteEhObstetricia)
            bloco('Acompanhamento obstétrico', [
              campo(nomeBebe, 'Nome do bebê'),
              dropdown(
                'Sexo do bebê',
                sexo,
                ['Masculino', 'Feminino', 'Não informado'],
                (v) {
                  setState(() => sexo = v);
                },
              ),
              campoDpp(),
              campoInfo(
                'IG atual',
                calcularIdadeGestacional(dppController.text),
              ),
            ]),

          bloco('Valores', [
            seletorPlanoGestante(),
            campoInfo('Valor do plano', formatarMoeda(valorPlano)),
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
            onPressed: salvandoPaciente ? null : salvarGestante,
            icon: salvandoPaciente
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              salvandoPaciente ? 'Salvando paciente...' : 'Salvar paciente',
            ),
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
    final totalAtivas = gestantes.where(gestanteEstaAtiva).length;
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
    final opcoesPlanoGestante =
        <String>{
          'Todos',
          ...gestantes
              .map((g) => (g['plano'] ?? '').trim())
              .where((plano) => plano.isNotEmpty),
        }.toList()..sort((a, b) {
          if (a == 'Todos') return -1;
          if (b == 'Todos') return 1;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pacientes',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: NatusApp.vinho,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'Acompanhamento dos pacientes da sua clínica.',
            style: TextStyle(
              fontSize: 13,
              color: NatusApp.textoSuave,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          NatusCardsResumoLayout(
            children: [
              cardResumo(
                'Ativas',
                totalAtivas.toString(),
                Icons.people_alt_rounded,
                cor: NatusApp.vinho,
              ),
              cardResumo(
                'Pós-parto',
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

          DropdownButtonFormField<String>(
            initialValue: opcoesPlanoGestante.contains(filtroPlanoGestante)
                ? filtroPlanoGestante
                : 'Todos',
            decoration: InputDecoration(
              labelText: 'Filtrar por plano',
              prefixIcon: const Icon(Icons.filter_alt_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: NatusApp.offWhite,
            ),
            items: opcoesPlanoGestante
                .map(
                  (plano) => DropdownMenuItem<String>(
                    value: plano,
                    child: Text(plano),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                filtroPlanoGestante = value ?? 'Todos';
              });
            },
          ),

          const SizedBox(height: 16),

          TextField(
            controller: buscaGestantesController,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Buscar paciente',
              hintText:
                  'Nome, telefone, e-mail, cidade, unidade ou profissional',
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

  String rotuloTipoBiblioteca(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'video':
        return 'Vídeos';
      case 'link':
        return 'Links';
      case 'pdf':
        return 'PDFs';
      default:
        return tipo.isEmpty ? 'Conteúdos' : tipo;
    }
  }

  IconData iconeTipoBiblioteca(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'link':
        return Icons.link_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  Widget chipBibliotecaFiltro({
    required String label,
    required IconData icon,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selecionado
              ? NatusApp.vinho
              : Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionado
                ? NatusApp.vinho
                : NatusApp.rose.withValues(alpha: 0.45),
          ),
          boxShadow: selecionado
              ? [
                  BoxShadow(
                    color: NatusApp.vinho.withValues(alpha: 0.17),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selecionado ? NatusApp.offWhite : NatusApp.vinho,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selecionado ? NatusApp.offWhite : NatusApp.vinho,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget chipBibliotecaCategoria({
    required String label,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: selecionado ? NatusApp.vinho : NatusApp.offWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selecionado
                ? NatusApp.vinho
                : NatusApp.rose.withValues(alpha: 0.45),
          ),
          boxShadow: selecionado
              ? [
                  BoxShadow(
                    color: NatusApp.vinho.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? NatusApp.offWhite : NatusApp.vinho,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget telaBiblioteca() {
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);
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

    final termoBusca = buscaBibliotecaController.text.trim().toLowerCase();
    final materiaisFiltrados = biblioteca.where((item) {
      final categoria = (item['categoria'] ?? 'Outros').trim();
      final tipo = (item['tipo'] ?? 'pdf').trim().toLowerCase();
      final textoBusca = [
        item['titulo'] ?? '',
        item['descricao'] ?? '',
        categoria,
        tipo,
      ].join(' ').toLowerCase();

      final passaBusca = termoBusca.isEmpty || textoBusca.contains(termoBusca);

      return passaBusca;
    }).toList();
    final Map<String, List<Map<String, String>>> categorias = {};

    for (var item in materiaisFiltrados) {
      final categoria = item['categoria'] ?? 'Outros';

      if (!categorias.containsKey(categoria)) {
        categorias[categoria] = [];
      }

      categorias[categoria]!.add(item);
    }

    final materiaisParaDestaque = materiaisFiltrados.isEmpty
        ? biblioteca
        : materiaisFiltrados;
    final indiceDestaqueSeguro = materiaisParaDestaque.isEmpty
        ? 0
        : indiceDestaqueBiblioteca % materiaisParaDestaque.length;
    final materialDestaque = materiaisParaDestaque[indiceDestaqueSeguro];

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

            const SizedBox(height: 24),

            Divider(color: NatusApp.rose.withValues(alpha: 0.35), height: 1),

            const SizedBox(height: 22),

            TextField(
              controller: buscaBibliotecaController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Buscar na biblioteca',
                hintText: 'Título, categoria, descrição ou tipo de material',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: buscaBibliotecaController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() {
                            buscaBibliotecaController.clear();
                          });
                        },
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.72),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: NatusApp.rose.withValues(alpha: 0.35),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: NatusApp.rose.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            if (materiaisFiltrados.isEmpty) ...[
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
                      backgroundColor: const Color(0xFFFFEFEA),
                      child: Icon(
                        Icons.search_off_rounded,
                        color: NatusApp.vinho,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Nenhum material encontrado com esses filtros. Mostrei um destaque da biblioteca para você continuar navegando.',
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
              const SizedBox(height: 18),
            ],

            // MATERIAL RECOMENDADO
            if (termoBusca == '__natus_bloco_antigo_oculto__')
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
                            materiaisFiltrados.isEmpty
                                ? 'Destaque da biblioteca'
                                : '${materiaisFiltrados.length} material${materiaisFiltrados.length == 1 ? '' : 'is'} encontrado${materiaisFiltrados.length == 1 ? '' : 's'}',
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
                                onEditar: usuarioEhAdmin()
                                    ? () => abrirCadastroMaterialBiblioteca(
                                        materialExistente: materialDestaque,
                                      )
                                    : null,
                                onExcluir: usuarioEhAdmin()
                                    ? () => confirmarExcluirItemBiblioteca(
                                        materialDestaque,
                                      )
                                    : null,
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cardBibliotecaNetflix(
                                materialDestaque,
                                largura: 280,
                                onEditar: usuarioEhAdmin()
                                    ? () => abrirCadastroMaterialBiblioteca(
                                        materialExistente: materialDestaque,
                                      )
                                    : null,
                                onExcluir: usuarioEhAdmin()
                                    ? () => confirmarExcluirItemBiblioteca(
                                        materialDestaque,
                                      )
                                    : null,
                              ),

                              const SizedBox(width: 22),

                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              final url =
                                                  materialDestaque['url'] ?? '';
                                              if (url.isNotEmpty) {
                                                abrirArquivo(url);
                                              } else {
                                                mostrarMensagem(
                                                  'Material ainda não disponível.',
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.auto_stories_rounded,
                                            ),
                                            label: const Text('Abrir destaque'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: NatusApp.vinho,
                                              foregroundColor:
                                                  NatusApp.offWhite,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed:
                                                materiaisParaDestaque.length <=
                                                    1
                                                ? null
                                                : () {
                                                    setState(() {
                                                      indiceDestaqueBiblioteca =
                                                          indiceDestaqueSeguro +
                                                          1;
                                                    });
                                                  },
                                            icon: const Icon(
                                              Icons.skip_next_rounded,
                                            ),
                                            label: const Text('Próximo'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: NatusApp.vinho,
                                              side: BorderSide(
                                                color: NatusApp.rose.withValues(
                                                  alpha: 0.55,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ],
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

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: materiaisFiltrados.map((material) {
                return cardBibliotecaNetflix(
                  material,
                  largura: isMobile ? double.infinity : 238,
                  onEditar: usuarioEhAdmin()
                      ? () => abrirCadastroMaterialBiblioteca(
                          materialExistente: material,
                        )
                      : null,
                  onExcluir: usuarioEhAdmin()
                      ? () => confirmarExcluirItemBiblioteca(material)
                      : null,
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            if (termoBusca == '__natus_lista_antiga_oculta__')
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
                            onEditar: usuarioEhAdmin()
                                ? () => abrirCadastroMaterialBiblioteca(
                                    materialExistente: material,
                                  )
                                : null,
                            onExcluir: usuarioEhAdmin()
                                ? () => confirmarExcluirItemBiblioteca(material)
                                : null,
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

            if (podeGerenciarBiblioteca) ...[
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: botaoAdicionarMaterialBiblioteca(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget cabecalhoBiblioteca(bool podeGerenciarBiblioteca) {
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
      ],
    );
  }

  Widget botaoAdicionarMaterialBiblioteca() {
    return Tooltip(
      message: 'Adicionar material',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: abrirCadastroMaterialBiblioteca,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: NatusApp.vinho,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: NatusApp.vinhoProfundo.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: NatusApp.offWhite, size: 24),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirDialogoUpload(UploadProgressController controller) async {
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Upload em andamento',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return UploadProgressDialog(controller: controller);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  Future<void> _fecharDialogoUpload() async {
    if (!mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<String?> uploadArquivoBiblioteca(
    PlatformFile arquivo, {
    String pasta = 'biblioteca',
    UploadProgressController? progressController,
    String tituloUpload = 'Enviando material',
    String mensagemPreparando = 'Preparando arquivo para envio...',
  }) async {
    final controller = progressController ?? UploadProgressController();
    final gerenciarDialogo = progressController == null;
    var dialogoAberto = false;

    try {
      final bytes = arquivo.bytes;

      if (bytes == null) {
        mostrarMensagem('Não foi possível ler o arquivo selecionado.');
        return null;
      }

      if (gerenciarDialogo) {
        unawaited(_abrirDialogoUpload(controller));
        await Future<void>.delayed(const Duration(milliseconds: 120));
        dialogoAberto = true;
      }

      controller.preparing(titulo: tituloUpload, mensagem: mensagemPreparando);

      final nomeSeguro = arquivo.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final nomeFinal = '${DateTime.now().millisecondsSinceEpoch}_$nomeSeguro';
      final ref = storage.ref().child(
        tenantFirestore.caminhoStorage('$pasta/$nomeFinal'),
      );

      final task = ref.putData(
        bytes,
        metadadosUpload(arquivo, permitirVideo: true),
      );

      final subscription = task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;
        final progress = total <= 0 ? 0.05 : transferred / total;

        controller.uploading(
          progress,
          titulo: tituloUpload,
          mensagem: 'Enviando ${arquivo.name} (${(progress * 100).round()}%)',
        );
      });

      await task;
      await subscription.cancel();

      final url = await ref.getDownloadURL();

      controller.success(
        titulo: 'Upload concluído',
        mensagem: '${arquivo.name} foi enviado com sucesso.',
      );

      if (gerenciarDialogo) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }

      return url;
    } catch (e) {
      logErroSeguro('Erro ao enviar material da biblioteca.', e);
      controller.error(
        titulo: 'Erro no upload',
        mensagem: 'Não foi possível concluir o envio de ${arquivo.name}.',
      );

      if (gerenciarDialogo) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }

      mostrarMensagem('Erro ao enviar material da biblioteca.');
      return null;
    } finally {
      if (gerenciarDialogo && dialogoAberto) {
        await _fecharDialogoUpload();
      }
    }
  }

  Future<void> abrirCadastroMaterialBiblioteca({
    Map<String, String>? materialExistente,
  }) async {
    if (!usuarioEhAdmin()) return;

    final bool editando = materialExistente != null;
    final tituloController = TextEditingController(
      text: materialExistente?['titulo'] ?? '',
    );
    final categoriaController = TextEditingController(text: 'Gestação');
    final descricaoController = TextEditingController(
      text: materialExistente?['descricao'] ?? '',
    );
    final urlController = TextEditingController(
      text: materialExistente?['url'] ?? '',
    );
    final capaUrlController = TextEditingController(
      text: materialExistente?['capaUrl'] ?? '',
    );
    var tipoSelecionado = materialExistente?['tipo'] ?? 'pdf';
    PlatformFile? arquivoSelecionadoBiblioteca;
    PlatformFile? capaSelecionadaBiblioteca;
    var salvandoMaterialBiblioteca = false;

    categoriaController.text =
        materialExistente?['categoria'] ?? categoriaController.text;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text(
                  editando ? 'Editar material' : 'Adicionar material',
                ),
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
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            final resultado = await FilePicker.platform
                                .pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'pdf',
                                    'jpg',
                                    'jpeg',
                                    'png',
                                    'webp',
                                    'heic',
                                    'heif',
                                    'mp4',
                                  ],
                                  withData: true,
                                );

                            if (resultado == null) return;

                            setStateDialog(() {
                              arquivoSelecionadoBiblioteca =
                                  resultado.files.first;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7F3),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: NatusApp.rose.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: NatusApp.offWhite,
                                  child: Icon(
                                    Icons.cloud_upload_rounded,
                                    color: NatusApp.vinho,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        arquivoSelecionadoBiblioteca == null
                                            ? 'Selecionar arquivo do material'
                                            : arquivoSelecionadoBiblioteca!
                                                  .name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: NatusApp.vinho,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'PDF, JPG, PNG, WebP, HEIC/HEIF ou '
                                        'vídeo MP4.',
                                        style: TextStyle(
                                          color: NatusApp.textoSuave,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            final resultado = await FilePicker.platform
                                .pickFiles(
                                  withData: true,
                                  type: FileType.image,
                                );

                            if (resultado == null) return;

                            setStateDialog(() {
                              capaSelecionadaBiblioteca = resultado.files.first;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7F3),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: NatusApp.rose.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: NatusApp.offWhite,
                                  child: Icon(
                                    Icons.image_rounded,
                                    color: NatusApp.vinho,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        capaSelecionadaBiblioteca == null
                                            ? 'Selecionar arquivo da capa'
                                            : capaSelecionadaBiblioteca!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: NatusApp.vinho,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Imagem opcional para a capa do material.',
                                        style: TextStyle(
                                          color: NatusApp.textoSuave,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        campoFull(
                          urlController,
                          'Link opcional (vídeo da internet ou material externo)',
                        ),
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
                    onPressed: salvandoMaterialBiblioteca
                        ? null
                        : () async {
                            final titulo = tituloController.text.trim();
                            final url = urlController.text.trim();

                            if (titulo.isEmpty) {
                              mostrarMensagem('Informe o título do material.');
                              return;
                            }

                            if (!editando &&
                                url.isEmpty &&
                                arquivoSelecionadoBiblioteca == null) {
                              mostrarMensagem(
                                'Selecione um arquivo ou informe um link externo.',
                              );
                              return;
                            }

                            setStateDialog(
                              () => salvandoMaterialBiblioteca = true,
                            );

                            final uploadController = UploadProgressController(
                              titulo: 'Enviando material',
                              mensagem: 'Preparando arquivos da biblioteca...',
                            );
                            final bool temUploadVisual =
                                arquivoSelecionadoBiblioteca != null ||
                                capaSelecionadaBiblioteca != null;

                            if (temUploadVisual) {
                              unawaited(_abrirDialogoUpload(uploadController));
                              await Future<void>.delayed(
                                const Duration(milliseconds: 120),
                              );
                            }

                            final urlFinal =
                                arquivoSelecionadoBiblioteca != null
                                ? await uploadArquivoBiblioteca(
                                    arquivoSelecionadoBiblioteca!,
                                    progressController: uploadController,
                                    tituloUpload: 'Enviando material',
                                    mensagemPreparando:
                                        'Preparando material da biblioteca...',
                                  )
                                : (url.isNotEmpty
                                      ? url
                                      : materialExistente?['url'] ?? '');

                            final String capaFinal =
                                capaUrlController.text.trim().isNotEmpty
                                ? capaUrlController.text.trim()
                                : capaSelecionadaBiblioteca != null
                                ? await uploadArquivoBiblioteca(
                                        capaSelecionadaBiblioteca!,
                                        pasta: 'biblioteca/capas',
                                        progressController: uploadController,
                                        tituloUpload: 'Enviando capa',
                                        mensagemPreparando:
                                            'Preparando imagem de capa...',
                                      ) ??
                                      ''
                                : '';

                            if (urlFinal == null || urlFinal.isEmpty) {
                              setStateDialog(
                                () => salvandoMaterialBiblioteca = false,
                              );
                              if (temUploadVisual) {
                                await _fecharDialogoUpload();
                              }
                              return;
                            }

                            if (capaSelecionadaBiblioteca != null &&
                                capaFinal.isEmpty) {
                              setStateDialog(
                                () => salvandoMaterialBiblioteca = false,
                              );
                              if (temUploadVisual) {
                                await _fecharDialogoUpload();
                              }
                              return;
                            }

                            if (temUploadVisual) {
                              uploadController.success(
                                titulo: 'Material salvo',
                                mensagem:
                                    'Os arquivos da biblioteca foram enviados com sucesso.',
                              );
                              await Future<void>.delayed(
                                const Duration(milliseconds: 700),
                              );
                              await _fecharDialogoUpload();
                            }

                            final Map<String, String> material = {
                              if (editando) 'id': materialExistente['id'] ?? '',
                              'titulo': titulo,
                              'categoria':
                                  categoriaController.text.trim().isEmpty
                                  ? 'Outros'
                                  : categoriaController.text.trim(),
                              'tipo': tipoSelecionado,
                              'url': urlFinal,
                              'arquivoNome':
                                  arquivoSelecionadoBiblioteca?.name ??
                                  materialExistente?['arquivoNome'] ??
                                  '',
                              'capaUrl': capaFinal,
                              'descricao': descricaoController.text.trim(),
                              'ativo': 'true',
                              'ordem':
                                  materialExistente?['ordem'] ??
                                  (biblioteca.length + 1).toString(),
                              'criadoEm':
                                  materialExistente?['criadoEm'] ??
                                  DateTime.now().toIso8601String(),
                            };

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            if (editando) {
                              await atualizarItemBibliotecaFirestore(material);
                            } else {
                              await salvarItemBibliotecaFirestore(material);
                            }
                          },
                    icon: salvandoMaterialBiblioteca
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      salvandoMaterialBiblioteca
                          ? 'Enviando...'
                          : editando
                          ? 'Salvar alterações'
                          : 'Salvar',
                    ),
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
    VoidCallback? onEditar,
    VoidCallback? onExcluir,
  }) {
    final tipo = material['tipo'] ?? 'pdf';
    final titulo = material['titulo'] ?? 'Material';
    final descricao = material['descricao'] ?? '';
    final url = material['url'] ?? '';
    final capaUrl = material['capaUrl'] ?? '';
    final capaUri = uriMidiaNatusSegura(capaUrl);

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
                    if (capaUri != null)
                      Image.network(
                        capaUri.toString(),
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

                    if (onEditar != null || onExcluir != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: NatusApp.offWhite.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: NatusApp.vinhoProfundo.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: PopupMenuButton<String>(
                              tooltip: 'Ações do material',
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: NatusApp.vinho,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onSelected: (value) {
                                if (value == 'editar') {
                                  onEditar?.call();
                                } else if (value == 'excluir') {
                                  onExcluir?.call();
                                }
                              },
                              itemBuilder: (context) {
                                return [
                                  if (onEditar != null)
                                    const PopupMenuItem<String>(
                                      value: 'editar',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.edit_rounded),
                                        title: Text('Editar'),
                                      ),
                                    ),
                                  if (onExcluir != null)
                                    const PopupMenuItem<String>(
                                      value: 'excluir',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.red,
                                        ),
                                        title: Text('Excluir'),
                                      ),
                                    ),
                                ];
                              },
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
            dropdownGrande('Paciente', atendimentoGestante, nomesGestantes, (
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
      mostrarMensagem('Selecione um paciente antes de salvar.');
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
        mostrarMensagem('ID do paciente não encontrado.');
        return;
      }

      final doc = await firestore.collection('gestantes').doc(idGestante).get();

      if (!doc.exists) {
        mostrarMensagem('Paciente não encontrado no Firebase.');
        return;
      }

      final dados = doc.data() ?? {};

      if (!widget.escopoTenant.pertenceAoTenant(dados)) {
        mostrarMensagem('Cadastro fora da clínica autenticada.');
        return;
      }

      final telefone = dados['telefoneGestante']?.toString() ?? '';
      final nome = dados['nomeGestante']?.toString() ?? '';
      final email = dados['emailGestante']?.toString() ?? '';

      if (email.trim().isEmpty) {
        mostrarMensagem('E-mail do paciente não informado.');
        return;
      }

      if (FirebaseAuth.instance.currentUser == null) {
        mostrarMensagem('Usuário não autenticado. Faça login novamente.');
        return;
      }

      mostrarMensagem('Solicitando redefinição de senha...');

      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('solicitarRedefinicaoSenhaPaciente');
      final resposta = await callable.call(<String, dynamic>{
        'pacienteId': idGestante,
      });
      final dadosResposta = Map<String, dynamic>.from(resposta.data as Map);

      if (dadosResposta['sucesso'] != true) {
        mostrarMensagem(
          dadosResposta['mensagem']?.toString() ??
              'Não foi possível solicitar a redefinição de senha.',
        );
        return;
      }

      final emailValidado =
          dadosResposta['emailPaciente']?.toString().trim().toLowerCase() ?? '';
      if (emailValidado.isEmpty) {
        mostrarMensagem('O cadastro não possui um e-mail válido.');
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailValidado);

      final nomeValidado =
          dadosResposta['nomePaciente']?.toString().trim() ?? nome;
      final telefoneValidado =
          dadosResposta['telefonePaciente']?.toString().trim() ?? telefone;

      if (telefoneValidado.isEmpty) {
        mostrarMensagem('E-mail de redefinição enviado com sucesso.');
        return;
      }

      final url = uriWhatsAppRedefinicaoSenhaPaciente(
        telefone: telefoneValidado,
        nome: nomeValidado,
        email: emailValidado,
      );

      if (!uriExternaPermitida(url, hostsHttpsPermitidos: const {'wa.me'})) {
        mostrarMensagem('Não foi possível abrir o canal de atendimento.');
        return;
      }

      await launchUrl(url, mode: LaunchMode.externalApplication);
    } on FirebaseFunctionsException catch (e) {
      mostrarMensagem(
        mensagemErroFunctionsSeguro(
          e,
          fallback: 'Não foi possível solicitar a redefinição de senha.',
        ),
      );
    } on FirebaseAuthException catch (e) {
      logErroSeguro('Erro ao enviar redefinicao de senha.', e.code);
      mostrarMensagem(mensagemErroEnvioAcessoParaEquipe(e.code));
    } catch (e) {
      logErroSeguro('Erro ao solicitar redefinicao de senha.', e);
      mostrarMensagem('Erro ao solicitar redefinição de senha.');
    }
  }

  Widget telaFichaGestanteTempoReal(Map<String, String> g) {
    final idGestante = g['id'] ?? '';

    if (idGestante.isEmpty) {
      return telaCentralGestanteClinica(g);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('gestantes').doc(idGestante).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Paciente não encontrado.'));
        }

        final dados = snapshot.data!.data() as Map<String, dynamic>;
        if (!widget.escopoTenant.pertenceAoTenant(dados) ||
            (widget.escopoTenant.ehPaciente &&
                snapshot.data!.id != widget.escopoTenant.pacienteId)) {
          return const Center(child: Text('Acesso ao cadastro bloqueado.'));
        }

        final gestanteAtualizada = dados.map((chave, valor) {
          return MapEntry(chave, valor.toString());
        });

        gestanteAtualizada['id'] = snapshot.data!.id;

        return telaCentralGestanteClinica(gestanteAtualizada);
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
          Text(g['nomeGestante'] ?? 'Prontuário do paciente'),

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

          if (usuarioEhAdmin() || widget.escopoTenant.ehPaciente)
            ElevatedButton.icon(
              onPressed: () {
                enviarAcessoGestante(g);
              },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reenviar acesso do paciente'),
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
                  : (g['statusGestante'] ?? 'Gestante') == 'Puérpera' ||
                        (g['statusGestante'] ?? 'Gestante') == 'Ativa'
                  ? 'Encerrar atendimento'
                  : 'Atendimento encerrado',
            ),
          ),

          const SizedBox(height: 24),

          blocoFicha('Paciente', [
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

          blocoFicha(
            'Responsável / contato',
            [
              linhaInfo('Nome do responsável', g['nomePai']),
              linhaInfo('CPF do responsável', g['cpfPai']),
              linhaInfo('Telefone do responsável', g['telefonePai']),
              linhaInfo('E-mail do responsável', g['emailPai']),
            ],
            onEditar: () => abrirPopupEditarSecaoGestante(g, 'Pai'),
          ),

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

          blocoFicha('Atendimentos do paciente', [
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

          blocoFicha('Documentos do paciente', [
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

  Widget telaCentralGestanteClinica(Map<String, String> g) {
    final igAtual = calcularIdadeGestacional(g['dpp'] ?? '');
    final especialidade = especialidadeDoPaciente(g);
    final ehObstetricia = pacienteTemModuloObstetrico(g);
    final podeVerFinanceiroGestante = usuarioEhAdmin();
    final nomeGestante = (g['nomeGestante'] ?? '').trim();
    final diasRestantesDpp = diasParaDpp(g['dpp'] ?? '');
    final atendimentosDaGestante = atendimentosDaGestanteCentral(g);
    final contracoesDaGestante = contracoesDaGestanteCentral(g);
    final contracoesHoje = contracoesDaGestante.where((contracao) {
      final data = dataReferenciaContracao(contracao);
      return data != null && mesmaData(data, DateTime.now());
    }).toList();
    final documentosDaGestante = documentos.where((d) {
      return (d['gestante'] ?? '').trim() == nomeGestante;
    }).toList();
    final documentosGeraisDaGestante = documentosDaGestante.where((d) {
      final tipo = (d['tipo'] ?? '').trim();
      return tipo.isNotEmpty && tipo != 'Exame';
    }).toList();
    final contratosDaGestante = documentosDaGestante.where((d) {
      return (d['tipo'] ?? '').trim() == 'Contrato';
    }).toList();
    final comprovantesDaGestante = documentosDaGestante.where((d) {
      return (d['tipo'] ?? '').trim() == 'Comprovante';
    }).toList();
    final parcelasDaGestante = parcelasDaGestanteFicha(g);
    final totalPendenciasFinanceiras = parcelasDaGestante.where((parcela) {
      return (parcela['status'] ?? '') != 'Pago';
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
              ElevatedButton.icon(
                onPressed: () => abrirPopupEditarGestante(g),
                icon: const Icon(Icons.edit),
                label: const Text('Editar cadastro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NatusApp.offWhite,
                  foregroundColor: NatusApp.vinho,
                ),
              ),
              if (usuarioEhAdmin() || widget.escopoTenant.ehPaciente)
                ElevatedButton.icon(
                  onPressed: () => enviarAcessoGestante(g),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reenviar acesso'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NatusApp.rose,
                    foregroundColor: NatusApp.vinho,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () => atualizarStatusGestante(g),
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  (g['statusGestante'] ?? 'Gestante') == 'Gestante'
                      ? 'Transformar em puérpera'
                      : (g['statusGestante'] ?? 'Gestante') == 'Puérpera' ||
                            (g['statusGestante'] ?? 'Gestante') == 'Ativa'
                      ? 'Encerrar atendimento'
                      : 'Atendimento encerrado',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: NatusApp.vinhoProfundo.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: NatusApp.rose.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 46,
                    color: NatusApp.vinho,
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeGestante.isEmpty
                            ? 'Central do paciente'
                            : nomeGestante,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: NatusApp.vinho,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          badgeStatus(g['statusGestante'] ?? 'Gestante'),
                          centralClinicaTag(
                            Icons.medical_services_rounded,
                            especialidade,
                          ),
                          if (ehObstetricia)
                            centralClinicaTag(
                              Icons.favorite_rounded,
                              'IG $igAtual',
                            ),
                          if (ehObstetricia &&
                              (g['dpp'] ?? '').trim().isNotEmpty)
                            centralClinicaTag(
                              Icons.event_rounded,
                              'DPP ${g['dpp']}',
                            ),
                          if ((g['plano'] ?? '').trim().isNotEmpty)
                            centralClinicaTag(
                              Icons.workspace_premium_rounded,
                              g['plano'] ?? '',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Painel rápido para acompanhamento clínico, exames, atendimentos e evolução do paciente.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: NatusApp.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      cardResumoCentralClinica(
                        titulo: 'Hospital',
                        valor: (g['hospitalGestante'] ?? '').trim().isEmpty
                            ? 'Não informado'
                            : g['hospitalGestante'] ?? '',
                        icone: Icons.local_hospital_rounded,
                        cor: NatusApp.vinho,
                      ),
                      cardResumoCentralClinica(
                        titulo: 'Obstetra',
                        valor: (g['obstetraGestante'] ?? '').trim().isEmpty
                            ? 'Não informado'
                            : g['obstetraGestante'] ?? '',
                        icone: Icons.medical_services_rounded,
                        cor: NatusApp.olivaSeco,
                      ),
                      cardResumoCentralClinica(
                        titulo: 'Telefone',
                        valor: (g['telefoneGestante'] ?? '').trim().isEmpty
                            ? 'Não informado'
                            : g['telefoneGestante'] ?? '',
                        icone: Icons.phone_rounded,
                        cor: NatusApp.marsalaSuave,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (ehObstetricia)
                chipAlertaCentralClinica(
                  icone: Icons.timelapse_rounded,
                  titulo: 'Contrações hoje',
                  subtitulo: contracoesHoje.isEmpty
                      ? 'Sem registros no dia'
                      : '${contracoesHoje.length} registro(s)',
                  cor: contracoesHoje.isEmpty
                      ? NatusApp.textoSuave
                      : NatusApp.vinho,
                ),
              chipAlertaCentralClinica(
                icone: Icons.science_rounded,
                titulo: 'Exames',
                subtitulo: 'Acompanhe os envios recentes',
                cor: NatusApp.marsalaSuave,
              ),
              if (ehObstetricia)
                chipAlertaCentralClinica(
                  icone: Icons.event_available_rounded,
                  titulo: 'DPP',
                  subtitulo: diasRestantesDpp < 0
                      ? 'DPP já passou'
                      : diasRestantesDpp == 0
                      ? 'DPP é hoje'
                      : 'Faltam $diasRestantesDpp dia(s)',
                  cor: diasRestantesDpp <= 14
                      ? Colors.orange
                      : NatusApp.olivaSeco,
                ),
              if (podeVerFinanceiroGestante)
                chipAlertaCentralClinica(
                  icone: Icons.payments_rounded,
                  titulo: 'Financeiro',
                  subtitulo: totalPendenciasFinanceiras == 0
                      ? 'Sem pendências'
                      : '$totalPendenciasFinanceiras pendência(s)',
                  cor: totalPendenciasFinanceiras == 0
                      ? Colors.green
                      : Colors.red,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (ehObstetricia)
                secaoCentralClinica(
                  titulo: 'Últimas contrações',
                  largura: 350,
                  child: contracoesDaGestante.isEmpty
                      ? vazioCentralClinica(
                          'Nenhuma contração registrada para este paciente.',
                        )
                      : Column(
                          children: contracoesDaGestante.take(3).map((
                            contracao,
                          ) {
                            return itemResumoCentralClinica(
                              titulo:
                                  contracao['inicio'] ??
                                  contracao['dataRegistro'] ??
                                  'Contração registrada',
                              subtitulo:
                                  'Duração: ${contracao['duracao'] ?? 'Não informada'}\n'
                                  'Intervalo: ${contracao['intervalo'] ?? 'Não informado'}',
                              icone: Icons.favorite_border_rounded,
                              cor: NatusApp.vinho,
                            );
                          }).toList(),
                        ),
                ),
              secaoCentralClinica(
                titulo: 'Exames recentes',
                largura: 350,
                child: examesRecentesCentralClinica(g),
              ),
              secaoCentralClinica(
                titulo: 'Atendimentos recentes',
                largura: 350,
                child: atendimentosDaGestante.isEmpty
                    ? vazioCentralClinica(
                        'Nenhum atendimento registrado ainda.',
                      )
                    : Column(
                        children: atendimentosDaGestante.take(3).map((a) {
                          final observacao = (a['observacao'] ?? '').trim();
                          return itemResumoCentralClinica(
                            titulo: a['tipo'] ?? 'Atendimento',
                            subtitulo:
                                '${formatarDataHoraCurtaCentral(a['data'] ?? '')}\n'
                                '${observacao.isEmpty ? 'Sem observações registradas.' : observacao}',
                            icone: Icons.assignment_rounded,
                            cor: NatusApp.olivaSeco,
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          blocoFicha('Paciente', [
            linhaInfo('Nome', g['nomeGestante']),
            linhaInfo('Especialidade', especialidade),
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
          blocoFicha(
            'Responsável / contato',
            [
              linhaInfo('Nome do responsável', g['nomePai']),
              linhaInfo('CPF do responsável', g['cpfPai']),
              linhaInfo('Telefone do responsável', g['telefonePai']),
              linhaInfo('E-mail do responsável', g['emailPai']),
            ],
            onEditar: () => abrirPopupEditarSecaoGestante(g, 'Pai'),
          ),
          if (ehObstetricia)
            blocoFicha(
              'Acompanhamento obstétrico',
              [
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
              ],
              onEditar: () => abrirPopupEditarSecaoGestante(g, 'Bebê'),
            ),
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
          blocoFicha('Atendimentos do paciente', [
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
          blocoFicha('Contrações', [
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
          timelineProntuario(g),
          blocoFicha('Documentos do paciente', [
            if (documentosGeraisDaGestante.isEmpty)
              linhaInfo('Documentos', 'Nenhum documento adicional encontrado'),
            ...documentosGeraisDaGestante.map((d) {
              return linhaInfo(d['tipo'] ?? 'Documento', d['nome'] ?? '');
            }),
          ]),
          blocoFicha('Exames', [examesCompletosCentralClinica(g)]),
          if (podeVerFinanceiroGestante)
            blocoFicha('Contratos', [
              if (contratosDaGestante.isEmpty)
                linhaInfo('Contratos', 'Nenhum contrato encontrado'),
              ...contratosDaGestante.map(cardDocumentoProntuario),
            ]),
          if (podeVerFinanceiroGestante)
            blocoFicha('Comprovantes', [
              if (comprovantesDaGestante.isEmpty)
                linhaInfo('Comprovantes', 'Nenhum comprovante encontrado'),
              ...comprovantesDaGestante.map(cardDocumentoProntuario),
            ]),
        ],
      ),
    );
  }

  List<Map<String, String>> atendimentosDaGestanteCentral(
    Map<String, String> g,
  ) {
    final nomeGestante = (g['nomeGestante'] ?? '').trim();
    final lista = atendimentos.where((a) {
      return (a['gestante'] ?? '').trim() == nomeGestante;
    }).toList();

    lista.sort((a, b) {
      final dataA = DateTime.tryParse(a['data'] ?? '') ?? DateTime(1900);
      final dataB = DateTime.tryParse(b['data'] ?? '') ?? DateTime(1900);
      return dataB.compareTo(dataA);
    });

    return lista;
  }

  List<Map<String, String>> contracoesDaGestanteCentral(Map<String, String> g) {
    final nomeGestante = (g['nomeGestante'] ?? '').trim();
    final idGestante = (g['id'] ?? '').trim();
    final lista = contracoes.where((contracao) {
      final nome = (contracao['gestante'] ?? '').trim();
      final id = (contracao['idGestante'] ?? '').trim();
      return (nomeGestante.isNotEmpty && nome == nomeGestante) ||
          (idGestante.isNotEmpty && id == idGestante);
    }).toList();

    lista.sort((a, b) {
      final dataA =
          dataReferenciaContracao(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dataB =
          dataReferenciaContracao(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dataB.compareTo(dataA);
    });

    return lista;
  }

  String formatarDataHoraCurtaCentral(String valor) {
    final data = DateTime.tryParse(valor);
    if (data == null) {
      return valor.trim().isEmpty ? 'Data não informada' : valor;
    }

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano às $hora:$minuto';
  }

  Widget cardResumoCentralClinica({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color cor,
  }) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: cor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: NatusApp.textoSuave,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: NatusApp.texto,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget centralClinicaTag(IconData icone, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: NatusApp.vinho),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NatusApp.vinho,
            ),
          ),
        ],
      ),
    );
  }

  Widget chipAlertaCentralClinica({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required Color cor,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NatusApp.vinho,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 12, color: NatusApp.textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget secaoCentralClinica({
    required String titulo,
    required Widget child,
    double largura = 340,
  }) {
    return Container(
      width: largura,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget itemResumoCentralClinica({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Color cor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NatusApp.texto,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: NatusApp.textoSuave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget vazioCentralClinica(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.35)),
      ),
      child: Text(
        texto,
        style: TextStyle(color: NatusApp.textoSuave, height: 1.4),
      ),
    );
  }

  Widget examesRecentesCentralClinica(Map<String, String> g) {
    final idGestante = (g['id'] ?? '').trim();

    if (idGestante.isEmpty) {
      return vazioCentralClinica('Paciente sem identificação para exames.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: tenantFirestore
          .consultaRegistrosDoPaciente('exames', pacienteId: idGestante)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final dadosA = a.data() as Map<String, dynamic>;
            final dadosB = b.data() as Map<String, dynamic>;
            final criadoEmA = (dadosA['criadoEm'] ?? '').toString();
            final criadoEmB = (dadosB['criadoEm'] ?? '').toString();
            return criadoEmB.compareTo(criadoEmA);
          });

        if (docs.isEmpty) {
          return vazioCentralClinica(
            'Nenhum exame enviado por este paciente até o momento.',
          );
        }

        return Column(
          children: docs.take(3).map((doc) {
            final dados = doc.data() as Map<String, dynamic>;
            return itemResumoCentralClinica(
              titulo: (dados['nomeArquivo'] ?? 'Exame').toString(),
              subtitulo: formatarDataHoraCurtaCentral(
                (dados['criadoEm'] ?? '').toString(),
              ),
              icone: Icons.description_rounded,
              cor: NatusApp.marsalaSuave,
            );
          }).toList(),
        );
      },
    );
  }

  Widget examesCompletosCentralClinica(Map<String, String> g) {
    final idGestante = (g['id'] ?? '').trim();

    if (idGestante.isEmpty) {
      return vazioCentralClinica('Paciente sem identificação para exames.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: tenantFirestore
          .consultaRegistrosDoPaciente('exames', pacienteId: idGestante)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final dadosA = a.data() as Map<String, dynamic>;
            final dadosB = b.data() as Map<String, dynamic>;
            final criadoEmA = (dadosA['criadoEm'] ?? '').toString();
            final criadoEmB = (dadosB['criadoEm'] ?? '').toString();
            return criadoEmB.compareTo(criadoEmA);
          });

        if (docs.isEmpty) {
          return vazioCentralClinica(
            'Nenhum exame encontrado para este paciente.',
          );
        }

        return Column(
          children: docs.map((doc) {
            final dados = (doc.data() as Map<String, dynamic>).map((k, v) {
              return MapEntry(k, v.toString());
            });

            return cardDocumentoProntuario({
              'tipo': 'Exame',
              'nome': dados['nomeArquivo'] ?? 'Exame',
              'arquivoNome': dados['nomeArquivo'] ?? 'Exame',
              'arquivoUrl': dados['url'] ?? '',
              'data': formatarDataHoraCurtaCentral(dados['criadoEm'] ?? ''),
            });
          }).toList(),
        );
      },
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
          NatusTermos.rotuloStatusPaciente(status),
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
        final isMobile =
            constraints.maxWidth < 700 || NatusBreakpoints.isPhone(context);

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
          'Nenhum paciente cadastrado ainda.',
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
    return gestacao.calcularSemanas(dpp);
  }

  String frutaDaSemana(int semanas) {
    return gestacao.frutaDaSemana(semanas);
  }

  String imagemFrutaDaSemana(int semanas) {
    return gestacao.imagemFrutaDaSemana(semanas);
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
      'couve-flor',
      'abóbora',
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
        borderRadius: BorderRadius.circular(18),
        color: NatusApp.offWhite,
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
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
                    borderRadius: BorderRadius.circular(12),
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
                      valor: semanas > 0 ? '$semanas semanas' : 'A calcular',
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
                          valueColor: AlwaysStoppedAnimation(NatusApp.marsala),
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: NatusApp.douradoClaro.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  imagemGestacional(semanas: semanas, tamanho: tamanhoImagem),
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
                children: [blocoTexto, const SizedBox(height: 22), blocoImagem],
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
        'Paciente: ${gestante['nomeGestante'] ?? 'Não informado'}',
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

    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
      return p['gestante'] == nomeGestante &&
          p['status'] != 'Pago' &&
          fincalc.lancamentoFinanceiroValido(p);
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
      return const Center(child: Text('Nenhum paciente vinculado.'));
    }

    final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';

    final gestantesVinculadas = gestantes.where((g) {
      return g['uidGestante'] == uidLogado;
    }).toList();

    if (gestantesVinculadas.isEmpty) {
      return Center(
        child: Text(
          'Nenhum paciente vinculado a este login.',
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
      return const Center(child: Text('Nenhum paciente cadastrado'));
    }

    if (widget.tipoUsuario != 'gestante' && gestantesAtivas.isEmpty) {
      return const Center(
        child: Text('Nenhum paciente ativo disponível para upload.'),
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
                'Paciente',
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
    Map<String, String> gestanteSelecionada = <String, String>{};

    if (widget.tipoUsuario == 'gestante') {
      final uidLogado = FirebaseAuth.instance.currentUser?.uid ?? '';
      gestanteSelecionada = gestantes.firstWhere(
        (g) => g['uidGestante'] == uidLogado,
        orElse: () => {},
      );
      gestanteSelecionadaNome = gestanteSelecionada['nomeGestante'] ?? '';
    } else {
      if (documentoGestanteSelecionada.isEmpty ||
          documentoGestanteSelecionada == 'Selecione') {
        mostrarMensagem('Selecione um paciente ativo.');
        return;
      }

      gestanteSelecionada = gestantesAtivasParaDocumentos().firstWhere(
        (g) => g['nomeGestante'] == documentoGestanteSelecionada,
        orElse: () => {},
      );

      if (gestanteSelecionada.isEmpty) {
        mostrarMensagem(
          'Esse paciente não está ativo para receber documentos.',
        );
        return;
      }

      gestanteSelecionadaNome = documentoGestanteSelecionada;
    }

    if (gestanteSelecionadaNome.trim().isEmpty) {
      mostrarMensagem('Não foi possível identificar o paciente.');
      return;
    }

    if ((gestanteSelecionada['id'] ?? '').trim().isEmpty) {
      mostrarMensagem('Não foi possível identificar o cadastro da paciente.');
      return;
    }

    final pacienteId = (gestanteSelecionada['id'] ?? '').trim();
    if (widget.escopoTenant.ehPaciente &&
        pacienteId != widget.escopoTenant.pacienteId) {
      mostrarMensagem('Cadastro fora do contexto autenticado.');
      return;
    }

    final uidPaciente = widget.escopoTenant.ehPaciente
        ? widget.escopoTenant.uidUsuario
        : (gestanteSelecionada['uidGestante'] ?? '').trim();

    mostrarMensagem('Enviando arquivo...');

    final upload = await uploadArquivo(
      arquivoSelecionado!,
      pasta: 'pacientes/$pacienteId/documentos',
      pacienteId: pacienteId,
    );

    if (upload == null) {
      mostrarMensagem('Não foi possível enviar o arquivo');
      return;
    }

    final novoDocumento = {
      'nome': arquivoSelecionado!.name,
      'tipo': documentoTipoSelecionado,
      'gestante': gestanteSelecionadaNome,
      'gestanteId': pacienteId,
      'pacienteId': pacienteId,
      'uidGestante': uidPaciente,
      'arquivoNome': arquivoSelecionado!.name,
      'arquivoUrl': upload.url,
      'arquivoCaminho': upload.caminho,
      'data': formatarDataHora(DateTime.now()),
    };

    try {
      final referencia = await firestore
          .collection('documentos')
          .add(tenantFirestore.prepararCriacaoTexto(novoDocumento));
      novoDocumento['id'] = referencia.id;
    } catch (e) {
      await removerUploadOrfao(upload, 'documento');
      logErroSeguro('Erro ao registrar documento após o upload.', e);
      mostrarMensagem(
        'O arquivo não foi salvo e o envio foi desfeito com segurança.',
      );
      return;
    }

    setState(() {
      documentos.add(novoDocumento);
      documentoTipoSelecionado = 'Exame';
      documentoGestanteSelecionada = 'Selecione';
      arquivoSelecionado = null;
    });

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
                      '${widget.tipoUsuario == 'gestante' ? '' : 'Paciente: ${d['gestante'] ?? 'Não informado'}\n'}'
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
                        if (usuarioEhAdmin())
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
                  labelText: 'Buscar paciente ativo',
                  hintText: 'Nome, telefone, e-mail, cidade ou unidade...',
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
                    'Nenhum paciente ativo encontrado para registrar contrações.',
                    style: TextStyle(
                      color: NatusApp.vinho,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],

              dropdownGrande(
                'Paciente',
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

          painelResumoContracoes(),
        ],
      ),
    );
  }

  void iniciarContracao() {
    if (contracaoGestanteSelecionada == 'Selecione') {
      mostrarMensagem('Selecione um paciente ativo antes de iniciar.');
      return;
    }

    final gestanteAtivaSelecionada = gestantes.any((g) {
      return (g['nomeGestante'] ?? '') == contracaoGestanteSelecionada &&
          gestanteAtivaParaContracoes(g);
    });

    if (!gestanteAtivaSelecionada) {
      mostrarMensagem(
        'Esse paciente não está ativo para registrar contrações.',
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
                    final gestanteSelecionada = gestantes.firstWhere(
                      (g) =>
                          (g['nomeGestante'] ?? '') ==
                          contracaoGestanteSelecionada,
                      orElse: () => {},
                    );

                    final novaContracao = {
                      'gestante': contracaoGestanteSelecionada,
                      'idGestante': gestanteSelecionada['id'] ?? '',
                      'uidGestante': gestanteSelecionada['uidGestante'] ?? '',
                      'origemTipoUsuario': widget.tipoUsuario,
                      'origemNomeUsuario': widget.nomeUsuario,
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
      return const Text('Nenhuma contração registrada para este paciente.');
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

  Widget painelResumoContracoes() {
    final hoje = DateTime.now();
    final textoBusca = buscaContracoesController.text.trim().toLowerCase();
    final grupos = <String, List<Map<String, String>>>{};

    for (final contracao in contracoes) {
      final dataContracao = dataReferenciaContracao(contracao);

      if (dataContracao == null || !mesmaData(dataContracao, hoje)) {
        continue;
      }

      final nomeGestante = nomeGestanteDaContracao(contracao);

      if (widget.tipoUsuario == 'gestante') {
        if (nomeGestante != contracaoGestanteSelecionada) {
          continue;
        }
      } else if (textoBusca.isNotEmpty &&
          !nomeGestante.toLowerCase().contains(textoBusca)) {
        continue;
      }

      grupos.putIfAbsent(nomeGestante, () => []).add(contracao);
    }

    if (grupos.isEmpty) {
      return Text(
        widget.tipoUsuario == 'gestante'
            ? 'Nenhuma contração registrada hoje.'
            : 'Nenhuma contração registrada hoje para a busca informada.',
      );
    }

    final nomesOrdenados = grupos.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo de hoje',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: NatusApp.vinho,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Mostrando as 3 últimas contrações de cada paciente no dia.',
          style: TextStyle(fontSize: 14, color: NatusApp.textoSuave),
        ),
        const SizedBox(height: 16),
        ...nomesOrdenados.map((nomeGestante) {
          final lista = grupos[nomeGestante]!
            ..sort((a, b) {
              final dataA =
                  dataReferenciaContracao(a) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dataB =
                  dataReferenciaContracao(b) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return dataB.compareTo(dataA);
            });

          final ultimasTres = lista.take(3).toList();

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NatusApp.rose.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: NatusApp.vinho,
                      child: Icon(Icons.favorite, color: NatusApp.offWhite),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomeGestante,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: NatusApp.vinho,
                            ),
                          ),
                          Text(
                            '${lista.length} contração(ões) registrada(s) hoje',
                            style: TextStyle(
                              fontSize: 13,
                              color: NatusApp.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...ultimasTres.asMap().entries.map((entry) {
                  final index = entry.key;
                  final c = entry.value;

                  return Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(
                      bottom: index == ultimasTres.length - 1 ? 0 : 10,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFFFFEFEA)
                          : NatusApp.vinho.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Início: ${c['inicio'] ?? '-'} | Fim: ${c['fim'] ?? '-'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NatusApp.texto,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Duração: ${c['duracao'] ?? 'Não informada'} | '
                          'Intervalo: ${c['intervalo'] ?? 'Não informado'} | '
                          'Intensidade: ${c['intensidade'] ?? 'Não informada'}',
                        ),
                        if ((c['observacao'] ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Observação: ${c['observacao']}'),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  DateTime? dataReferenciaContracao(Map<String, String> contracao) {
    return DateTime.tryParse(contracao['fimISO'] ?? '') ??
        DateTime.tryParse(contracao['inicioISO'] ?? '') ??
        DateTime.tryParse(contracao['criadoEm'] ?? '');
  }

  bool mesmaData(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String nomeGestanteDaContracao(Map<String, String> contracao) {
    final nomeSalvo = (contracao['gestante'] ?? '').trim();

    if (nomeSalvo.isNotEmpty) {
      return nomeSalvo;
    }

    final idGestante = (contracao['idGestante'] ?? '').trim();
    final uidGestante = (contracao['uidGestante'] ?? '').trim();

    for (final gestante in gestantes) {
      if (idGestante.isNotEmpty && (gestante['id'] ?? '') == idGestante) {
        return (gestante['nomeGestante'] ?? 'Paciente não identificado').trim();
      }

      if (uidGestante.isNotEmpty &&
          (gestante['uidGestante'] ?? '') == uidGestante) {
        return (gestante['nomeGestante'] ?? 'Paciente não identificado').trim();
      }
    }

    return 'Paciente não identificado';
  }

  Widget telaUsuarios() {
    return StreamBuilder<QuerySnapshot>(
      stream: tenantFirestore.consultaClinica('usuarios').snapshots(),
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
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Reenviar acesso por e-mail',
                          icon: const Icon(Icons.mark_email_unread_outlined),
                          onPressed: () =>
                              reenviarConviteUsuario(email.toString()),
                        ),
                        IconButton(
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
                                      onPressed: () =>
                                          Navigator.pop(context, true),
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
                              try {
                                final callable = FirebaseFunctions.instanceFor(
                                  region: 'us-central1',
                                ).httpsCallable('excluirUsuarioAuth');
                                await callable.call({'uidUsuario': doc.id});
                                mostrarMensagem('Usuário excluído.');
                              } on FirebaseFunctionsException catch (e) {
                                mostrarMensagem(
                                  mensagemErroFunctionsSeguro(
                                    e,
                                    fallback:
                                        'Não foi possível excluir o usuário.',
                                  ),
                                );
                              }
                            }
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
      },
    );
  }

  Widget telaProntuario() {
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
            'Prontuário clínico do paciente com anamnese e evolução.',
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
                labelText: 'Selecionar paciente',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: gestantes
                  .where((g) {
                    final status = (g['statusGestante'] ?? '').trim();

                    return status == 'Ativa' ||
                        status == 'Gestante' ||
                        status == 'Puérpera';
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
      mostrarMensagem('Erro: paciente sem ID.');
      return;
    }

    try {
      await firestore
          .collection('prontuario_atendimentos')
          .add(
            tenantFirestore.prepararCriacao({
              ...identidadePacienteProntuario(
                pacienteId: idGestante,
                pacienteUid: g['uidGestante'],
              ),
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
            }),
          );

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
      logErroSeguro('Erro ao salvar anamnese.', e);
      mostrarMensagem('Erro ao salvar anamnese.');
    }
  }

  Future<void> salvarExameFisicoProntuario(Map<String, String> g) async {
    final idGestante = g['id'] ?? '';

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: paciente sem ID.');
      return;
    }

    try {
      await firestore
          .collection('prontuario_atendimentos')
          .add(
            tenantFirestore.prepararCriacao({
              ...identidadePacienteProntuario(
                pacienteId: idGestante,
                pacienteUid: g['uidGestante'],
              ),
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
            }),
          );

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
      logErroSeguro('Erro ao salvar exame fisico.', e);
      mostrarMensagem('Erro ao salvar exame físico.');
    }
  }

  Future<void> salvarPlanoCuidadoProntuario(Map<String, String> g) async {
    final idGestante = g['id'] ?? '';

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: paciente sem ID.');
      return;
    }

    try {
      await firestore
          .collection('prontuario_atendimentos')
          .add(
            tenantFirestore.prepararCriacao({
              ...identidadePacienteProntuario(
                pacienteId: idGestante,
                pacienteUid: g['uidGestante'],
              ),
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
            }),
          );

      planoCondutasController.clear();
      planoOrientacoesController.clear();
      planoEncaminhamentosController.clear();
      planoRetornoController.clear();
      planoObservacoesController.clear();

      setState(() {});

      mostrarMensagem('Plano de cuidado salvo.');
    } catch (e) {
      logErroSeguro('Erro ao salvar plano de cuidado.', e);
      mostrarMensagem('Erro ao salvar plano de cuidado.');
    }
  }

  Future<void> salvarEvolucaoProntuario(Map<String, String> g) async {
    final idGestante = g['id'] ?? '';
    final nomeGestante = g['nomeGestante'] ?? '';
    final texto = observacaoProntuarioController.text.trim();

    if (idGestante.isEmpty) {
      mostrarMensagem('Erro: paciente sem ID.');
      return;
    }

    if (texto.isEmpty) {
      mostrarMensagem('Digite uma evolução.');
      return;
    }

    try {
      await firestore
          .collection('prontuarios')
          .add(
            tenantFirestore.prepararCriacao({
              ...identidadePacienteProntuario(
                pacienteId: idGestante,
                pacienteUid: g['uidGestante'],
              ),
              'nomeGestante': nomeGestante,
              'texto': texto,
              'data': formatarDataHora(DateTime.now()),
              'criadoEm': DateTime.now().toIso8601String(),
              'eo': usuarioEhAdmin() ? eoResponsavelProntuario : nomeEoLogada(),
              'tipo': tipoObservacaoProntuario,
              'anexo': nomeArquivoSelecionado,
            }),
          );

      observacaoProntuarioController.clear();
      nomeArquivoSelecionado = '';

      setState(() {});

      mostrarMensagem('Evolução registrada no prontuário.');
    } catch (e) {
      logErroSeguro('Erro ao salvar evolucao.', e);
      mostrarMensagem('Erro ao salvar evolução.');
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
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
      stream: tenantFirestore
          .consultaRegistrosDoPaciente(
            'prontuario_atendimentos',
            pacienteId: g['id'] ?? '',
          )
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

        final atendimentos = docs
            .map(
              (d) =>
                  Map<String, dynamic>.from(d.data() as Map<String, dynamic>),
            )
            .toList();

        atendimentos.sort((a, b) {
          return (b['criadoEm'] ?? '').toString().compareTo(
            (a['criadoEm'] ?? '').toString(),
          );
        });

        return blocoFicha('Histórico clínico', [
          ...atendimentos.map((a) {
            final tipo = (a['tipo'] ?? '').toString().trim();
            final eo = (a['eo'] ?? '').toString().trim();
            final data = (a['data'] ?? '').toString().trim();
            final autoria = [
              data,
              eo,
            ].where((valor) => valor.isNotEmpty).join(' — ');
            final camposClinicos = camposClinicosDoAtendimento(a);

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
                              tipo.isEmpty ? 'Atendimento clínico' : tipo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: NatusApp.vinho,
                              ),
                            ),

                            if (autoria.isNotEmpty)
                              Text(
                                autoria,
                                style: TextStyle(color: NatusApp.textoSuave),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  ...camposClinicos.map((campoClinico) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: NatusApp.texto,
                            fontSize: 14,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(
                              text: '${campoClinico.rotulo}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: NatusApp.vinho,
                              ),
                            ),
                            TextSpan(text: campoClinico.valor),
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
        stream: tenantFirestore
            .consultaRegistrosDoPaciente(
              'prontuarios',
              pacienteId: g['id'] ?? '',
            )
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
    final isMobile = NatusBreakpoints.usarLayoutCompacto(context);

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
                              'Mapa de pacientes',
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
                          'Mapa de pacientes',
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
          'Nenhum plano ativo cadastrado. Cadastre um plano em “Planos da Natus” antes de cadastrar o paciente.',
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
            'Cadastre os planos usados nos atendimentos e contratos.',
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
                      '${formatarMoeda(valor)} • $qtdParcelas parcela(s)',
                    ),
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
    final larguraResponsiva = NatusBreakpoints.usarLayoutCompacto(context)
        ? (MediaQuery.sizeOf(context).width - 80).clamp(230.0, 360.0)
        : 360.0;
    return SizedBox(
      width: larguraResponsiva,
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

  Future<void> salvarGestante() async {
    if (salvandoPaciente) return;

    if (nomeGestante.text.trim().isEmpty) {
      mostrarMensagem('Informe o nome do paciente.');
      return;
    }

    if (planoIdSelecionado.isEmpty || plano.trim().isEmpty) {
      mostrarMensagem(
        'Cadastre e selecione um plano antes de salvar o paciente.',
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
    final pacienteRef = firestore.collection('gestantes').doc();
    final pacienteId = pacienteRef.id;
    final dadosBaseGestante = <String, String>{
      'pacienteId': pacienteId,
      'gestanteId': pacienteId,
      'idGestante': pacienteId,
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
      'especialidadeAcompanhamento': especialidadePaciente,
      'tipoCadastroPaciente': especialidadePaciente,
      'moduloObstetricoAtivo': especialidadePacienteEhObstetricia.toString(),
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
      'statusGestante': especialidadePacienteEhObstetricia
          ? 'Gestante'
          : 'Ativa',
      'criadoEm': DateTime.now().toIso8601String(),
      'uid': FirebaseAuth.instance.currentUser!.uid,
    };
    final metadadosContrato = ContratoPayloadMapper.criarMetadadosIniciais(
      paciente: dadosBaseGestante,
      valorTotal: valorFinal,
      valorEntrada: entrada,
      valorSaldo: valorParcelado,
      valorParcela: valorParcela,
      numeroParcelas: qtdParcelas,
    );

    final novaGestante = <String, String>{
      ...dadosBaseGestante,
      'id': pacienteId,
    };
    final gestanteFirestore = <String, dynamic>{
      ...dadosBaseGestante,
      ...metadadosContrato,
    };

    setState(() => salvandoPaciente = true);

    try {
      final lancamentos = montarLancamentosFinanceiros(novaGestante);
      final lote = firestore.batch();
      lote.set(pacienteRef, tenantFirestore.prepararCriacao(gestanteFirestore));

      for (final lancamento in lancamentos) {
        final parcelaRef = firestore.collection('parcelas').doc();
        lote.set(parcelaRef, tenantFirestore.prepararCriacaoTexto(lancamento));
      }

      await lote.commit();
      if (!mounted) return;

      setState(limparCampos);
      await Future.wait([
        carregarGestantesFirestore(),
        carregarParcelasFirestore(),
      ]);

      if (mounted) {
        mostrarMensagem(
          'Paciente salvo com financeiro vinculado com segurança.',
        );
      }
    } catch (e) {
      logErroSeguro('Erro ao salvar paciente e financeiro.', e);
      if (mounted) {
        mostrarMensagem(
          'Não foi possível salvar. Nenhum dado parcial foi criado.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => salvandoPaciente = false);
      }
    }
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
    especialidadePaciente = NatusEspecialidades.clinicaGeral;

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
    final ativos = planosCadastrados.where((p) => p['ativo'] != false).toList();
    if (ativos.isNotEmpty) {
      final primeiro = ativos.first;
      planoIdSelecionado = (primeiro['id'] ?? '').toString();
      plano = (primeiro['nomePlano'] ?? '').toString();
      parcelas = (primeiro['parcelas'] ?? '1').toString();
    }
    descontoPercentual = '0%';
    parcelas = '1';
    consultorio = 'Não';
    formaPagamento = 'Pix';
  }

  Widget listaGestantes() {
    if (gestantes.isEmpty) {
      return const Text('Nenhum paciente cadastrado ainda.');
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

      if (filtroPlanoGestante != 'Todos') {
        final plano = (g['plano'] ?? '').trim();
        if (plano != filtroPlanoGestante) {
          return false;
        }
      }

      return gestanteApareceNaBusca(g, busca);
    }).toList();

    if (listaFiltrada.isEmpty) {
      return const Text('Nenhum paciente encontrado com esse filtro.');
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
          onExcluir: usuarioEhAdmin()
              ? () => confirmarExcluirGestante(g)
              : null,
        );
      }).toList(),
    );
  }

  Future<void> confirmarExcluirGestante(Map<String, String> g) async {
    if (!usuarioEhAdmin()) {
      mostrarMensagem('Somente o administrador pode excluir pacientes.');
      return;
    }

    final possuiAcessoVinculado = [
      g['uidPaciente'],
      g['pacienteUid'],
      g['uidGestante'],
      g['gestanteUid'],
    ].any((uid) => (uid ?? '').trim().isNotEmpty);
    if (possuiAcessoVinculado) {
      mostrarMensagem(
        'Revogue primeiro o acesso da paciente na tela Usuários. '
        'Isso evita deixar uma conta sem cadastro vinculado.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: const Text(
            'Tem certeza que deseja excluir este paciente? Esta ação não pode ser desfeita.',
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
                if (id == null || id.isEmpty) {
                  mostrarMensagem('ID não encontrado.');
                  return;
                }

                try {
                  final pacienteAtual = await firestore
                      .collection('gestantes')
                      .doc(id)
                      .get(const GetOptions(source: Source.server));
                  final dadosPacienteAtual = pacienteAtual.data();
                  if (dadosPacienteAtual == null ||
                      !widget.escopoTenant.pertenceAoTenant(
                        dadosPacienteAtual,
                      )) {
                    mostrarMensagem(
                      'O cadastro não existe mais ou saiu da clínica atual.',
                    );
                    return;
                  }
                  final acessoCriadoDuranteConfirmacao = [
                    dadosPacienteAtual['uidPaciente'],
                    dadosPacienteAtual['pacienteUid'],
                    dadosPacienteAtual['uidGestante'],
                    dadosPacienteAtual['gestanteUid'],
                  ].any((uid) => (uid ?? '').toString().trim().isNotEmpty);
                  if (acessoCriadoDuranteConfirmacao) {
                    mostrarMensagem(
                      'A paciente possui acesso ativo. Revogue-o antes de excluir.',
                    );
                    return;
                  }

                  final parcelas = await tenantFirestore
                      .consultaClinica('parcelas')
                      .where('gestanteId', isEqualTo: id)
                      .get();
                  final batch = firestore.batch();
                  for (final doc in parcelas.docs) {
                    batch.delete(doc.reference);
                  }
                  batch.delete(firestore.collection('gestantes').doc(id));
                  await batch.commit();

                  setState(() {
                    gestantes.removeWhere((item) => item['id'] == id);

                    parcelasFinanceiras.removeWhere(
                      (p) =>
                          p['gestanteId'] == id ||
                          p['pacienteId'] == id ||
                          p['idGestante'] == id,
                    );

                    marcadores.removeWhere((m) => m.markerId.value == id);
                    mapaJaCarregado = false;
                  });

                  mostrarMensagem(
                    'Paciente e financeiro excluídos com sucesso.',
                  );
                } catch (e) {
                  logErroSeguro('Erro ao excluir paciente e financeiro.', e);
                  mostrarMensagem('Erro ao excluir paciente e financeiro.');
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
    return gestacao.calcularIdadeGestacional(dppTexto);
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
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('buscarCoordenadaEndereco');
      final resposta = await callable.call(<String, dynamic>{
        'endereco': endereco.trim(),
      });
      final dados = Map<String, dynamic>.from(resposta.data as Map);
      final latitude = dados['latitude'];
      final longitude = dados['longitude'];

      if (latitude is! num || longitude is! num) {
        return null;
      }

      return LatLng(latitude.toDouble(), longitude.toDouble());
    } catch (e) {
      logErroSeguro('Erro ao converter endereco.', e);
      return null;
    }
  }

  Future<EnderecoCep?> buscarEnderecoPorCep(String cep) async {
    try {
      return await cepService.buscar(cep);
    } catch (e) {
      logErroSeguro('Erro ao buscar CEP.', e);
      return null;
    }
  }

  void mostrarResultadoConsultaCep(EnderecoCep? resultado) {
    if (!mounted) return;
    if (resultado == null) {
      mostrarMensagem(
        'CEP não encontrado. Confira o número ou preencha o endereço manualmente.',
      );
      return;
    }
    if (!resultado.possuiLogradouro) {
      mostrarMensagem(
        'CEP localizado apenas até cidade/UF. Complete o endereço manualmente.',
      );
    }
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
  final Map<String, PlatformFile> comprovantesSelecionados = {};
  final Set<String> parcelasComUploadEmAndamento = {};

  Future<PlatformFile?> escolherArquivoClinico() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'heif',
        ],
        withData: true,
      );
      if (resultado == null || resultado.files.isEmpty) return null;

      final arquivo = resultado.files.first;
      metadadosUpload(arquivo);
      return arquivo;
    } on FormatException catch (e) {
      mostrarMensagem(e.message);
      return null;
    } catch (e) {
      logErroSeguro('Erro ao selecionar arquivo.', e);
      mostrarMensagem('Não foi possível ler o arquivo selecionado.');
      return null;
    }
  }

  Future<void> selecionarArquivo() async {
    final arquivo = await escolherArquivoClinico();
    if (arquivo != null) {
      setState(() {
        arquivoSelecionado = arquivo;
      });

      mostrarMensagem('Arquivo selecionado: ${arquivoSelecionado!.name}');
    }
  }

  String chaveParcelaFinanceira(Map<String, String> parcela) {
    return (parcela['id'] ?? '').trim();
  }

  Future<void> selecionarComprovanteParcela(Map<String, String> parcela) async {
    final chave = chaveParcelaFinanceira(parcela);
    if (chave.isEmpty) {
      mostrarMensagem('Não foi possível identificar a parcela.');
      return;
    }

    final arquivo = await escolherArquivoClinico();
    if (arquivo == null) return;
    setState(() => comprovantesSelecionados[chave] = arquivo);
    mostrarMensagem('Comprovante selecionado: ${arquivo.name}');
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
        await dados.buscarGestantes(widget.escopoTenant),
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

      logInfoSeguro('Pacientes carregados do Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao carregar pacientes.', e);
      mostrarMensagem('Erro ao carregar pacientes do Firebase');
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

  bool podeVisualizarDetalhesMapa() {
    return widget.tipoUsuario == 'admin' ||
        widget.tipoUsuario == 'enfermeira' ||
        widget.tipoUsuario == 'obstetra' ||
        widget.tipoUsuario == 'superAdmin';
  }

  String enderecoDetalhadoMapa(Map<String, String> g) {
    final rua = (g['enderecoGestante'] ?? '').trim();
    final numero = (g['numeroGestante'] ?? '').trim();
    final complemento = (g['complementoGestante'] ?? '').trim();
    final bairro = (g['bairroGestante'] ?? '').trim();
    final cidade = (g['cidadeGestante'] ?? '').trim();
    final estado = (g['estadoGestante'] ?? '').trim();
    final cep = (g['cepGestante'] ?? '').trim();

    final partes = <String>[
      if (rua.isNotEmpty) rua,
      if (numero.isNotEmpty) numero,
      if (complemento.isNotEmpty) complemento,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) cidade,
      if (estado.isNotEmpty) estado,
      if (cep.isNotEmpty) 'CEP $cep',
    ];

    if (partes.isEmpty) {
      return 'Endereço não informado';
    }

    return partes.join(', ');
  }

  Widget itemDetalheMapa({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NatusApp.rose.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: NatusApp.rose.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 18, color: NatusApp.vinho),
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
                    fontWeight: FontWeight.w700,
                    color: NatusApp.textoSuave,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor.trim().isEmpty ? 'Não informado' : valor,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: NatusApp.texto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String normalizarTelefoneMapa(String telefone) {
    return telefone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> abrirLinkExternoMapa(Uri uri, String mensagemErro) async {
    if (!uriExternaPermitida(
      uri,
      permitirTelefone: true,
      hostsHttpsPermitidos: const {'wa.me', 'www.google.com'},
    )) {
      mostrarMensagem(mensagemErro);
      return;
    }

    try {
      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu) {
        mostrarMensagem(mensagemErro);
      }
    } catch (_) {
      mostrarMensagem(mensagemErro);
    }
  }

  Future<void> ligarParaGestanteMapa(String telefone) async {
    final telefoneNormalizado = normalizarTelefoneMapa(telefone);
    if (telefoneNormalizado.isEmpty) {
      mostrarMensagem('Telefone do paciente não informado.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: telefoneNormalizado);
    await abrirLinkExternoMapa(uri, 'Não foi possível iniciar a ligação.');
  }

  Future<void> abrirWhatsAppGestanteMapa(String telefone) async {
    final telefoneNormalizado = normalizarTelefoneMapa(telefone);
    if (telefoneNormalizado.isEmpty) {
      mostrarMensagem('Telefone do paciente não informado.');
      return;
    }

    final numeroComPais = telefoneNormalizado.startsWith('55')
        ? telefoneNormalizado
        : '55$telefoneNormalizado';

    final uri = Uri.https('wa.me', '/$numeroComPais');
    await abrirLinkExternoMapa(uri, 'Não foi possível abrir o WhatsApp.');
  }

  Future<void> abrirRotaGestanteMapa(LatLng coordenada) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${coordenada.latitude},${coordenada.longitude}',
      'travelmode': 'driving',
    });
    await abrirLinkExternoMapa(uri, 'Não foi possível abrir a rota.');
  }

  Widget botaoAcaoMapa({
    required IconData icone,
    required String texto,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 160,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: NatusApp.vinho,
          side: BorderSide(color: NatusApp.rose.withValues(alpha: 0.55)),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> abrirDetalhesMapaGestante(
    Map<String, String> g,
    LatLng coordenada,
  ) async {
    if (!podeVisualizarDetalhesMapa()) {
      return;
    }

    final nomeGestante = (g['nomeGestante'] ?? '').trim();
    final nomeBebeMapa = (g['nomeBebe'] ?? '').trim();
    final dppMapa = (g['dpp'] ?? '').trim();
    final planoMapa = (g['plano'] ?? '').trim();
    final telefoneMapa = (g['telefoneGestante'] ?? '').trim();
    final enderecoMapa = enderecoDetalhadoMapa(g);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: BoxDecoration(
              color: NatusApp.offWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: NatusApp.rose.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: NatusApp.rose.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: NatusApp.vinho,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeGestante.isEmpty
                                  ? 'Paciente sem nome'
                                  : nomeGestante,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: NatusApp.vinho,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Detalhes do pin no mapa',
                              style: TextStyle(
                                fontSize: 13,
                                color: NatusApp.textoSuave,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  itemDetalheMapa(
                    icone: Icons.home_rounded,
                    titulo: 'Endereço',
                    valor: enderecoMapa,
                  ),
                  itemDetalheMapa(
                    icone: Icons.phone_rounded,
                    titulo: 'Telefone',
                    valor: telefoneMapa,
                  ),
                  itemDetalheMapa(
                    icone: Icons.workspace_premium_rounded,
                    titulo: 'Plano',
                    valor: planoMapa,
                  ),
                  itemDetalheMapa(
                    icone: Icons.child_friendly_rounded,
                    titulo: 'Nome do bebê',
                    valor: nomeBebeMapa,
                  ),
                  itemDetalheMapa(
                    icone: Icons.event_available_rounded,
                    titulo: 'DPP',
                    valor: dppMapa,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      botaoAcaoMapa(
                        icone: Icons.call_rounded,
                        texto: 'Ligar',
                        onTap: () => ligarParaGestanteMapa(telefoneMapa),
                      ),
                      botaoAcaoMapa(
                        icone: Icons.chat_rounded,
                        texto: 'WhatsApp',
                        onTap: () => abrirWhatsAppGestanteMapa(telefoneMapa),
                      ),
                      botaoAcaoMapa(
                        icone: Icons.alt_route_rounded,
                        texto: 'Traçar rota',
                        onTap: () => abrirRotaGestanteMapa(coordenada),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          gestanteSelecionada = g;
                          telaAtual = 'Gestantes';
                        });
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir central do paciente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NatusApp.vinho,
                        foregroundColor: (NatusApp.escuro
                            ? NatusApp.fundo
                            : NatusApp.offWhite),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
      },
    );
  }

  Future<void> carregarMarcadores() async {
    Set<Marker> novosMarcadores = {};

    for (var g in gestantes) {
      if (!gestanteEstaAtiva(g)) {
        continue;
      }

      final endereco = montarEnderecoMapa(g);

      if (endereco.isEmpty) {
        logInfoSeguro('Registro sem endereco suficiente para o mapa.');
        continue;
      }

      logInfoSeguro('Buscando coordenada para o mapa.');

      final coordenada = await buscarCoordenada(endereco);

      if (coordenada != null) {
        novosMarcadores.add(
          Marker(
            markerId: MarkerId(g['id'] ?? g['nomeGestante'] ?? 'sem-id'),
            position: coordenada,
            onTap: () => abrirDetalhesMapaGestante(g, coordenada),
            infoWindow: InfoWindow(
              title: g['nomeGestante'],
              snippet: podeVisualizarDetalhesMapa()
                  ? '${(g['plano'] ?? '').trim().isEmpty ? 'Plano não informado' : g['plano']} • ${(g['dpp'] ?? '').trim().isEmpty ? 'DPP não informada' : 'DPP ${g['dpp']}'}'
                  : 'Toque para visualizar',
            ),
          ),
        );
      } else {
        logInfoSeguro('Coordenada não encontrada para um registro.');
      }
    }

    setState(() {
      marcadores = novosMarcadores;
    });

    logInfoSeguro('Marcadores do mapa atualizados.');
  }

  Future<void> atualizarStatusGestante(Map<String, String> gestante) async {
    final id = gestante['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem('Não foi possível encontrar o ID do paciente.');
      return;
    }

    final statusAtual = gestante['statusGestante'] ?? 'Gestante';

    if (statusAtual == 'Gestante') {
      abrirPopupNascimento(gestante);
      return;
    }

    if (statusAtual == 'Puérpera' || statusAtual == 'Ativa') {
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
        logErroSeguro('Erro ao encerrar atendimento.', e);
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
    final estadoTemp = TextEditingController(
      text: gestante['estadoGestante'] ?? '',
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
    final especialidadeTemp = TextEditingController(
      text: especialidadeDoPaciente(gestante),
    );
    final ehObstetricia = pacienteTemModuloObstetrico(gestante);

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
      Function(String)? onChanged,
    }) {
      return SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
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
          title: const Text('Editar cadastro do paciente'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  campoPopup(nomeTemp, 'Nome do paciente'),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          NatusEspecialidades.opcoes.contains(
                            especialidadeTemp.text,
                          )
                          ? especialidadeTemp.text
                          : 'Outra especialidade',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo / especialidade do acompanhamento',
                        border: OutlineInputBorder(),
                      ),
                      items: NatusEspecialidades.opcoes
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) {
                        especialidadeTemp.text = valor ?? 'Clínica geral';
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  campoPopup(telefoneTemp, 'Telefone'),

                  const SizedBox(height: 16),

                  campoPopup(emailTemp, 'E-mail'),

                  const SizedBox(height: 16),

                  campoPopup(
                    cepTemp,
                    'CEP',
                    onChanged: (value) async {
                      final cepConsultado = value.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (cepConsultado.length == 8) {
                        final resultado = await buscarEnderecoPorCep(value);
                        final cepAtual = cepTemp.text.replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        );
                        if (cepAtual != cepConsultado) return;

                        if (resultado != null) {
                          enderecoTemp.text = resultado.logradouro;
                          bairroTemp.text = resultado.bairro;
                          cidadeTemp.text = resultado.cidade;
                          estadoTemp.text = resultado.estado;
                        }
                        mostrarResultadoConsultaCep(resultado);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  campoPopup(enderecoTemp, 'Endereço'),

                  const SizedBox(height: 16),

                  campoPopup(bairroTemp, 'Bairro'),

                  const SizedBox(height: 16),

                  campoPopup(cidadeTemp, 'Cidade'),

                  const SizedBox(height: 16),

                  campoPopup(estadoTemp, 'UF'),

                  const SizedBox(height: 16),

                  campoPopup(hospitalTemp, 'Unidade / Hospital'),

                  const SizedBox(height: 16),

                  campoPopup(obstetraTemp, 'Profissional responsável'),

                  const SizedBox(height: 16),

                  campoPopup(convenioTemp, 'Convênio'),

                  if (ehObstetricia) ...[
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
                  estadoTemp.text.trim(),
                  cepTemp.text.trim(),
                  hospitalTemp.text.trim(),
                  obstetraTemp.text.trim(),
                  convenioTemp.text.trim(),
                  especialidadeTemp.text.trim(),
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
        {'campo': 'nomeGestante', 'label': 'Nome do paciente'},
        {
          'campo': 'especialidadeAcompanhamento',
          'label': 'Tipo / especialidade do acompanhamento',
        },
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
        {'campo': 'hospitalGestante', 'label': 'Unidade / Hospital'},
        {'campo': 'obstetraGestante', 'label': 'Profissional responsável'},
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
        {'campo': 'nomePai', 'label': 'Nome do responsável'},
        {'campo': 'cpfPai', 'label': 'CPF do responsável'},
        {'campo': 'telefonePai', 'label': 'Telefone do responsável'},
        {'campo': 'emailPai', 'label': 'E-mail do responsável'},
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
        {
          'campo': 'parcelas',
          'label': 'Total de parcelas (incluindo as já pagas)',
        },
        {'campo': 'valorParcela', 'label': 'Valor da parcela'},
        {'campo': 'formaPagamento', 'label': 'Forma de pagamento'},
        {'campo': 'consultorio', 'label': 'Consultório'},
      ],
    };

    final campos = [...(camposPorSecao[secao] ?? const [])];
    if (secao == 'Gestante' && !pacienteTemModuloObstetrico(gestante)) {
      campos.removeWhere(
        (item) =>
            item['campo'] == 'riscoGestacional' ||
            item['campo'] == 'diabetesGestacional',
      );
    }
    final controllers = <String, TextEditingController>{};

    for (final item in campos) {
      final campo = item['campo'] ?? '';
      controllers[campo] = TextEditingController(text: gestante[campo] ?? '');
    }

    Future<void> preencherEnderecoPorCep(String value) async {
      final cepConsultado = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (cepConsultado.length != 8) return;

      final resultado = await buscarEnderecoPorCep(value);
      final cepAtual = controllers['cepGestante']?.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      if (cepAtual != cepConsultado) return;

      if (resultado != null) {
        controllers['enderecoGestante']?.text = resultado.logradouro;
        controllers['bairroGestante']?.text = resultado.bairro;
        controllers['cidadeGestante']?.text = resultado.cidade;
        controllers['estadoGestante']?.text = resultado.estado;
      }
      mostrarResultadoConsultaCep(resultado);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Editar ${secao == 'Gestante'
                ? 'Paciente'
                : secao == 'Pai'
                ? 'Responsável / contato'
                : secao}',
          ),
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
                  final campoFinanceiroCalculado =
                      secao == 'Valores' &&
                      (campo == 'valorDesconto' || campo == 'valorParcela');
                  final campoNumerico =
                      secao == 'Valores' &&
                      (campo == 'valorPlano' ||
                          campo == 'descontoPercentual' ||
                          campo == 'entrada' ||
                          campo == 'parcelas');
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
                      enabled: !campoFinanceiroCalculado,
                      keyboardType: campoNumerico
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : null,
                      inputFormatters: mascara == null ? null : [mascara],
                      maxLines: campo == 'observacoesBebe' ? 3 : 1,
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

                final salvou = secao == 'Valores'
                    ? await salvarEdicaoFinanceiraGestante(
                        gestante,
                        dadosAtualizados,
                      )
                    : await salvarEdicaoSecaoGestante(
                        gestante,
                        dadosAtualizados,
                      );

                if (salvou && context.mounted) {
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

  Future<bool> salvarEdicaoSecaoGestante(
    Map<String, String> gestante,
    Map<String, String> dadosAtualizados,
  ) async {
    final id = gestante['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem('ID do paciente não encontrado.');
      return false;
    }

    try {
      final especialidade = dadosAtualizados['especialidadeAcompanhamento']
          ?.trim();
      if (especialidade != null && especialidade.isNotEmpty) {
        final moduloObstetrico = NatusEspecialidades.ehObstetricia(
          especialidade,
        );
        final statusAtual = gestante['statusGestante'] ?? 'Ativa';
        dadosAtualizados['tipoCadastroPaciente'] = especialidade;
        dadosAtualizados['moduloObstetricoAtivo'] = moduloObstetrico.toString();
        if (statusAtual != 'Puérpera' && statusAtual != 'Encerrada') {
          dadosAtualizados['statusGestante'] = moduloObstetrico
              ? 'Gestante'
              : 'Ativa';
        }
      }

      await firestore.collection('gestantes').doc(id).update(dadosAtualizados);

      setState(() {
        gestante.addAll(dadosAtualizados);
        gestanteSelecionada = gestante;
      });

      mostrarMensagem('Cadastro atualizado com sucesso.');
      return true;
    } catch (e) {
      logErroSeguro('Erro ao editar secao da paciente.', e);
      mostrarMensagem('Erro ao atualizar cadastro.');
      return false;
    }
  }

  Future<bool> salvarEdicaoFinanceiraGestante(
    Map<String, String> gestante,
    Map<String, String> dadosInformados,
  ) async {
    final gestanteId = (gestante['id'] ?? '').trim();
    final nome = (gestante['nomeGestante'] ?? '').trim();
    final uidGestante = (gestante['uidGestante'] ?? '').trim();

    if (gestanteId.isEmpty) {
      mostrarMensagem('ID da paciente não encontrado.');
      return false;
    }

    final valorPlano = converterValor(dadosInformados['valorPlano'] ?? '0');
    final desconto = converterPercentual(
      dadosInformados['descontoPercentual'] ?? '0',
    );
    final entradaInformada = converterValor(dadosInformados['entrada'] ?? '0');
    final quantidadeParcelas = int.tryParse(
      (dadosInformados['parcelas'] ?? '').trim(),
    );

    if (valorPlano <= 0) {
      mostrarMensagem('Informe um valor de plano maior que zero.');
      return false;
    }
    if (desconto < 0 || desconto > 1) {
      mostrarMensagem('O desconto deve estar entre 0% e 100%.');
      return false;
    }
    if (quantidadeParcelas == null ||
        quantidadeParcelas < 1 ||
        quantidadeParcelas > 120) {
      mostrarMensagem('Informe uma quantidade entre 1 e 120 parcelas.');
      return false;
    }

    final valorDesconto = valorPlano * desconto;
    final valorFinal = valorPlano - valorDesconto;
    if (entradaInformada < 0 || entradaInformada > valorFinal) {
      mostrarMensagem('A entrada deve ficar entre zero e o valor final.');
      return false;
    }

    try {
      final snapshot = await tenantFirestore.consultaClinica('parcelas').get();
      final documentos = snapshot.docs.where((doc) {
        final dados = identidadePacienteCanonica(
          doc.data(),
          pacienteId: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.pacienteId
              : null,
          pacienteUid: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.uidUsuario
              : null,
        );
        final idVinculado = (dados['gestanteId'] ?? '').toString().trim();
        final nomeVinculado = (dados['gestante'] ?? '').toString().trim();
        return (idVinculado.isNotEmpty && idVinculado == gestanteId) ||
            (nome.isNotEmpty && nomeVinculado == nome);
      }).toList();

      bool ehEntrada(Map<String, dynamic> dados) {
        return (dados['tipo'] ?? '').toString().trim().toLowerCase() ==
                'entrada' ||
            (dados['numero'] ?? '').toString().trim() == '0';
      }

      bool estaPaga(Map<String, dynamic> dados) {
        final status = (dados['status'] ?? '').toString().trim().toLowerCase();
        return status == 'pago' || status == 'paga';
      }

      final entradasPagas = documentos.where((doc) {
        final dados = identidadePacienteCanonica(
          doc.data(),
          pacienteId: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.pacienteId
              : null,
          pacienteUid: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.uidUsuario
              : null,
        );
        return ehEntrada(dados) && estaPaga(dados);
      }).toList();
      final parcelasPagas = documentos.where((doc) {
        final dados = doc.data();
        return !ehEntrada(dados) && estaPaga(dados);
      }).toList();

      final totalEntradaPaga = entradasPagas.fold<double>(0, (total, doc) {
        return total + converterValor((doc.data()['valor'] ?? '0').toString());
      });
      if (entradasPagas.isNotEmpty &&
          (entradaInformada - totalEntradaPaga).abs() > 0.009) {
        mostrarMensagem(
          'A entrada já foi baixada e não pode ter o valor alterado.',
        );
        return false;
      }

      final numerosPagos = parcelasPagas
          .map((doc) {
            return int.tryParse((doc.data()['numero'] ?? '').toString()) ?? 0;
          })
          .where((numero) => numero > 0)
          .toSet();
      final maiorNumeroPago = numerosPagos.isEmpty
          ? 0
          : numerosPagos.reduce((a, b) => a > b ? a : b);
      if (quantidadeParcelas < parcelasPagas.length ||
          quantidadeParcelas < maiorNumeroPago) {
        mostrarMensagem(
          'Não é possível reduzir para menos parcelas do que as já baixadas.',
        );
        return false;
      }

      final totalParcelasPagas = parcelasPagas.fold<double>(0, (total, doc) {
        return total + converterValor((doc.data()['valor'] ?? '0').toString());
      });
      final saldoParcelado = valorFinal - entradaInformada;
      final saldoPendente = saldoParcelado - totalParcelasPagas;
      final quantidadePendentes = quantidadeParcelas - parcelasPagas.length;
      final quantidadePendentesFinanceiras = saldoPendente > 0.009
          ? quantidadePendentes
          : 0;

      if (saldoPendente < -0.009) {
        mostrarMensagem(
          'O novo total é menor do que o valor das parcelas já baixadas.',
        );
        return false;
      }
      if (saldoPendente > 0.009 && quantidadePendentes == 0) {
        mostrarMensagem(
          'Aumente o número de parcelas para distribuir o saldo pendente.',
        );
        return false;
      }

      final batch = firestore.batch();
      final agora = formatarDataHora(DateTime.now());
      final dadosAtualizados = <String, String>{
        ...dadosInformados,
        'valorPlano': formatarMoeda(valorPlano),
        'descontoPercentual': '${(desconto * 100).toStringAsFixed(0)}%',
        'valorDesconto': formatarMoeda(valorDesconto),
        'entrada': formatarMoeda(entradaInformada),
        'parcelas': quantidadeParcelas.toString(),
        'parcelasPagas': parcelasPagas.length.toString(),
      };

      final numerosPendentes = <int>[];
      for (
        var numero = 1;
        numero <= quantidadeParcelas &&
            numerosPendentes.length < quantidadePendentesFinanceiras;
        numero++
      ) {
        if (!numerosPagos.contains(numero)) numerosPendentes.add(numero);
      }

      final valoresPendentes = fincalc.distribuirSaldoEmParcelas(
        saldoPendente,
        quantidadePendentesFinanceiras,
      );
      final valorParcelaAtual = valoresPendentes.isEmpty
          ? 0.0
          : valoresPendentes.first;
      dadosAtualizados['valorParcela'] = formatarMoeda(valorParcelaAtual);

      batch.update(
        firestore.collection('gestantes').doc(gestanteId),
        tenantFirestore.prepararAtualizacaoTexto(dadosAtualizados),
      );

      final entradasPendentes = documentos.where((doc) {
        final dados = doc.data();
        return ehEntrada(dados) && !estaPaga(dados);
      }).toList();
      if (entradaInformada > 0 && entradasPagas.isEmpty) {
        final dadosEntrada = <String, String>{
          'gestante': nome,
          'gestanteId': gestanteId,
          'uidGestante': uidGestante,
          'tipo': 'entrada',
          'numero': '0',
          'descricao': 'Entrada',
          'valor': formatarMoeda(entradaInformada),
          'vencimento': gerarVencimentoEntrada(),
          'status': 'Pendente',
          'editadoEm': agora,
        };
        if (entradasPendentes.isEmpty) {
          batch.set(
            firestore.collection('parcelas').doc(),
            tenantFirestore.prepararCriacaoTexto(dadosEntrada),
          );
        } else {
          batch.update(
            entradasPendentes.first.reference,
            tenantFirestore.prepararAtualizacaoTexto(dadosEntrada),
          );
          for (final excedente in entradasPendentes.skip(1)) {
            batch.delete(excedente.reference);
          }
        }
      } else {
        for (final entrada in entradasPendentes) {
          batch.delete(entrada.reference);
        }
      }

      final parcelasPendentes =
          documentos.where((doc) {
            final dados = doc.data();
            return !ehEntrada(dados) && !estaPaga(dados);
          }).toList()..sort((a, b) {
            final numeroA =
                int.tryParse((a.data()['numero'] ?? '').toString()) ?? 0;
            final numeroB =
                int.tryParse((b.data()['numero'] ?? '').toString()) ?? 0;
            return numeroA.compareTo(numeroB);
          });

      for (var indice = 0; indice < numerosPendentes.length; indice++) {
        final numero = numerosPendentes[indice];
        final dadosParcela = <String, String>{
          'gestante': nome,
          'gestanteId': gestanteId,
          'uidGestante': uidGestante,
          'tipo': 'parcela',
          'numero': numero.toString(),
          'descricao': '$numeroª Parcela',
          'valor': formatarMoeda(valoresPendentes[indice]),
          'vencimento': gerarVencimentoParcelaHistorico(
            numero,
            parcelasPagas.length,
          ),
          'status': 'Pendente',
          'editadoEm': agora,
        };

        if (indice < parcelasPendentes.length) {
          batch.update(
            parcelasPendentes[indice].reference,
            tenantFirestore.prepararAtualizacaoTexto(dadosParcela),
          );
        } else {
          batch.set(
            firestore.collection('parcelas').doc(),
            tenantFirestore.prepararCriacaoTexto(dadosParcela),
          );
        }
      }
      for (final excedente in parcelasPendentes.skip(numerosPendentes.length)) {
        batch.delete(excedente.reference);
      }

      await batch.commit();
      await carregarParcelasFirestore();

      setState(() {
        gestante.addAll(dadosAtualizados);
        gestanteSelecionada = gestante;
      });
      mostrarMensagem(
        'Financeiro atualizado: ${parcelasPagas.length} parcela(s) paga(s) '
        'preservada(s) e $quantidadePendentesFinanceiras restante(s) '
        'recalculada(s).',
      );
      return true;
    } catch (e) {
      logErroSeguro('Erro ao editar financeiro da paciente.', e);
      mostrarMensagem('Erro ao atualizar o financeiro.');
      return false;
    }
  }

  void abrirPopupCriarUsuario() {
    _sessaoCriacaoUsuario.reiniciar();
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
                      controller: TextEditingController(
                        text: 'Link seguro enviado por e-mail',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Definição da senha',
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
                              child: Text(NatusTermos.rotuloPerfil(tipo)),
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
                          labelText: 'Selecionar paciente',
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
                          labelText: 'Selecionar profissional',
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
                          labelText: 'Selecionar profissional obstetra',
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
      mostrarMensagem('Selecione o paciente para vincular ao login.');
      return;
    }

    if (novoTipoUsuario == 'enfermeira' && enfermeiraSelecionadaLogin == null) {
      mostrarMensagem('Selecione o profissional para vincular ao login.');
      return;
    }

    if (novoTipoUsuario == 'obstetra' && obstetraSelecionadoLogin == null) {
      mostrarMensagem(
        'Selecione o profissional obstetra para vincular ao login.',
      );
      return;
    }

    if (novoTipoUsuario == 'superAdmin' || novoTipoUsuario == 'superadmin') {
      mostrarMensagem('Criação de Super Admin bloqueada neste cadastro.');
      return;
    }

    try {
      final emailNovoUsuario = novoEmailController.text.trim().toLowerCase();
      final idVinculo = switch (novoTipoUsuario) {
        'gestante' => gestanteSelecionadaLogin ?? '',
        'enfermeira' => enfermeiraSelecionadaLogin ?? '',
        'obstetra' => obstetraSelecionadoLogin ?? '',
        _ => '',
      };
      final assinaturaOperacao = jsonEncode([
        novoNomeController.text.trim(),
        emailNovoUsuario,
        novoTipoUsuario,
        idVinculo,
      ]);
      final operacaoId = _sessaoCriacaoUsuario.idParaAssinatura(
        assinaturaOperacao,
      );

      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('criarUsuarioClinica');
      final resposta = await callable.call({
        'nome': novoNomeController.text.trim(),
        'email': emailNovoUsuario,
        'tipo': novoTipoUsuario,
        'idVinculo': idVinculo,
        'operacaoId': operacaoId,
      });
      final resultado = Map<String, dynamic>.from(resposta.data as Map);
      if (resultado['sucesso'] != true) {
        throw StateError('O servidor não confirmou a criação do usuário.');
      }

      var conviteEnviado = false;
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: emailNovoUsuario,
        );
        conviteEnviado = true;
      } catch (e) {
        logErroSeguro('Usuario criado, mas o convite nao foi enviado.', e);
      }

      if (!mounted) return;
      Navigator.pop(context);

      novoNomeController.clear();
      novoEmailController.clear();
      gestanteSelecionadaLogin = null;
      enfermeiraSelecionadaLogin = null;
      obstetraSelecionadoLogin = null;
      novoTipoUsuario = 'gestante';
      _sessaoCriacaoUsuario.reiniciar();

      await carregarEnfermeirasFirestore();
      await carregarObstetrasFirestore();
      await carregarGestantesFirestore();

      mostrarMensagem(
        conviteEnviado
            ? 'Usuário criado. O link para definir a senha foi enviado.'
            : 'Usuário criado, mas o e-mail de acesso ficou pendente.',
      );
    } on FirebaseFunctionsException catch (e) {
      logErroSeguro('Erro ao criar usuario.', e);
      mostrarMensagem(
        mensagemErroFunctionsSeguro(
          e,
          fallback: 'Não foi possível criar o usuário.',
        ),
      );
    } catch (e) {
      logErroSeguro('Erro inesperado ao criar usuario.', e);
      mostrarMensagem('Não foi possível criar o usuário.');
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
    String estado,
    String cep,
    String hospital,
    String obstetra,
    String convenio,
    String especialidade,
    String riscoGestacional,
    String diabetesGestacional,
  ) async {
    final id = gestante['id'];

    if (id == null || id.isEmpty) {
      mostrarMensagem('ID do paciente não encontrado.');
      return;
    }

    try {
      final moduloObstetrico = NatusEspecialidades.ehObstetricia(especialidade);
      final statusAtual = gestante['statusGestante'] ?? 'Ativa';
      final statusAtualizado =
          statusAtual == 'Puérpera' || statusAtual == 'Encerrada'
          ? statusAtual
          : moduloObstetrico
          ? 'Gestante'
          : 'Ativa';
      final dadosAtualizados = {
        'nomeGestante': nome,
        'telefoneGestante': telefone,
        'emailGestante': email,
        'enderecoGestante': endereco,
        'bairroGestante': bairro,
        'cidadeGestante': cidade,
        'estadoGestante': estado,
        'cepGestante': cep,
        'hospitalGestante': hospital,
        'obstetraGestante': obstetra,
        'convenioGestante': convenio,
        'especialidadeAcompanhamento': especialidade,
        'tipoCadastroPaciente': especialidade,
        'moduloObstetricoAtivo': moduloObstetrico.toString(),
        'statusGestante': statusAtualizado,
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
      logErroSeguro('Erro ao editar paciente.', e);
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

      mostrarMensagem(
        'Paciente atualizado para o acompanhamento pós-parto com sucesso.',
      );
    } catch (e) {
      logErroSeguro('Erro ao salvar dados do procedimento.', e);
      mostrarMensagem('Erro ao salvar dados do nascimento.');
    }
  }

  Future<void> salvarAtendimentoFirestore(
    Map<String, String> atendimento,
  ) async {
    try {
      await firestore
          .collection('atendimentos')
          .add(tenantFirestore.prepararCriacaoTexto(atendimento));
      logInfoSeguro('Atendimento salvo no Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao salvar atendimento.', e);
      mostrarMensagem('Erro ao salvar atendimento no Firebase');
    }
  }

  Future<void> salvarMaterialFirestore(Map<String, String> material) async {
    try {
      await firestore
          .collection('materiais')
          .add(tenantFirestore.prepararCriacaoTexto(material));
      logInfoSeguro('Material salvo no Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao salvar material.', e);
      mostrarMensagem('Erro ao salvar material no Firebase');
    }
  }

  Future<void> carregarMateriaisFirestore() async {
    try {
      if (widget.escopoTenant.ehPaciente) {
        setState(materiais.clear);
        return;
      }

      final resultado = await tenantFirestore
          .consultaClinica('materiais')
          .get();

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

      logInfoSeguro('Materiais carregados do Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao carregar materiais.', e);
      mostrarMensagem('Erro ao carregar materiais');
    }
  }

  Future<ArquivoUploadResultado?> uploadArquivo(
    PlatformFile arquivo, {
    String pasta = 'arquivos',
    String? pacienteId,
    bool obterUrlDownload = true,
  }) async {
    final controller = UploadProgressController(
      titulo: 'Enviando arquivo',
      mensagem: 'Preparando arquivo para envio...',
    );
    var dialogoAberto = false;
    Reference? referenciaEnviada;
    var uploadConcluido = false;
    var etapaUpload = 'preparacao';

    try {
      if (arquivo.bytes == null) {
        mostrarMensagem('Não foi possível ler o arquivo.');
        return null;
      }

      unawaited(_abrirDialogoUpload(controller));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      dialogoAberto = true;

      final usuarioUpload = FirebaseAuth.instance.currentUser;
      if (usuarioUpload == null) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'unauthenticated',
        );
      }

      final nomeArquivo =
          '${DateTime.now().millisecondsSinceEpoch}_${nomeArquivoSeguro(arquivo.name)}';

      etapaUpload = 'escopo';
      final ref = storage.ref().child(
        tenantFirestore.caminhoStorage('$pasta/$nomeArquivo'),
      );
      referenciaEnviada = ref;

      etapaUpload = 'validacao';
      final metadados = metadadosUpload(arquivo, pacienteId: pacienteId);

      controller.preparing(
        titulo: 'Enviando arquivo',
        mensagem: 'Iniciando envio de ${arquivo.name}...',
      );

      controller.uploading(
        0.1,
        titulo: 'Enviando arquivo',
        mensagem: 'Enviando ${arquivo.name}...',
      );

      // O SDK de Storage administra o token da sessão. Forçar uma renovação
      // imediatamente antes do putData criava uma segunda operação assíncrona
      // no Web e podia interromper o envio antes da primeira requisição.
      etapaUpload = 'envio';
      await ref.putData(arquivo.bytes!, metadados);
      uploadConcluido = true;

      final url = obterUrlDownload ? await ref.getDownloadURL() : '';

      controller.success(
        titulo: 'Upload concluído',
        mensagem: '${arquivo.name} foi enviado com sucesso.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));

      logInfoSeguro('Arquivo enviado com sucesso.');

      return ArquivoUploadResultado(url: url, caminho: ref.fullPath);
    } on FirebaseException catch (e) {
      if (uploadConcluido && referenciaEnviada != null) {
        try {
          await referenciaEnviada.delete();
        } catch (erroRemocao) {
          logErroSeguro(
            'Falha ao remover arquivo após erro de finalização do upload.',
            erroRemocao,
          );
        }
      }

      final mensagem = mensagemErroUpload(e.code);
      logErroSeguro('Erro do Firebase Storage no upload.', e.code);
      controller.error(titulo: 'Erro no upload', mensagem: mensagem);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      mostrarMensagem(mensagem);
      return null;
    } on FormatException catch (e) {
      final mensagem = e.message;
      logErroSeguro('Arquivo recusado antes do upload.', e);
      controller.error(titulo: 'Arquivo não enviado', mensagem: mensagem);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      mostrarMensagem(mensagem);
      return null;
    } on TenantScopeException catch (e) {
      final mensagem = e.message;
      logErroSeguro('Escopo recusado antes do upload.', e);
      controller.error(titulo: 'Arquivo não enviado', mensagem: mensagem);
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      mostrarMensagem(mensagem);
      return null;
    } catch (e) {
      logErroSeguro('Erro no upload.', e);
      final codigoSeguro = 'U-${etapaUpload.toUpperCase()}';
      controller.error(
        titulo: 'Erro no upload',
        mensagem:
            'Não foi possível iniciar o envio. Código de diagnóstico: $codigoSeguro.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      mostrarMensagem('Não foi possível enviar o comprovante ($codigoSeguro).');
      return null;
    } finally {
      if (dialogoAberto) {
        await _fecharDialogoUpload();
      }
      controller.dispose();
    }
  }

  Future<void> removerUploadOrfao(
    ArquivoUploadResultado upload,
    String contexto,
  ) async {
    try {
      await storage.ref(upload.caminho).delete();
    } catch (e) {
      logErroSeguro('Falha ao remover upload órfão de $contexto.', e);
    }
  }

  Future<void> abrirDocumento(String url) async {
    try {
      final uri = uriHttpsExternaSegura(url);
      if (uri == null) {
        mostrarMensagem('Link do documento inválido ou não seguro.');
        return;
      }

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Não foi possível abrir o documento';
      }
    } catch (e) {
      logErroSeguro('Erro ao abrir documento.', e);
      mostrarMensagem('Erro ao abrir documento');
    }
  }

  Future<void> carregarDocumentosFirestore() async {
    try {
      final resultado = await tenantFirestore
          .consultaDoPaciente('documentos', campoUid: 'uidGestante')
          .get();

      final listaFirebase = resultado.docs.map((doc) {
        final dados = identidadePacienteCanonica(
          doc.data(),
          pacienteId: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.pacienteId
              : null,
          pacienteUid: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.uidUsuario
              : null,
        );

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

      logInfoSeguro('Documentos carregados do Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao carregar documentos.', e);
      mostrarMensagem('Erro ao carregar documentos');
    }
  }

  Future<void> excluirDocumento(Map<String, String> doc) async {
    if (!usuarioEhAdmin()) {
      mostrarMensagem('Somente o administrador pode excluir documentos.');
      return;
    }

    try {
      final id = doc['id'];
      final url = doc['arquivoUrl'];

      if (id != null && id.isNotEmpty) {
        await firestore.collection('documentos').doc(id).delete();
      }

      if (url != null && url.isNotEmpty) {
        final ref = storage.refFromURL(url);
        try {
          await ref.delete();
        } catch (e) {
          logErroSeguro('Falha ao remover arquivo orfao do documento.', e);
        }
      }

      setState(() {
        documentos.removeWhere((d) => d['id'] == id);
      });

      mostrarMensagem('Documento excluído com sucesso');
    } catch (e) {
      logErroSeguro('Erro ao excluir documento.', e);
      mostrarMensagem('Erro ao excluir documento');
    }
  }

  List<Map<String, String>> montarLancamentosFinanceiros(
    Map<String, String> gestante,
  ) {
    final nome = gestante['nomeGestante'] ?? '';
    final gestanteId = (gestante['id'] ?? '').trim();
    final uidGestante = (gestante['uidGestante'] ?? '').trim();
    if (gestanteId.isEmpty) {
      throw ArgumentError.value(gestanteId, 'pacienteId', 'ID vazio.');
    }

    final quantidadeParcelas = (int.tryParse(gestante['parcelas'] ?? '1') ?? 1)
        .clamp(1, 24)
        .toInt();
    final valorParcela = gestante['valorParcela'] ?? 'R\$ 0,00';
    final valorEntrada = gestante['entrada'] ?? 'R\$ 0,00';
    final parcelasPagas = int.tryParse(gestante['parcelasPagas'] ?? '0') ?? 0;
    final saldoParcelado =
        converterValor(gestante['valorPlano'] ?? '0') -
        converterValor(gestante['valorDesconto'] ?? '0') -
        converterValor(valorEntrada);
    final valoresParcelas = saldoParcelado > 0
        ? fincalc.distribuirSaldoEmParcelas(saldoParcelado, quantidadeParcelas)
        : List<double>.filled(quantidadeParcelas, converterValor(valorParcela));

    if (valoresParcelas.every((valor) => valor <= 0) &&
        converterValor(valorEntrada) <= 0) {
      logInfoSeguro('Lancamento financeiro ignorado: valor ausente.');
      return const [];
    }

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
        'pacienteId': gestanteId,
        'gestanteId': gestanteId,
        'idGestante': gestanteId,
        'uidPaciente': uidGestante,
        'uidGestante': uidGestante,
        'tipo': tipo,
        'numero': numero,
        'descricao': descricao,
        'valor': valor,
        'vencimento': vencimento,
        'status': status,
        'comprovanteNome': '',
        'comprovanteUrl': '',
        'dataPagamento': '',
      };
    }

    final lancamentos = <Map<String, String>>[];
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
      lancamentos.add(entradaFinanceira);
    }

    for (int i = 1; i <= quantidadeParcelas; i++) {
      final novaParcela = baseFinanceira(
        tipo: 'parcela',
        numero: i.toString(),
        descricao: '$iª Parcela',
        valor: formatarMoeda(valoresParcelas[i - 1]),
        vencimento: gerarVencimentoParcelaHistorico(i, parcelasPagas),
        status: i <= parcelasPagas ? 'Pago' : 'Pendente',
      );
      lancamentos.add(novaParcela);
    }

    return lancamentos;
  }

  Future<void> gerarParcelasDaGestante(Map<String, String> gestante) async {
    final gestanteId = (gestante['id'] ?? '').trim();
    final parcelasExistentes = await tenantFirestore
        .consultaRegistrosDoPaciente(
          'parcelas',
          pacienteId: gestanteId,
          campoId: 'gestanteId',
        )
        .get();

    if (parcelasExistentes.docs.isNotEmpty) {
      logInfoSeguro('Parcelas ja existem para este paciente.');
      return;
    }

    final lancamentos = montarLancamentosFinanceiros(gestante);
    if (lancamentos.isEmpty) return;

    final lote = firestore.batch();
    for (final lancamento in lancamentos) {
      final parcelaRef = firestore.collection('parcelas').doc();
      lote.set(parcelaRef, tenantFirestore.prepararCriacaoTexto(lancamento));
    }
    await lote.commit();

    if (mounted) {
      setState(() => parcelasFinanceiras.addAll(lancamentos));
    }
  }

  Future<void> carregarParcelasFirestore() async {
    try {
      final resultado = await tenantFirestore
          .consultaDoPaciente('parcelas', campoUid: 'uidGestante')
          .get();

      final listaFirebase = resultado.docs.map((doc) {
        final dados = identidadePacienteCanonica(
          doc.data(),
          pacienteId: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.pacienteId
              : null,
          pacienteUid: widget.escopoTenant.ehPaciente
              ? widget.escopoTenant.uidUsuario
              : null,
        );

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

      logInfoSeguro('Parcelas carregadas do Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao carregar parcelas.', e);
      mostrarMensagem('Erro ao carregar parcelas');
    }
  }

  String gerarVencimentoEntradaHistorico(int parcelasPagas) =>
      fincalc.gerarVencimentoEntradaHistorico(parcelasPagas);

  String rotuloParcelaFinanceira(Map<String, String> parcela) =>
      fincalc.rotuloParcelaFinanceira(parcela);

  List<Map<String, String>> parcelasDaGestanteFicha(Map<String, String> g) {
    final nomeGestante = (g['nomeGestante'] ?? '').trim();
    final gestanteId = (g['id'] ?? '').trim();

    final lista = parcelasFinanceiras.where((p) {
      final parcelaGestante = (p['gestante'] ?? '').trim();
      final parcelaGestanteId = pacienteIdDoRegistro(p);

      final pertencePaciente =
          (nomeGestante.isNotEmpty && parcelaGestante == nomeGestante) ||
          (gestanteId.isNotEmpty && parcelaGestanteId == gestanteId);
      return pertencePaciente && fincalc.lancamentoFinanceiroValido(p);
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
      if (filtro(parcela) && fincalc.lancamentoFinanceiroValido(parcela)) {
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

    return 'Pendente';
  }

  Color corStatusParcelaPremium(Map<String, String> parcela) {
    final status = textoStatusParcelaPremium(parcela);

    if (status == 'Paga') return Colors.green;
    if (status == 'Vencida') return Colors.red;

    return Colors.orange;
  }

  IconData iconeStatusParcelaPremium(Map<String, String> parcela) {
    final status = textoStatusParcelaPremium(parcela);

    if (status == 'Paga') return Icons.check_circle;
    if (status == 'Vencida') return Icons.warning_rounded;

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

  Widget cardParcelaFinanceiraGestante(Map<String, String> parcela) {
    final cor = corStatusParcelaPremium(parcela);
    final status = textoStatusParcelaPremium(parcela);

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

    return blocoFicha('Financeiro do paciente', [
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
            'Nenhuma parcela encontrada para este paciente.',
            style: TextStyle(color: NatusApp.textoSuave),
          ),
        )
      else
        ...parcelas.map(cardParcelaFinanceiraGestante),
    ]);
  }

  Future<void> salvarContracaoFirestore(Map<String, String> contracao) async {
    try {
      await firestore
          .collection('contracoes')
          .add(tenantFirestore.prepararCriacaoTexto(contracao));

      logInfoSeguro('Atualizacao clinica salva no Firebase.');
    } catch (e) {
      logErroSeguro('Erro ao salvar atualizacao clinica.', e);
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

    String descontoSelecionado = '0%';
    DateTime dataQuitacaoSelecionada = DateTime.now();

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
                    OutlinedButton.icon(
                      onPressed: () async {
                        final dataEscolhida = await showDatePicker(
                          context: context,
                          initialDate: dataQuitacaoSelecionada,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );

                        if (dataEscolhida == null) return;
                        setDialogState(() {
                          dataQuitacaoSelecionada = dataEscolhida;
                        });
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        'Data da quitação: '
                        '${dataQuitacaoSelecionada.day.toString().padLeft(2, '0')}/'
                        '${dataQuitacaoSelecionada.month.toString().padLeft(2, '0')}/'
                        '${dataQuitacaoSelecionada.year}',
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
      dataQuitacaoSelecionada,
    );
  }

  Future<void> quitarParcelasGestante(
    List<Map<String, String>> pendentes,
    String nomeGestante,
    double percentualDesconto,
    double valorFinal,
    DateTime dataQuitacao,
  ) async {
    final horarioAtual = DateTime.now();
    final dataPagamento = formatarDataHora(
      DateTime(
        dataQuitacao.year,
        dataQuitacao.month,
        dataQuitacao.day,
        horarioAtual.hour,
        horarioAtual.minute,
      ),
    );
    final descontoTexto = '${percentualDesconto.toStringAsFixed(0)}%';

    final batch = firestore.batch();
    var comId = 0;
    final totalOriginalCentavos = pendentes.fold<int>(0, (total, parcela) {
      return total + (converterValor(parcela['valor'] ?? '0') * 100).round();
    });
    final valorFinalCentavos = (valorFinal * 100).round();
    var centavosDistribuidos = 0;

    for (var indice = 0; indice < pendentes.length; indice++) {
      final p = pendentes[indice];
      final valorParcelaCentavos = (converterValor(p['valor'] ?? '0') * 100)
          .round();
      final valorRecebidoCentavos = indice == pendentes.length - 1
          ? valorFinalCentavos - centavosDistribuidos
          : totalOriginalCentavos == 0
          ? 0
          : valorFinalCentavos * valorParcelaCentavos ~/ totalOriginalCentavos;
      centavosDistribuidos += valorRecebidoCentavos;
      final valorRecebido = formatarMoeda(valorRecebidoCentavos / 100);
      final id = p['id'];
      if (id != null && id.isNotEmpty) {
        batch.update(firestore.collection('parcelas').doc(id), {
          'status': 'Pago',
          'dataPagamento': dataPagamento,
          'quitacaoAntecipada': 'true',
          'descontoQuitacao': descontoTexto,
          'valorRecebido': valorRecebido,
        });
        comId++;
      }
      p['valorRecebido'] = valorRecebido;
    }

    if (comId > 0) {
      await batch.commit();
    }

    setState(() {
      for (final p in pendentes) {
        p['status'] = 'Pago';
        p['dataPagamento'] = dataPagamento;
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
    final id = chaveParcelaFinanceira(parcela);
    if (id.isEmpty) {
      mostrarMensagem('Não foi possível identificar a parcela.');
      return;
    }

    if (!usuarioEhAdmin()) {
      mostrarMensagem(
        'Somente o administrador da clínica pode enviar comprovantes.',
      );
      return;
    }

    if (parcelasComUploadEmAndamento.contains(id)) {
      mostrarMensagem('O comprovante desta parcela já está sendo enviado.');
      return;
    }

    final arquivo = comprovantesSelecionados[id];
    if (arquivo == null) {
      mostrarMensagem('Selecione o comprovante antes de dar baixa.');
      return;
    }

    String pacienteId;
    try {
      pacienteId = pacienteIdDoRegistro(parcela);
    } on FormatException {
      mostrarMensagem('A parcela possui um vínculo de paciente inconsistente.');
      return;
    }
    if (pacienteId.isEmpty) {
      mostrarMensagem('Não foi possível identificar o paciente da parcela.');
      return;
    }

    mostrarMensagem('Enviando comprovante...');
    setState(() => parcelasComUploadEmAndamento.add(id));

    try {
      final upload = await uploadArquivo(
        arquivo,
        pasta: 'financeiro/pacientes/$pacienteId/comprovantes',
        pacienteId: pacienteId,
        obterUrlDownload: false,
      );

      if (upload == null) return;

      final dataPagamento = formatarDataHora(DateTime.now());
      final dadosAtualizados = <String, String>{
        'status': 'Pago',
        'comprovanteNome': arquivo.name,
        'comprovanteCaminho': upload.caminho,
        'dataPagamento': dataPagamento,
        'valorRecebido': parcela['valor'] ?? 'R\$ 0,00',
      };

      try {
        await firestore
            .collection('parcelas')
            .doc(id)
            .update(tenantFirestore.prepararAtualizacaoTexto(dadosAtualizados));
      } catch (e) {
        await removerUploadOrfao(upload, 'comprovante');
        logErroSeguro('Erro ao registrar a baixa da parcela.', e);
        mostrarMensagem(
          'A baixa não foi salva e o comprovante enviado foi removido.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        parcela.addAll(dadosAtualizados);
        comprovantesSelecionados.remove(id);
      });

      mostrarMensagem('Parcela baixada com sucesso!');
    } finally {
      parcelasComUploadEmAndamento.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> abrirComprovanteParcela(Map<String, String> parcela) async {
    final caminho = (parcela['comprovanteCaminho'] ?? '').trim();
    if (caminho.isNotEmpty) {
      try {
        final urlAtual = await storage.ref(caminho).getDownloadURL();
        await abrirDocumento(urlAtual);
        return;
      } catch (e) {
        logErroSeguro('Erro ao obter comprovante autenticado.', e);
        mostrarMensagem('Não foi possível acessar o comprovante.');
        return;
      }
    }

    final urlLegada = (parcela['comprovanteUrl'] ?? '').trim();
    if (urlLegada.isEmpty) {
      mostrarMensagem('Comprovante não encontrado.');
      return;
    }
    await abrirDocumento(urlLegada);
  }

  Map<String, String>? pacienteDaParcelaFinanceira(
    Map<String, String> parcela,
  ) {
    final pacienteId = pacienteIdDoRegistro(parcela);
    final nomePaciente = (parcela['gestante'] ?? '').trim().toLowerCase();

    for (final paciente in gestantes) {
      if (pacienteId.isNotEmpty && (paciente['id'] ?? '') == pacienteId) {
        return paciente;
      }

      final nomeCadastrado = (paciente['nomeGestante'] ?? '')
          .trim()
          .toLowerCase();
      if (nomePaciente.isNotEmpty && nomeCadastrado == nomePaciente) {
        return paciente;
      }
    }

    return null;
  }

  void abrirAlteracaoParcelas(Map<String, String> parcela) {
    final paciente = pacienteDaParcelaFinanceira(parcela);
    if (paciente == null) {
      mostrarMensagem('Paciente vinculado à parcela não encontrado.');
      return;
    }

    abrirPopupEditarSecaoGestante(paciente, 'Valores');
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

    sheet.appendRow([excel.TextCellValue('Relatório Financeiro - Natus')]);

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
      excel.TextCellValue('Paciente'),
      excel.TextCellValue('Parcela'),
      excel.TextCellValue('Valor'),
      excel.TextCellValue('Vencimento'),
      excel.TextCellValue('Status'),
      excel.TextCellValue('Comprovante'),
      excel.TextCellValue('Data pagamento'),
    ]);

    final parcelasDoMes = parcelasFinanceiras.where((p) {
      return lancamentoFinanceiroVisivelNoPeriodo(p);
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

    final nomeArquivo =
        'natus_financeiro_${anoSelecionado}_${mesSelecionado.toString().padLeft(2, '0')}.xlsx';

    try {
      final salvo = await salvarArquivo(
        nome: nomeArquivo,
        bytes: Uint8List.fromList(bytes),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        extensoesPermitidas: const ['xlsx'],
      );

      if (salvo) {
        mostrarMensagem('Relatório financeiro exportado com sucesso.');
      }
    } catch (erro) {
      logErroSeguro('Erro ao salvar relatorio.', erro);
      mostrarMensagem('Não foi possível salvar o relatório.');
    }
  }

  Widget telaFinanceiro() {
    final parcelasDoMes = parcelasFinanceiras.where((p) {
      return lancamentoFinanceiroVisivelNoPeriodo(p);
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

          NatusCardsResumoLayout(
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
                  comprovanteSelecionadoNome:
                      comprovantesSelecionados[chaveParcelaFinanceira(p)]
                          ?.name ??
                      '',
                  processando: parcelasComUploadEmAndamento.contains(
                    chaveParcelaFinanceira(p),
                  ),
                  onAbrirComprovante: () async {
                    await abrirComprovanteParcela(p);
                  },
                  onSelecionarComprovante: () async {
                    await selecionarComprovanteParcela(p);
                  },
                  onDarBaixa: () async {
                    await darBaixaParcela(p);
                  },
                  onAlterarParcelas: () {
                    abrirAlteracaoParcelas(p);
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
    final pacientesObstetricia = gestantes
        .where(pacienteTemModuloObstetrico)
        .toList(growable: false);
    final resumo = DashboardClinicaResumo.calcular(
      gestantes,
      mes: mesSelecionado,
      ano: anoSelecionado,
    );
    final pacientesPorPlano = contarGestantesAtivasPorPlano();
    final recebidoMes = calcularValorRecebidoMesAtual();
    final aReceberMes = calcularValorAReceberReal();
    final atrasadoMes = calcularValorAtrasadoMesAtual();

    final alertas = <Widget>[
      if (usuarioEhAdmin())
        cardAlertaDashboard(
          'Parcelas atrasadas',
          '${contarParcelasAtrasadasMesSelecionado()} parcela(s)',
          Icons.warning_amber_rounded,
          Colors.red,
          onTap: () => abrirFinanceiroDoDashboard('Atrasados'),
        ),
      if (resumo.pacientesSemEspecialidade > 0)
        cardAlertaDashboard(
          'Especialidade pendente',
          '${resumo.pacientesSemEspecialidade} paciente(s)',
          Icons.category_outlined,
          Colors.orange,
          onTap: () => abrirPacientesDoDashboard(
            const FiltroDashboardPacientes(
              tipo: TipoFiltroDashboardPacientes.semEspecialidade,
              titulo: 'Pacientes sem especialidade',
            ),
          ),
        ),
      if (resumo.pacientesSemProfissional > 0)
        cardAlertaDashboard(
          'Profissional não vinculado',
          '${resumo.pacientesSemProfissional} paciente(s)',
          Icons.person_search_rounded,
          Colors.orange,
          onTap: () => abrirPacientesDoDashboard(
            const FiltroDashboardPacientes(
              tipo: TipoFiltroDashboardPacientes.semProfissional,
              titulo: 'Pacientes sem profissional responsável',
            ),
          ),
        ),
      if (resumo.possuiModuloObstetricia)
        cardAlertaDashboard(
          'DPP próxima',
          '${contarGestantesProximasDpp(pacientesObstetricia)} paciente(s)',
          Icons.event_available_rounded,
          NatusApp.marsala,
          onTap: () => abrirPacientesDoDashboard(
            const FiltroDashboardPacientes(
              tipo: TipoFiltroDashboardPacientes.dppProxima,
              titulo: 'DPP próxima',
            ),
          ),
        ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(NatusBreakpoints.isPhone(context) ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NatusSaudacaoDashboard(
            nomeEoLogada().trim().isEmpty ? 'equipe Natus' : nomeEoLogada(),
            subtitulo: 'Visão geral da clínica',
          ),
          const SizedBox(height: 16),
          NatusFiltroPeriodoDashboard(
            mes: mesSelecionado,
            ano: anoSelecionado,
            onMesAlterado: (mes) => setState(() => mesSelecionado = mes),
            onAnoAlterado: (ano) => setState(() => anoSelecionado = ano),
          ),
          const SizedBox(height: 20),
          blocoDashboard('Visão geral da clínica', [
            NatusCardsResumoLayout(
              children: [
                cardContagemResumo(
                  'Pacientes cadastrados',
                  resumo.totalPacientes,
                  NatusApp.vinho,
                  Icons.people_alt_rounded,
                  onTap: () => abrirPacientesDoDashboard(
                    const FiltroDashboardPacientes(
                      tipo: TipoFiltroDashboardPacientes.todos,
                      titulo: 'Todos os pacientes',
                    ),
                  ),
                ),
                cardContagemResumo(
                  'Pacientes ativos',
                  resumo.pacientesAtivos,
                  NatusApp.olivaSeco,
                  Icons.favorite_outline_rounded,
                  onTap: () => abrirPacientesDoDashboard(
                    const FiltroDashboardPacientes(
                      tipo: TipoFiltroDashboardPacientes.ativos,
                      titulo: 'Pacientes ativos',
                    ),
                  ),
                ),
                cardContagemResumo(
                  'Novos no período',
                  resumo.cadastrosNoPeriodo,
                  Colors.blueGrey,
                  Icons.person_add_alt_1_rounded,
                  onTap: () => abrirPacientesDoDashboard(
                    FiltroDashboardPacientes(
                      tipo: TipoFiltroDashboardPacientes.cadastroNoPeriodo,
                      titulo:
                          'Novos pacientes em ${nomeMes(mesSelecionado)} / $anoSelecionado',
                      mes: mesSelecionado,
                      ano: anoSelecionado,
                    ),
                  ),
                ),
                cardContagemResumo(
                  'Acompanhamentos encerrados',
                  resumo.acompanhamentosEncerrados,
                  Colors.green,
                  Icons.task_alt_rounded,
                  onTap: () => abrirPacientesDoDashboard(
                    const FiltroDashboardPacientes(
                      tipo: TipoFiltroDashboardPacientes.encerrados,
                      titulo: 'Acompanhamentos encerrados',
                    ),
                  ),
                ),
                cardContagemResumo(
                  'Especialidades ativas',
                  resumo.especialidadesAtivas,
                  NatusApp.douradoEscuro,
                  Icons.medical_information_outlined,
                ),
              ],
            ),
          ]),
          blocoDashboard('Carteira por especialidade', [
            if (resumo.pacientesAtivosPorEspecialidade.isEmpty)
              Text(
                'Nenhum paciente ativo no momento.',
                style: TextStyle(color: NatusApp.textoSuave),
              )
            else
              NatusCardsResumoLayout(
                children: resumo.pacientesAtivosPorEspecialidade
                    .map(
                      (item) => cardContagemResumo(
                        item.key,
                        item.value,
                        item.key == especialidadeNaoInformadaDashboard
                            ? Colors.orange
                            : NatusApp.marsala,
                        Icons.health_and_safety_outlined,
                        onTap: () => abrirPacientesDoDashboard(
                          FiltroDashboardPacientes(
                            tipo: TipoFiltroDashboardPacientes.especialidade,
                            titulo: 'Pacientes de ${item.key}',
                            valor: item.key,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ]),
          if (alertas.isNotEmpty)
            blocoDashboard('Central de atenção', [
              NatusCardsResumoLayout(children: alertas),
            ]),
          blocoDashboard('Pacientes ativos por plano', [
            if (pacientesPorPlano.isEmpty)
              Text(
                'Nenhum paciente ativo com plano identificado no momento.',
                style: TextStyle(color: NatusApp.textoSuave),
              )
            else
              NatusCardsResumoLayout(
                children: pacientesPorPlano
                    .map(
                      (item) => cardContagemResumo(
                        item.key,
                        item.value,
                        NatusApp.olivaSeco,
                        Icons.workspace_premium_rounded,
                        onTap: () => abrirGestantesPorPlanoDashboard(item.key),
                      ),
                    )
                    .toList(),
              ),
          ]),
          blocoDashboard('Distribuição por profissional responsável', [
            if (resumo.pacientesAtivosPorProfissional.isEmpty)
              Text(
                'Nenhum profissional está vinculado aos pacientes ativos.',
                style: TextStyle(color: NatusApp.textoSuave),
              )
            else
              NatusCardsResumoLayout(
                children: resumo.pacientesAtivosPorProfissional
                    .map(
                      (item) => cardContagemResumo(
                        item.key,
                        item.value,
                        NatusApp.vinho,
                        Icons.badge_outlined,
                        onTap: () => abrirPacientesDoDashboard(
                          FiltroDashboardPacientes(
                            tipo: TipoFiltroDashboardPacientes
                                .profissionalResponsavel,
                            titulo: 'Pacientes de ${item.key}',
                            valor: item.key,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ]),
          if (usuarioEhAdmin())
            blocoDashboard('Financeiro do período', [
              NatusCardsResumoLayout(
                children: [
                  cardFinanceiroResumo(
                    'Recebido',
                    recebidoMes,
                    Colors.green,
                    Icons.check_circle_rounded,
                    onTap: () => abrirFinanceiroDoDashboard('Pagos'),
                  ),
                  cardFinanceiroResumo(
                    'A receber',
                    aReceberMes,
                    Colors.orange,
                    Icons.pending_actions_rounded,
                    onTap: () => abrirFinanceiroDoDashboard('Pendentes'),
                  ),
                  cardFinanceiroResumo(
                    'Atrasado',
                    atrasadoMes,
                    Colors.red,
                    Icons.warning_rounded,
                    onTap: () => abrirFinanceiroDoDashboard('Atrasados'),
                  ),
                  cardFinanceiroResumo(
                    'Inadimplência',
                    calcularPercentualInadimplencia(),
                    corInadimplencia(calcularPercentualInadimplencia()),
                    Icons.percent_rounded,
                    sufixo: '%',
                    onTap: () => abrirFinanceiroDoDashboard('Atrasados'),
                  ),
                ],
              ),
            ]),
          if (resumo.possuiModuloObstetricia)
            NatusModuloDashboard(
              titulo: 'Módulo Obstetrícia',
              subtitulo:
                  '${resumo.pacientesObstetricia} paciente(s) com acompanhamento obstétrico',
              icone: Icons.pregnant_woman_rounded,
              inicialmenteAberto: widget.tipoUsuario == 'obstetra',
              children: _conteudoModuloObstetriciaDashboard(
                pacientesObstetricia,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _conteudoModuloObstetriciaDashboard(
    List<Map<String, String>> pacientesObstetricia,
  ) {
    final amamentacaoDados = contarAmamentacao(pacientesObstetricia);
    final crescimentoNascimentos = calcularCrescimentoNascimentos(
      pacientesObstetricia,
    );
    final viaNascimentoDados = contarViaNascimento(pacientesObstetricia);
    final riscoDados = contarRiscoGestacional(pacientesObstetricia);
    final dgDados = contarDiabetesGestacional(pacientesObstetricia);
    final maternidades =
        mregras
            .contarPacientesPorMaternidade(pacientesObstetricia)
            .entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return [
      blocoDashboard('Status do acompanhamento obstétrico', [
        NatusCardsResumoLayout(
          children: [
            cardContagemResumo(
              'DPP no período',
              contarGestantesPorStatusNoPeriodoDpp(
                'Gestante',
                pacientesObstetricia,
              ),
              NatusApp.marsala,
              Icons.event_rounded,
              onTap: () => abrirPacientesDoDashboard(
                FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.statusNoPeriodo,
                  titulo: 'DPP em ${nomeMes(mesSelecionado)} / $anoSelecionado',
                  valor: 'Gestante',
                  mes: mesSelecionado,
                  ano: anoSelecionado,
                ),
              ),
            ),
            cardContagemResumo(
              'Pós-parto no período',
              contarGestantesPorStatusNoPeriodoDpp(
                'Puérpera',
                pacientesObstetricia,
              ),
              Colors.orange,
              Icons.child_friendly_rounded,
              onTap: () => abrirPacientesDoDashboard(
                FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.statusNoPeriodo,
                  titulo:
                      'Pós-parto em ${nomeMes(mesSelecionado)} / $anoSelecionado',
                  valor: 'Puérpera',
                  mes: mesSelecionado,
                  ano: anoSelecionado,
                ),
              ),
            ),
            cardContagemResumo(
              'Encerrados no período',
              contarEncerradasOuHistoricoNoPeriodoDpp(pacientesObstetricia),
              Colors.green,
              Icons.task_alt_rounded,
              onTap: () => abrirPacientesDoDashboard(
                FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes
                      .encerradasOuHistoricoNoPeriodo,
                  titulo: 'Acompanhamentos obstétricos encerrados no período',
                  mes: mesSelecionado,
                  ano: anoSelecionado,
                ),
              ),
            ),
          ],
        ),
      ]),
      blocoDashboard('Risco gestacional (pré-natal)', [
        NatusCardsResumoLayout(
          children: [
            cardContagemResumo(
              'Risco habitual',
              riscoDados['Habitual'] ?? 0,
              Colors.green,
              Icons.verified_user_outlined,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.riscoGestacional,
                  titulo: 'Risco habitual',
                  valor: 'Habitual',
                ),
              ),
            ),
            cardContagemResumo(
              'Risco intermediário',
              riscoDados['Intermediário'] ?? 0,
              Colors.orange,
              Icons.report_problem_outlined,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.riscoGestacional,
                  titulo: 'Risco intermediário',
                  valor: 'Intermediário',
                ),
              ),
            ),
            cardContagemResumo(
              'Alto risco',
              riscoDados['Alto Risco'] ?? 0,
              Colors.red,
              Icons.emergency_outlined,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.riscoGestacional,
                  titulo: 'Alto risco',
                  valor: 'Alto Risco',
                ),
              ),
            ),
          ],
        ),
      ]),
      blocoDashboard('Diabetes gestacional', [
        NatusCardsResumoLayout(
          children: [
            cardContagemResumo(
              'Com diabetes gestacional',
              dgDados['Sim'] ?? 0,
              Colors.red,
              Icons.bloodtype_outlined,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.diabetesGestacional,
                  titulo: 'Com diabetes gestacional',
                  valor: 'Sim',
                ),
              ),
            ),
            cardContagemResumo(
              'Sem diabetes gestacional',
              dgDados['Não'] ?? 0,
              Colors.green,
              Icons.health_and_safety_outlined,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.diabetesGestacional,
                  titulo: 'Sem diabetes gestacional',
                  valor: 'Não',
                ),
              ),
            ),
          ],
        ),
      ]),
      blocoDashboard('Nascimentos', [
        NatusCardsResumoLayout(
          children: [
            cardContagemResumo(
              'Nascimentos no período',
              contarBebesNoPeriodoSelecionado(pacientesObstetricia),
              Colors.purple,
              Icons.baby_changing_station_rounded,
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
            cardContagemResumo(
              'Nascimentos em $anoSelecionado',
              contarBebesPorAno(
                anoSelecionado.toString(),
                pacientesObstetricia,
              ),
              NatusApp.vinho,
              Icons.child_care_rounded,
              onTap: () => abrirPacientesDoDashboard(
                FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.nascimentoNoAno,
                  titulo: 'Nascimentos em $anoSelecionado',
                  ano: anoSelecionado,
                ),
              ),
            ),
            cardContagemResumo(
              'Total histórico',
              crescimentoNascimentos.totalHistorico,
              Colors.blueGrey,
              Icons.history_rounded,
            ),
          ],
        ),
      ]),
      blocoDashboard('Crescimento anual de nascimentos', [
        NatusPainelCrescimento(crescimentoNascimentos),
        const SizedBox(height: 22),
        NatusGraficoLinhaCrescimento(
          anos: crescimentoNascimentos.anosDisponiveis,
          dadosPorAno: {
            for (final ano in crescimentoNascimentos.anosDisponiveis)
              ano: contarBebesPorMes(ano.toString(), pacientesObstetricia),
          },
        ),
      ]),
      blocoDashboard('Amamentação', [
        NatusGraficoAmamentacao(amamentacaoDados),
      ]),
      blocoDashboard('Partos e cesáreas', [
        NatusCardsResumoLayout(
          children: [
            cardContagemResumo(
              'Partos normais',
              viaNascimentoDados['Normal'] ?? 0,
              Colors.green,
              Icons.favorite_outline_rounded,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.viaNascimento,
                  titulo: 'Partos normais',
                  valor: 'Normal',
                ),
              ),
            ),
            cardContagemResumo(
              'Cesáreas',
              viaNascimentoDados['Cesárea'] ?? 0,
              Colors.orange,
              Icons.local_hospital_outlined,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.viaNascimento,
                  titulo: 'Cesáreas',
                  valor: 'Cesárea',
                ),
              ),
            ),
            cardContagemResumo(
              'Via não informada',
              viaNascimentoDados['Não informado'] ?? 0,
              Colors.grey,
              Icons.help_outline_rounded,
              onTap: () => abrirPacientesDoDashboard(
                const FiltroDashboardPacientes(
                  tipo: TipoFiltroDashboardPacientes.viaNascimento,
                  titulo: 'Partos sem via informada',
                  valor: 'Não informado',
                ),
              ),
            ),
          ],
        ),
      ]),
      if (widget.tipoUsuario == 'obstetra')
        NatusBlocoMetricasObstetra(
          metricasDoObstetraLogado(pacientesObstetricia),
        )
      else
        blocoDashboard('Top 5 obstetras', [
          podiumTop5(
            dados: () {
              final lista = metricasDeTodosObstetras(pacientesObstetricia)
                  .map(
                    (metrica) =>
                        MapEntry(metrica.nomeObstetra, metrica.totalCarteira),
                  )
                  .where((item) => item.value > 0)
                  .toList();
              lista.sort((a, b) => b.value.compareTo(a.value));
              return lista.take(5).toList();
            }(),
            icone: Icons.medical_services_outlined,
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
          dados: maternidades.take(5).toList(),
          icone: Icons.local_hospital_outlined,
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
    ];
  }

  void mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}
