import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import '../shared/natus_logo.dart';
import '../shared/natus_premium_visual.dart';
import 'super_admin_navigation.dart';
import 'super_admin_router.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({
    super.key,
    required this.nomeUsuario,
    required this.emailUsuario,
    this.pageBuilder,
  });

  final String nomeUsuario;
  final String emailUsuario;
  final Widget Function(String destinoId)? pageBuilder;

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  String _destinoAtual = SuperAdminNavigation.destinos.first.id;

  SuperAdminDestination get _destino {
    return SuperAdminNavigation.resolver(_destinoAtual);
  }

  void _selecionar(String id) {
    setState(() => _destinoAtual = id);
  }

  Future<void> _sair() async {
    NatusTema.restaurarPadrao();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumNatusBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < 900;

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: compacto
                ? AppBar(
                    backgroundColor: NatusApp.offWhite.withValues(alpha: 0.96),
                    foregroundColor: NatusApp.vinho,
                    surfaceTintColor: Colors.transparent,
                    titleSpacing: 0,
                    title: Text(
                      _destino.rotulo,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                : null,
            drawer: compacto
                ? Drawer(
                    width: 300,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    child: _SuperAdminMenu(
                      destinoAtual: _destinoAtual,
                      nomeUsuario: widget.nomeUsuario,
                      emailUsuario: widget.emailUsuario,
                      onSelecionar: (id) {
                        Navigator.of(context).pop();
                        _selecionar(id);
                      },
                      onSair: _sair,
                    ),
                  )
                : null,
            body: Row(
              children: [
                if (!compacto)
                  _SuperAdminMenu(
                    destinoAtual: _destinoAtual,
                    nomeUsuario: widget.nomeUsuario,
                    emailUsuario: widget.emailUsuario,
                    onSelecionar: _selecionar,
                    onSair: _sair,
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey(_destinoAtual),
                      child:
                          widget.pageBuilder?.call(_destinoAtual) ??
                          SuperAdminRouter.tela(_destinoAtual),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SuperAdminMenu extends StatelessWidget {
  const _SuperAdminMenu({
    required this.destinoAtual,
    required this.nomeUsuario,
    required this.emailUsuario,
    required this.onSelecionar,
    required this.onSair,
  });

  final String destinoAtual;
  final String nomeUsuario;
  final String emailUsuario;
  final ValueChanged<String> onSelecionar;
  final VoidCallback onSair;

  String get _nomeExibicao {
    final nome = nomeUsuario.trim();
    return nome.isEmpty ? 'Super admin Natus' : nome;
  }

  String get _iniciais {
    final partes = _nomeExibicao
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NatusApp.menuTopo, NatusApp.menuMeio, NatusApp.menuBase],
        ),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: SizedBox(
                height: 112,
                child: NatusLogo(color: NatusApp.sobreMarca),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: NatusApp.offWhite,
                      foregroundColor: NatusApp.vinho,
                      child: Text(
                        _iniciais,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nomeExibicao,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            emailUsuario,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ADMINISTRAÇÃO DA PLATAFORMA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                children: SuperAdminNavigation.destinos.map((destino) {
                  final ativo = destino.id == destinoAtual;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelecionar(destino.id),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ativo
                                ? NatusApp.offWhite.withValues(alpha: 0.96)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                destino.icone,
                                size: 21,
                                color: ativo
                                    ? NatusApp.vinho
                                    : Colors.white.withValues(alpha: 0.86),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  destino.rotulo,
                                  style: TextStyle(
                                    color: ativo
                                        ? NatusApp.vinho
                                        : Colors.white.withValues(alpha: 0.92),
                                    fontWeight: ativo
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: OutlinedButton.icon(
                onPressed: onSair,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
