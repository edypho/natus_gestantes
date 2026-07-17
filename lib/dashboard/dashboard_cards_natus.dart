import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../shared/natus_app.dart';
import '../shared/formatadores.dart';
import '../gestantes/gestantes_regras.dart';
import '../kpis/kpis_calculos.dart' as kpis;

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

  const NatusCardKpi(this.titulo, this.valor, this.icone, {super.key});

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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: NatusApp.vinho,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  style: TextStyle(
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

  const NatusAlertaDpp(this.g, {super.key});

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
  final VoidCallback? onTap;

  const NatusCardAlertaDashboard(
    this.titulo,
    this.valor,
    this.icone,
    this.cor, {
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return _NatusCardClicavel(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
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
                  style: TextStyle(
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
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: cor, size: 18),
          ],
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
  final VoidCallback? onTap;

  const NatusCardFinanceiroResumo(
    this.titulo,
    this.valor,
    this.cor,
    this.icone, {
    super.key,
    this.sufixo = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textoValor = sufixo == '%'
        ? '${valor.toStringAsFixed(1)}%'
        : formatarMoeda(valor);

    final isMobile = MediaQuery.of(context).size.width < 700;

    return _NatusCardClicavel(
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(18),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Spacer(),
              if (onTap != null)
                Icon(Icons.arrow_forward_rounded, color: cor, size: 18),
            ],
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
  final VoidCallback? onTap;

  const NatusCardContagemResumo(
    this.titulo,
    this.valor,
    this.cor,
    this.icone, {
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return _NatusCardClicavel(
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, color: cor, size: 13),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.arrow_forward_rounded, color: cor, size: 13),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isMobile ? 8.5 : 9.5,
              fontWeight: FontWeight.w600,
              color: NatusApp.textoSuave,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor.toString(),
            style: TextStyle(
              fontSize: 15,
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

class _NatusCardClicavel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;
  final BorderRadius borderRadius;
  final Decoration decoration;

  const _NatusCardClicavel({
    required this.child,
    required this.onTap,
    required this.padding,
    required this.borderRadius,
    required this.decoration,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final conteudo = Container(
      constraints: constraints,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return conteudo;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: conteudo,
          ),
        ),
      ),
    );
  }
}

class NatusCardResumo extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color? cor;

  const NatusCardResumo(
    this.titulo,
    this.valor,
    this.icone, {
    super.key,
    this.cor,
  });

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

  const NatusBlocoDashboard(this.titulo, this.filhos, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NatusApp.douradoClaro.withValues(alpha: 0.55),
        ),
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
                  style: TextStyle(
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

  const NatusAlertaDashboardFinanceiro(this.atrasadas, {super.key});

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
    this.titulo,
    this.valor,
    this.total,
    this.cor, {
    super.key,
  });

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
                  style: TextStyle(
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

/// Doughnut + lista interativos para o indicador de Amamentação.
///
/// Substitui `graficoPizzaAmamentacao()` + `cardIndicadorAmamentacao()`:
/// - cores de marca (`_tomOk` / `_tomAlerta` / `_tomErro`) no lugar de
///   Colors.green/orange/red;
/// - categorias com valor 0 somem do gráfico (antes viravam uma fatia
///   "fantasma" de tamanho igual às demais);
/// - total de registros no miolo do doughnut;
/// - toque sincronizado: tocar numa fatia realça a linha correspondente
///   e vice-versa;
/// - estado vazio próprio quando não há nenhum registro ainda;
/// - empilha (gráfico em cima, lista embaixo) em telas estreitas.
class NatusGraficoAmamentacao extends StatefulWidget {
  final Map<String, int> dados;

  const NatusGraficoAmamentacao(this.dados, {super.key});

  @override
  State<NatusGraficoAmamentacao> createState() =>
      _NatusGraficoAmamentacaoState();
}

class _NatusGraficoAmamentacaoState extends State<NatusGraficoAmamentacao> {
  static const _ordemCategorias = ['AME', 'Mista', 'Fórmula'];

  int? _indiceSelecionado;

  Color _corDe(String categoria) {
    switch (categoria) {
      case 'AME':
        return _tomOk;
      case 'Mista':
        return _tomAlerta;
      default:
        return _tomErro;
    }
  }

  IconData _iconeDe(String categoria) {
    switch (categoria) {
      case 'AME':
        return Icons.spa_rounded;
      case 'Mista':
        return Icons.water_drop_rounded;
      default:
        return Icons.local_drink_rounded;
    }
  }

  void _alternarSelecao(int indice) {
    setState(() {
      _indiceSelecionado = _indiceSelecionado == indice ? null : indice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.dados.values.fold<int>(0, (a, b) => a + b);

    if (total == 0) {
      return _estadoVazio();
    }

    final entradas =
        _ordemCategorias
            .map((c) => MapEntry(c, widget.dados[c] ?? 0))
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final empilhar = constraints.maxWidth < 520;
        final donut = _donut(total, entradas);
        final lista = _lista(entradas, total);

        if (empilhar) {
          return Column(children: [donut, const SizedBox(height: 20), lista]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: donut),
            const SizedBox(width: 24),
            Expanded(flex: 3, child: lista),
          ],
        );
      },
    );
  }

  Widget _estadoVazio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.insights_rounded, color: NatusApp.begeEscuro, size: 32),
          const SizedBox(height: 10),
          Text(
            'Ainda sem registros de amamentação',
            style: TextStyle(
              color: NatusApp.textoSuave,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _donut(int total, List<MapEntry<String, int>> entradas) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 46,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.touchedSection == null) {
                    return;
                  }
                  _alternarSelecao(
                    response.touchedSection!.touchedSectionIndex,
                  );
                },
              ),
              sections: List.generate(entradas.length, (i) {
                final e = entradas[i];
                final cor = _corDe(e.key);
                final selecionado = _indiceSelecionado == i;
                final percentual = e.value / total;

                return PieChartSectionData(
                  value: e.value.toDouble(),
                  radius: selecionado ? 60 : 52,
                  color: cor,
                  title: percentual >= 0.08
                      ? '${(percentual * 100).round()}%'
                      : '',
                  titleStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: NatusApp.offWhite,
                  ),
                  titlePositionPercentageOffset: 0.62,
                );
              }),
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: NatusApp.vinho,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  total == 1 ? 'registro' : 'registros',
                  style: TextStyle(
                    fontSize: 11,
                    color: NatusApp.textoSuave,
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

  Widget _lista(List<MapEntry<String, int>> entradas, int total) {
    return Column(
      children: List.generate(entradas.length, (i) {
        final e = entradas[i];
        return Padding(
          padding: EdgeInsets.only(bottom: i == entradas.length - 1 ? 0 : 12),
          child: _linhaCategoria(
            titulo: e.key,
            valor: e.value,
            total: total,
            cor: _corDe(e.key),
            icone: _iconeDe(e.key),
            selecionado: _indiceSelecionado == i,
            indice: i,
          ),
        );
      }),
    );
  }

  Widget _linhaCategoria({
    required String titulo,
    required int valor,
    required int total,
    required Color cor,
    required IconData icone,
    required bool selecionado,
    required int indice,
  }) {
    final percentual = total == 0 ? 0.0 : valor / total;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _alternarSelecao(indice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: selecionado ? 0.13 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cor.withValues(alpha: selecionado ? 0.55 : 0),
            width: 1.4,
          ),
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
                  child: Icon(icone, color: cor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
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
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: percentual),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, valorAnimado, _) => LinearProgressIndicator(
                  value: valorAnimado,
                  minHeight: 6,
                  backgroundColor: cor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(cor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NatusCardResumoAlmox extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const NatusCardResumoAlmox(
    this.titulo,
    this.valor,
    this.icone,
    this.cor, {
    super.key,
  });

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
                  style: TextStyle(
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
// ═══════════════════════════════════════════════════════════════════
// Bloco de métricas completas por obstetra (jul/2026)
// ═══════════════════════════════════════════════════════════════════

/// Uma linha "rótulo — valor" usada dentro dos blocos de métricas.
Widget _linhaMetricaObstetra(String rotulo, String valor, {Color? cor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            rotulo,
            style: TextStyle(fontSize: 13.5, color: NatusApp.textoSuave),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: cor ?? NatusApp.vinho,
          ),
        ),
      ],
    ),
  );
}

/// Cabeçalho de subseção dentro do bloco de métricas (ex.: "Partos").
Widget _tituloSecaoMetrica(String texto) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 2),
    child: Text(
      texto.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: NatusApp.douradoEscuro,
      ),
    ),
  );
}

