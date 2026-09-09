import 'package:flutter/material.dart';

import '../shared/natus_app.dart';

/// Item de parcela do financeiro — layout da referência visual:
/// quadrado de data (dia + mês), gestante e parcela, valor à direita
/// com badge de status, ação principal visível e demais ações no menu.
class NatusParcelaItem extends StatelessWidget {
  final Map<String, String> parcela;
  final String rotulo;
  final bool pago;
  final bool atrasado;
  final String comprovanteSelecionadoNome;
  final bool processando;
  final VoidCallback onAbrirComprovante;
  final VoidCallback onSelecionarComprovante;
  final VoidCallback onDarBaixa;
  final VoidCallback? onAlterarParcelas;
  final VoidCallback? onQuitarPlano;

  const NatusParcelaItem({
    super.key,
    required this.parcela,
    required this.rotulo,
    required this.pago,
    required this.atrasado,
    this.comprovanteSelecionadoNome = '',
    this.processando = false,
    required this.onAbrirComprovante,
    required this.onSelecionarComprovante,
    required this.onDarBaixa,
    this.onAlterarParcelas,
    this.onQuitarPlano,
  });

  static const _meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];

  (String, String) get _diaMes {
    final partes = (parcela['vencimento'] ?? '').split('/');
    if (partes.length == 3) {
      final dia = partes[0].padLeft(2, '0');
      final mes = int.tryParse(partes[1]);
      if (mes != null && mes >= 1 && mes <= 12) {
        return (dia, _meses[mes - 1]);
      }
    }
    return ('--', '---');
  }

  @override
  Widget build(BuildContext context) {
    final (dia, mes) = _diaMes;
    final corStatus = pago
        ? const Color(0xFF5F7D54)
        : atrasado
        ? const Color(0xFFB3413B)
        : const Color(0xFFC07A3D);
    final textoStatus = pago
        ? 'Pago'
        : atrasado
        ? 'Atrasado'
        : 'Pendente';

    final dataCard = Container(
      width: 48,
      height: 52,
      decoration: BoxDecoration(
        color: (atrasado ? corStatus : NatusApp.marsala).withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dia,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: atrasado ? corStatus : NatusApp.marsala,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            mes,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: (atrasado ? corStatus : NatusApp.marsala).withValues(
                alpha: 0.8,
              ),
            ),
          ),
        ],
      ),
    );

    final detalhes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parcela['gestante'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: NatusApp.texto,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: NatusApp.textoSuave,
          ),
        ),
        if (comprovanteSelecionadoNome.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            'Comprovante: $comprovanteSelecionadoNome',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5F7D54),
            ),
          ),
        ],
      ],
    );

    final valorStatus = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          parcela['valor'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: NatusApp.vinho,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: corStatus.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            textoStatus,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: corStatus,
            ),
          ),
        ),
      ],
    );

    final acaoPrincipal = processando
        ? const Padding(
            padding: EdgeInsets.all(13),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        : !pago
        ? IconButton(
            tooltip: 'Dar baixa',
            icon: const Icon(
              Icons.check_circle,
              color: Color(0xFF5F7D54),
              size: 22,
            ),
            onPressed: onDarBaixa,
          )
        : IconButton(
            tooltip: 'Abrir comprovante',
            icon: Icon(
              Icons.fact_check_outlined,
              color: NatusApp.vinho,
              size: 21,
            ),
            onPressed: onAbrirComprovante,
          );

    final menuAcoes = PopupMenuButton<String>(
      enabled: !processando,
      tooltip: 'Mais ações',
      icon: Icon(Icons.more_vert, color: NatusApp.textoSuave, size: 20),
      onSelected: (op) {
        switch (op) {
          case 'comprovante_sel':
            onSelecionarComprovante();
          case 'quitar':
            onQuitarPlano?.call();
          case 'alterar_parcelas':
            onAlterarParcelas?.call();
        }
      },
      itemBuilder: (context) => [
        if (onAlterarParcelas != null)
          PopupMenuItem(
            value: 'alterar_parcelas',
            child: Row(
              children: [
                Icon(
                  Icons.edit_calendar_outlined,
                  size: 18,
                  color: NatusApp.vinho,
                ),
                const SizedBox(width: 10),
                const Text('Alterar parcelas'),
              ],
            ),
          ),
        if (!pago) ...[
          const PopupMenuItem(
            value: 'comprovante_sel',
            child: Text('Selecionar comprovante'),
          ),
          if (onQuitarPlano != null)
            PopupMenuItem(
              value: 'quitar',
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 18,
                    color: NatusApp.douradoEscuro,
                  ),
                  const SizedBox(width: 10),
                  const Text('Quitar plano do paciente'),
                ],
              ),
            ),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NatusApp.douradoClaro.withValues(alpha: 0.55),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    dataCard,
                    const SizedBox(width: 12),
                    Expanded(child: detalhes),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: valorStatus),
                    acaoPrincipal,
                    menuAcoes,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              dataCard,
              const SizedBox(width: 12),
              Expanded(child: detalhes),
              const SizedBox(width: 8),
              valorStatus,
              acaoPrincipal,
              menuAcoes,
            ],
          );
        },
      ),
    );
  }
}
