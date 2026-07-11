import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import '../shared/formatadores.dart';
import '../gestantes/gestantes_regras.dart';

/// Cards e alertas do dashboard — linguagem visual "editorial sereno",
/// guiada por design_referencia_visual.png (raiz do projeto).
///
/// Assinaturas idênticas às originais: nenhum call site muda.

// Tons semânticos quentes, harmonizados com a paleta da marca.
const Color _tomOk = Color(0xFF5F7D54);
const Color _tomAlerta = Color(0xFFC07A3D);
const Color _tomErro = Color(0xFFB3413B);

class NatusCardKpi extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;

  const NatusCardKpi(this.titulo, this.valor, this.icone);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NatusApp.douradoClaro.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: NatusApp.douradoEscuro, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: NatusApp.vinho,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
}

class NatusAlertaDpp extends StatelessWidget {
  final Map<String, String> g;

  const NatusAlertaDpp(this.g);

  @override
  Widget build(BuildContext context) {
    final dias = diasParaDpp(g['dpp'] ?? '');
    final status = g['statusGestante'] ?? 'Gestante';

    // Só alerta para gestantes ativas (mesma regra de antes)
    if (status != 'Gestante') return const SizedBox();

    if (dias > 14) return const SizedBox();

    final urgente = dias <= 7;
    final cor = urgente ? NatusApp.marsala : _tomAlerta;
    final String rotulo;
    if (dias < 0) {
      rotulo = 'DPP passou há ${-dias} ${-dias == 1 ? 'dia' : 'dias'}';
    } else if (dias == 0) {
      rotulo = 'DPP é hoje';
    } else {
      rotulo = 'DPP em $dias ${dias == 1 ? 'dia' : 'dias'}';
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            rotulo,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class NatusCardAlertaDashboard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const NatusCardAlertaDashboard(
      this.titulo, this.valor, this.icone, this.cor);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icone, color: cor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NatusApp.textoSuave,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: cor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NatusCardFinanceiroResumo extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;
  final String sufixo;

  const NatusCardFinanceiroResumo(this.titulo, this.valor, this.cor, this.icone,
      {this.sufixo = ''});

  @override
  Widget build(BuildContext context) {
    final textoValor =
        sufixo == '%' ? '${valor.toStringAsFixed(1)}%' : formatarMoeda(valor);

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: NatusApp.textoSuave,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              textoValor,
              style: TextStyle(
                fontSize: isMobile ? 15 : 17,
                fontWeight: FontWeight.w800,
                color: cor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NatusCardContagemResumo extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color cor;
  final IconData icone;

  const NatusCardContagemResumo(this.titulo, this.valor, this.cor, this.icone);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: NatusApp.textoSuave,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            valor.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class NatusCardResumo extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color? cor;

  const NatusCardResumo(this.titulo, this.valor, this.icone, {this.cor});

  @override
  Widget build(BuildContext context) {
    final corFinal = cor ?? NatusApp.vinho;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      width: 220,
      height: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.05),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: NatusApp.textoSuave,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: corFinal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icone, color: corFinal, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: corFinal,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NatusBlocoDashboard extends StatelessWidget {
  final String titulo;
  final List<Widget> filhos;

  const NatusBlocoDashboard(this.titulo, this.filhos);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: NatusApp.dourado,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: NatusApp.vinho,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...filhos,
        ],
      ),
    );
  }
}

class NatusAlertaDashboardFinanceiro extends StatelessWidget {
  final int atrasadas;

  const NatusAlertaDashboardFinanceiro(this.atrasadas);

  @override
  Widget build(BuildContext context) {
    final semAtraso = atrasadas == 0;
    final cor = semAtraso ? _tomOk : _tomErro;
    final texto = semAtraso
        ? 'Nenhuma parcela atrasada no período selecionado.'
        : 'Atenção: existem $atrasadas parcela(s) atrasada(s) no período selecionado.';
    final icone = semAtraso ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NatusCardIndicadorAmamentacao extends StatelessWidget {
  final String titulo;
  final int valor;
  final int total;
  final Color cor;

  const NatusCardIndicadorAmamentacao(
      this.titulo, this.valor, this.total, this.cor);

  @override
  Widget build(BuildContext context) {
    final percentual = total == 0 ? 0.0 : (valor / total);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.child_friendly, color: cor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NatusApp.texto,
                  ),
                ),
              ),
              Text(
                '$valor (${(percentual * 100).toStringAsFixed(1)}%)',
                style: TextStyle(fontWeight: FontWeight.w800, color: cor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentual,
              minHeight: 6,
              backgroundColor: cor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
        ],
      ),
    );
  }
}

class NatusCardResumoAlmox extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const NatusCardResumoAlmox(this.titulo, this.valor, this.icone, this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: NatusApp.vinhoProfundo.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: cor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NatusApp.textoSuave,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cor,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Novos componentes da referência visual — prontos para as telas do 2f
// ═══════════════════════════════════════════════════════════════════

/// Badge-pílula de status (Ativa / Puérpera / Encerrada / Histórico),
/// no estilo pastel da referência.
class NatusStatusBadge extends StatelessWidget {
  final String status;

  const NatusStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    Color cor;
    if (s.contains('puérpera') || s.contains('puerpera')) {
      cor = NatusApp.marsalaSuave;
    } else if (s.contains('encerrada') || s.contains('histórico') ||
        s.contains('historico')) {
      cor = NatusApp.textoSuave;
    } else {
      cor = _tomOk; // Ativa / Gestante
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: cor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Cabeçalho de saudação do dashboard: "Olá, {nome} ♥" + subtítulo,
/// como na referência visual.
class NatusSaudacaoDashboard extends StatelessWidget {
  final String nome;
  final String? subtitulo;

  const NatusSaudacaoDashboard(this.nome, {this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'Olá, $nome',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: NatusApp.vinho,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.favorite, color: NatusApp.dourado, size: 18),
          ],
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitulo!,
            style: const TextStyle(
              fontSize: 13,
              color: NatusApp.textoSuave,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