/// Conteúdo completo de métricas de um obstetra — reaproveitado tanto
/// no bloco individual (visão do próprio obstetra) quanto dentro de
/// cada item da lista da equipe (visão de enfermeira/admin).
List<Widget> _corpoMetricasObstetra(kpis.ObstetraMetricasCompletas m) {
  return [
    _linhaMetricaObstetra('Total na carteira', '${m.totalCarteira}'),
    _linhaMetricaObstetra('Ativas no momento', '${m.ativasNaCarteira}'),

    _tituloSecaoMetrica('Partos'),
    _linhaMetricaObstetra('Já pariu', '${m.jaPariu}', cor: _tomOk),
    _linhaMetricaObstetra(
      'Ainda não pariu',
      '${m.aindaNaoPariu}',
      cor: _tomAlerta,
    ),
    _linhaMetricaObstetra('— Normal', '${m.partosNormal}'),
    _linhaMetricaObstetra('— Cesárea', '${m.partosCesarea}'),
    _linhaMetricaObstetra('— Domiciliar', '${m.partosDomiciliar}'),

    _tituloSecaoMetrica('Risco gestacional (ativas)'),
    _linhaMetricaObstetra('Habitual', '${m.riscoHabitual}', cor: _tomOk),
    _linhaMetricaObstetra(
      'Intermediário',
      '${m.riscoIntermediario}',
      cor: _tomAlerta,
    ),
    _linhaMetricaObstetra('Alto risco', '${m.riscoAltoRisco}', cor: _tomErro),

    _tituloSecaoMetrica('Diabetes gestacional (ativas)'),
    _linhaMetricaObstetra('Sim', '${m.diabetesSim}', cor: _tomAlerta),
    _linhaMetricaObstetra('Não', '${m.diabetesNao}', cor: _tomOk),

    _tituloSecaoMetrica('Acompanhamento'),
    _linhaMetricaObstetra(
      'DPP nos próximos 14 dias',
      '${m.dppProxima}',
      cor: m.dppProxima > 0 ? _tomAlerta : NatusApp.textoSuave,
    ),
  ];
}

