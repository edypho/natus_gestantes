import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/firebase_globals.dart';
import '../saas/contexto_saas.dart';
import '../saas/tenant_access_scope.dart';
import '../seguranca/log_seguro.dart';
import '../super_admin/primeiro_login_saas_dialog.dart';
import '../super_admin/primeiro_login_saas_guard.dart';
import '../super_admin/super_admin_access_guard.dart';
import '../super_admin/super_admin_shell.dart';
import 'tela_login.dart';

typedef TelaClinicaBuilder =
    Widget Function(
      ContextoSaaS contexto,
      TenantAccessScope escopoTenant,
      Map<String, dynamic> dadosUsuario,
    );

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.telaClinicaBuilder});

  final TelaClinicaBuilder telaClinicaBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _uidSessao;
  Future<List<dynamic>>? _dadosSessaoFuture;
  final Map<String, Future<bool>> _acessosFuture = {};

  Future<List<dynamic>> _dadosSessao(User user) {
    if (_uidSessao != user.uid || _dadosSessaoFuture == null) {
      _uidSessao = user.uid;
      _dadosSessaoFuture = Future.wait<dynamic>([
        firestore.collection('usuarios').doc(user.uid).get(),
        user.getIdTokenResult(true),
      ]);
      _acessosFuture.clear();
    }
    return _dadosSessaoFuture!;
  }

  Future<bool> _validarAcesso(User user, bool superAdminVerificado) {
    final chave = '${user.uid}:$superAdminVerificado';
    return _acessosFuture.putIfAbsent(
      chave,
      () => SuperAdminAccessGuard.usuarioPodeAcessar(
        uid: user.uid,
        superAdminVerificado: superAdminVerificado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      initialData: FirebaseAuth.instance.currentUser,
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const TelaLogin();

        final user = snapshot.data!;
        return FutureBuilder<List<dynamic>>(
          future: _dadosSessao(user),
          builder: (context, snapshotUser) {
            if (snapshotUser.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshotUser.hasError) {
              return const Scaffold(
                body: Center(child: Text('Não foi possível validar o acesso.')),
              );
            }

            final dadosSessao = snapshotUser.data;
            final usuarioDoc = dadosSessao == null
                ? null
                : dadosSessao[0] as DocumentSnapshot;
            if (usuarioDoc == null || !usuarioDoc.exists) {
              return const Scaffold(
                body: Center(child: Text('Usuário não configurado no sistema')),
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
              future: _validarAcesso(user, contextoSaaS.superAdmin),
              builder: (context, snapshotAcesso) {
                if (snapshotAcesso.connectionState == ConnectionState.waiting) {
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

                final telaPrincipal = contextoSaaS.superAdmin
                    ? SuperAdminShell(
                        nomeUsuario: contextoSaaS.nomeUsuario,
                        emailUsuario: contextoSaaS.emailUsuario,
                      )
                    : widget.telaClinicaBuilder(
                        contextoSaaS,
                        escopoTenant,
                        Map<String, dynamic>.unmodifiable(dados),
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
      if (!senhaAlterada || !mounted) return;
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
