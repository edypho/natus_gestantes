import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/natus_app.dart';
import '../shared/natus_logo.dart';
import '../shared/natus_premium_visual.dart';
import 'autenticacao_mensagens.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;
  bool recuperandoSenha = false;

  bool get processando => carregando || recuperandoSenha;

  Future<void> fazerLogin() async {
    if (emailController.text.trim().isEmpty || senhaController.text.isEmpty) {
      mostrarErro('Informe e-mail e senha.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final credenciais = credenciaisAcesso(
        email: emailController.text,
        senha: senhaController.text,
      );
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: credenciais.email,
        password: credenciais.senha,
      );
    } on FirebaseAuthException catch (e) {
      mostrarErro(mensagemErroLogin(e.code));
    } catch (_) {
      mostrarErro(mensagemErroLogin(''));
    } finally {
      senhaController.clear();
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> solicitarRedefinicaoSenha() async {
    final email = normalizarEmailAcesso(emailController.text);
    if (!emailAcessoValido(email)) {
      mostrarErro('Informe um e-mail válido para redefinir a senha.');
      return;
    }

    setState(() => recuperandoSenha = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      mostrarErro(mensagemRedefinicaoSenhaSolicitada);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      mostrarErro(mensagemErroRedefinicaoSenha(e.code));
    } catch (_) {
      if (!mounted) return;
      mostrarErro(mensagemErroRedefinicaoSenha(''));
    } finally {
      if (mounted) {
        setState(() => recuperandoSenha = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  void mostrarErro(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> baixarAplicativoAndroid() async {
    final url = Uri.base.resolve('/downloads/natus-android-1.1.2.apk');
    final abriuDownload = await launchUrl(url, webOnlyWindowName: '_self');
    if (!abriuDownload && mounted) {
      mostrarErro('Não foi possível iniciar o download do aplicativo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumNatusBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final alturaMinima = constraints.maxHeight > 40
                  ? constraints.maxHeight - 40
                  : 0.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: alturaMinima),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: NatusApp.offWhite.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: NatusApp.vinho.withValues(alpha: 0.12),
                            blurRadius: 34,
                            spreadRadius: -12,
                            offset: const Offset(0, 22),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NatusLogo(height: 180),

                          const SizedBox(height: 24),

                          Text(
                            'Boas-vindas',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: NatusApp.vinho,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Cuidado, gestão e acolhimento em um só lugar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: NatusApp.textoSuave),
                          ),

                          const SizedBox(height: 24),

                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                            decoration: InputDecoration(
                              labelText: 'E-mail',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: senhaController,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => fazerLogin(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: processando
                                  ? null
                                  : solicitarRedefinicaoSenha,
                              child: recuperandoSenha
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Esqueci minha senha'),
                            ),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: processando ? null : fazerLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NatusApp.marsala,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: carregando
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),

                          if (kIsWeb) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: baixarAplicativoAndroid,
                                icon: const Icon(
                                  Icons.android_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Baixar aplicativo para Android',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: NatusApp.marsala,
                                  side: BorderSide(
                                    color: NatusApp.marsala.withValues(
                                      alpha: 0.32,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
