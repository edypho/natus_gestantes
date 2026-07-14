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
  final String statusAsaasTexto;
  final Color statusAsaasCor;
  final bool temCobrancaAsaas;
  final VoidCallback onAbrirCobranca;
  final VoidCallback onConsultarStatus;
  final VoidCallback onCopiarPix;
  final VoidCallback onAbrirBoleto;
  final VoidCallback onAbrirComprovante;
  final VoidCallback onGerarCobranca;
  final VoidCallback onSelecionarComprovante;
  final VoidCallback onDarBaixa;
  final VoidCallback? onQuitarPlano;

  const NatusParcelaItem({
    super.key,
    required this.parcela,
    required this.rotulo,
    required this.pago,
    required this.atrasado,
    required this.statusAsaasTexto,
    required this.statusAsaasCor,
    required this.temCobrancaAsaas,
    required this.onAbrirCobranca,
    required this.onConsultarStatus,
    required this.onCopiarPix,
    required this.onAbrirBoleto,
    required this.onAbrirComprovante,
    required this.onGerarCobranca,
    required this.onSelecionarComprovante,
    required this.onDarBaixa,
    this.onQuitarPlano,
  });

  static const _meses = [
    'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
    'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          // quadrado de data
          Container(
            width: 48,
            height: 52,
            decoration: BoxDecoration(
              color: (atrasado ? corStatus : NatusApp.marsala)
                  .withValues(alpha: 0.10),
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
                    color: (atrasado ? corStatus : NatusApp.marsala)
                        .withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                const SizedBox(height: 4),
                Tooltip(
                  message: statusAsaasTexto,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 13, color: statusAsaasCor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusAsaasTexto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusAsaasCor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
          ),
          // ação principal + menu
          if (!pago)
            IconButton(
              tooltip: 'Dar baixa',
              icon: const Icon(Icons.check_circle,
                  color: Color(0xFF5F7D54), size: 22),
              onPressed: onDarBaixa,
            )
          else
            IconButton(
              tooltip: 'Abrir comprovante',
              icon: Icon(Icons.fact_check_outlined,
                  color: NatusApp.vinho, size: 21),
              onPressed: onAbrirComprovante,
            ),
          PopupMenuButton<String>(
            tooltip: 'Mais ações',
            icon: Icon(Icons.more_vert,
                color: NatusApp.textoSuave, size: 20),
            onSelected: (op) {
              switch (op) {
                case 'abrir':
                  onAbrirCobranca();
                case 'consultar':
                  onConsultarStatus();
                case 'pix_copiar':
                  onCopiarPix();
                case 'boleto':
                  onAbrirBoleto();
                case 'gerar':
                  onGerarCobranca();
                case 'comprovante_sel':
                  onSelecionarComprovante();
                case 'quitar':
                  onQuitarPlano?.call();
              }
            },
            itemBuilder: (context) => [
              if (temCobrancaAsaas) ...[
                const PopupMenuItem(
                    value: 'abrir', child: Text('Abrir cobrança Asaas')),
                const PopupMenuItem(
                    value: 'consultar', child: Text('Consultar status Asaas')),
                const PopupMenuItem(
                    value: 'pix_copiar', child: Text('Copiar Pix copia e cola')),
                const PopupMenuItem(
                    value: 'boleto', child: Text('Abrir boleto Asaas')),
              ],
              if (!pago) ...[
                if (!temCobrancaAsaas)
                  const PopupMenuItem(
                      value: 'gerar', child: Text('Gerar cobrança Asaas')),
                const PopupMenuItem(
                    value: 'comprovante_sel',
                    child: Text('Selecionar comprovante')),
                if (onQuitarPlano != null)
                  PopupMenuItem(
                    value: 'quitar',
                    child: Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined,
                            size: 18, color: NatusApp.douradoEscuro),
                        SizedBox(width: 10),
                        Text('Quitar plano da gestante'),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