/// Bloco de métricas completas de UM obstetra — usado na visão do
/// próprio obstetra ("Minhas métricas"), já respeitando o filtro de
/// carteira que ele enxerga.
class NatusBlocoMetricasObstetra extends StatelessWidget {
  final kpis.ObstetraMetricasCompletas metricas;
  final String? titulo;

  const NatusBlocoMetricasObstetra(this.metricas, {this.titulo, super.key});

  @override
  Widget build(BuildContext context) {
    return NatusBlocoDashboard(
      titulo ?? 'Minhas métricas',
      _corpoMetricasObstetra(metricas),
    );
  }
}

/// Lista de métricas completas de TODOS os obstetras — usada na visão
/// de enfermeira/admin. Cada obstetra é um card expansível, para não
/// poluir o dashboard quando a clínica tem muitos profissionais.
class NatusListaMetricasPorObstetra extends StatefulWidget {
  final List<kpis.ObstetraMetricasCompletas> lista;

  const NatusListaMetricasPorObstetra(this.lista, {super.key});

  @override
  State<NatusListaMetricasPorObstetra> createState() =>
      _NatusListaMetricasPorObstetraState();
}

class _NatusListaMetricasPorObstetraState
    extends State<NatusListaMetricasPorObstetra> {
  final Set<String> _expandidos = {};

  @override
  Widget build(BuildContext context) {
    if (widget.lista.isEmpty) {
      return const Text('Nenhum obstetra cadastrado.');
    }

    return Column(
      children: widget.lista.map((m) {
        final aberto = _expandidos.contains(m.nomeObstetra);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: NatusApp.offWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: NatusApp.douradoClaro.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    if (aberto) {
                      _expandidos.remove(m.nomeObstetra);
                    } else {
                      _expandidos.add(m.nomeObstetra);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: NatusApp.vinho.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.medical_services,
                          size: 18,
                          color: NatusApp.vinho,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.nomeObstetra,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: NatusApp.vinho,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${m.ativasNaCarteira} ativas · ${m.jaPariu} partos',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: NatusApp.textoSuave,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        aberto ? Icons.expand_less : Icons.expand_more,
                        color: NatusApp.douradoEscuro,
                      ),
                    ],
                  ),
                ),
              ),
              if (aberto)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(children: _corpoMetricasObstetra(m)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class NatusStatusBadge extends StatelessWidget {
  final String status;

  const NatusStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    Color cor;
    if (s.contains('puérpera') || s.contains('puerpera')) {
      cor = NatusApp.marsalaSuave;
    } else if (s.contains('encerrada') ||
        s.contains('histórico') ||
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
        style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Cabeçalho de saudação do dashboard: "Olá, {nome} ♥" + subtítulo,
/// como na referência visual.
class NatusSaudacaoDashboard extends StatelessWidget {
  final String nome;
  final String? subtitulo;

  const NatusSaudacaoDashboard(this.nome, {super.key, this.subtitulo});

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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: NatusApp.vinho,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.favorite, color: NatusApp.dourado, size: 18),
          ],
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitulo!,
            style: TextStyle(
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

const List<String> _mesesAbrev = [
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

/// Painel de KPIs de crescimento anual — 5 cards no estilo "Crescimento
/// anual" da referência visual, mas calculados sobre os anos que
/// realmente existem no banco (nada de ano fixo no código).
class NatusPainelCrescimento extends StatelessWidget {
  final kpis.CrescimentoNascimentosKpis dados;

  const NatusPainelCrescimento(this.dados, {super.key});

  @override
  Widget build(BuildContext context) {
    final mesAbrev = _mesesAbrev[dados.mesAtual - 1];
    final anoAnterior = dados.anoAtual - 1;
    final temAnoAnterior = dados.anosDisponiveis.contains(anoAnterior);

    final cards = <Widget>[
      _card(
        icone: Icons.trending_up_rounded,
        titulo: 'Crescimento anual',
        valor: dados.crescimentoPeriodoComparavel == null
            ? '—'
            : formatarPercentual(dados.crescimentoPeriodoComparavel!),
        corValor: _corCrescimento(dados.crescimentoPeriodoComparavel),
        subtitulo: temAnoAnterior
            ? 'Jan–$mesAbrev vs $anoAnterior'
            : 'Sem $anoAnterior p/ comparar',
      ),
      _card(
        icone: Icons.event_repeat_rounded,
        titulo: 'Crescimento mensal',
        valor: dados.crescimentoMesAtual == null
            ? '—'
            : formatarPercentual(dados.crescimentoMesAtual!),
        corValor: _corCrescimento(dados.crescimentoMesAtual),
        subtitulo: temAnoAnterior
            ? '$mesAbrev vs $mesAbrev/$anoAnterior'
            : 'Sem $anoAnterior p/ comparar',
      ),
      _card(
        icone: Icons.show_chart_rounded,
        titulo: 'Média histórica',
        valor: dados.mediaCrescimentoHistorico == null
            ? '—'
            : formatarPercentual(dados.mediaCrescimentoHistorico!),
        corValor: _corCrescimento(dados.mediaCrescimentoHistorico),
        subtitulo: '${dados.anosDisponiveis.length} ano(s) com registro',
      ),
      _card(
        icone: Icons.emoji_events_rounded,
        titulo: 'Melhor ano',
        valor: dados.melhorAnoTotal == 0 ? '—' : '${dados.melhorAno}',
        corValor: NatusApp.dourado,
        subtitulo: '${dados.melhorAnoTotal} nascimento(s)',
      ),
      _card(
        icone: Icons.insights_rounded,
        titulo: 'Total histórico',
        valor: '${dados.totalHistorico}',
        corValor: NatusApp.marsala,
        subtitulo: 'Todos os anos cadastrados',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Largura mínima confortável por card; quebra linha sozinho.
        const larguraMinima = 168.0;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(width: larguraMinima, child: c))
              .toList(),
        );
      },
    );
  }

  Color _corCrescimento(double? percentual) {
    if (percentual == null) return NatusApp.textoSuave;
    if (percentual > 0) return _tomOk;
    if (percentual < 0) return _tomErro;
    return NatusApp.textoSuave;
  }

  Widget _card({
    required IconData icone,
    required String titulo,
    required String valor,
    required Color corValor,
    required String subtitulo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NatusApp.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NatusApp.douradoClaro.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: corValor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, size: 14, color: corValor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NatusApp.textoSuave,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: corValor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: NatusApp.textoSuave),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de linha de crescimento, dinâmico para N anos — sem ano
/// hardcoded. Cada ano vira uma linha; o ano mais recente ganha a cor
/// de marca (marsala) e destaque, os demais usam uma escala de tons
/// suaves derivada da paleta (do dourado ao bege) para não competir
/// visualmente com o ano em foco.
class NatusGraficoLinhaCrescimento extends StatelessWidget {
  final List<int> anos;
  final Map<int, Map<int, int>> dadosPorAno;

  const NatusGraficoLinhaCrescimento({
    required this.anos,
    required this.dadosPorAno,
    super.key,
  });

  Color _corDoAno(int indice, int total) {
    if (indice == total - 1) return NatusApp.marsala; // ano mais recente
    if (indice == total - 2) return NatusApp.dourado; // ano anterior
    // Anos mais antigos: tons suaves, do texto-suave ao bege-escuro.
    return NatusApp.textoSuave.withValues(alpha: 0.45);
  }

  double _espessuraDoAno(int indice, int total) =>
      indice == total - 1 ? 3.2 : 2.0;

  @override
  Widget build(BuildContext context) {
    if (anos.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'Ainda sem dados suficientes para o gráfico',
          style: TextStyle(
            color: NatusApp.textoSuave,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    var maiorValor = 1.0;
    for (final ano in anos) {
      for (final valor in (dadosPorAno[ano] ?? {}).values) {
        if (valor.toDouble() > maiorValor) maiorValor = valor.toDouble();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: List.generate(anos.length, (i) {
            return _legendaAno(
              '${anos[i]}',
              _corDoAno(i, anos.length),
              ehAtual: i == anos.length - 1,
            );
          }),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: 12,
              minY: 0,
              maxY: maiorValor * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: NatusApp.begeEscuro.withValues(alpha: 0.35),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < 1 || value.toInt() > 12) {
                        return const SizedBox();
                      }
                      return Text(
                        _mesesAbrev[value.toInt() - 1],
                        style: TextStyle(
                          fontSize: 10,
                          color: NatusApp.textoSuave,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: maiorValor <= 10 ? 2 : null,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: NatusApp.textoSuave,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => NatusApp.vinhoProfundo,
                  getTooltipItems: (spots) => spots.map((s) {
                    final ano = anos[s.barIndex];
                    return LineTooltipItem(
                      '$ano • ${_mesesAbrev[s.x.toInt() - 1]}: ${s.y.toInt()}',
                      TextStyle(
                        color: NatusApp.offWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: List.generate(anos.length, (i) {
                final ano = anos[i];
                final porMes = dadosPorAno[ano] ?? {};
                final cor = _corDoAno(i, anos.length);
                final ehAtual = i == anos.length - 1;

                return LineChartBarData(
                  spots: List.generate(12, (m) {
                    final mes = m + 1;
                    return FlSpot(
                      mes.toDouble(),
                      (porMes[mes] ?? 0).toDouble(),
                    );
                  }),
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: cor,
                  barWidth: _espessuraDoAno(i, anos.length),
                  dotData: FlDotData(show: ehAtual),
                  belowBarData: ehAtual
                      ? BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              NatusApp.marsala.withValues(alpha: 0.16),
                              NatusApp.marsala.withValues(alpha: 0.0),
                            ],
                          ),
                        )
                      : BarAreaData(show: false),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendaAno(String texto, Color cor, {bool ehAtual = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontWeight: ehAtual ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
            color: ehAtual ? NatusApp.vinho : NatusApp.textoSuave,
          ),
        ),
      ],
    );
  }
}
