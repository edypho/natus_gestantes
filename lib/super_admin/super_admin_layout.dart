import 'package:flutter/material.dart';

const superAdminVinho = Color(0xFF7B3A44);
const superAdminFundoCard = Color(0xFFFFFCFB);

class SuperAdminPageScaffold extends StatelessWidget {
  const SuperAdminPageScaffold({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.icone,
    this.actions = const <Widget>[],
  });

  final String titulo;
  final String subtitulo;
  final Widget child;
  final IconData? icone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 700;
        final padding = compacto ? 16.0 : 28.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, 40),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SuperAdminPageHeader(
                    titulo: titulo,
                    subtitulo: subtitulo,
                    icone: icone,
                    actions: actions,
                    compacto: compacto,
                  ),
                  SizedBox(height: compacto ? 22 : 30),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuperAdminPageHeader extends StatelessWidget {
  const _SuperAdminPageHeader({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.actions,
    required this.compacto,
  });

  final String titulo;
  final String subtitulo;
  final IconData? icone;
  final List<Widget> actions;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tituloWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icone != null) ...[
          Container(
            width: compacto ? 44 : 52,
            height: compacto ? 44 : 52,
            decoration: BoxDecoration(
              color: superAdminVinho.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icone, color: superAdminVinho),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: compacto ? 25 : 32,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  color: superAdminVinho,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitulo,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: compacto ? 14 : 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (actions.isEmpty) return tituloWidget;
    if (compacto) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tituloWidget,
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: tituloWidget),
        const SizedBox(width: 20),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

class SuperAdminSectionCard extends StatelessWidget {
  const SuperAdminSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: superAdminFundoCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: superAdminVinho.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: superAdminVinho.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SuperAdminSectionTitle extends StatelessWidget {
  const SuperAdminSectionTitle({
    super.key,
    required this.titulo,
    this.descricao,
  });

  final String titulo;
  final String? descricao;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: superAdminVinho,
          ),
        ),
        if (descricao != null) ...[
          const SizedBox(height: 5),
          Text(
            descricao!,
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
        ],
      ],
    );
  }
}

class SuperAdminStateMessage extends StatelessWidget {
  const SuperAdminStateMessage({
    super.key,
    required this.mensagem,
    this.icone = Icons.inbox_outlined,
    this.erro = false,
  });

  final String mensagem;
  final IconData icone;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    final cor = erro ? Colors.red.shade700 : superAdminVinho;
    return SuperAdminSectionCard(
      child: Row(
        children: [
          Icon(icone, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class SuperAdminActionCard extends StatelessWidget {
  const SuperAdminActionCard({
    super.key,
    required this.titulo,
    required this.descricao,
    required this.icone,
    this.onTap,
  });

  final String titulo;
  final String descricao;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SuperAdminSectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: superAdminVinho.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icone, color: superAdminVinho),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      descricao,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded, color: superAdminVinho),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
