import 'package:flutter/material.dart';

import '../shared/natus_app.dart';
import 'financeiro_calculos.dart';
import 'financeiro_widgets.dart';

bool parcelaPagaFinanceiro(Map<String, String> parcela) {
  final status = (parcela['status'] ?? '').trim().toLowerCase();
  return status == 'pago' || status == 'paga';
}

String textoSeguroFinanceiro(Map<String, String> parcela, String chave) {
  final valor = parcela[chave];
  if (valor == null || valor.trim().isEmpty) {
    return '-';
  }
  return valor;
}

typedef CardResumoFinanceiroBuilder =
    Widget Function(String titulo, String valor, IconData icone);

Widget telaFinanceiroPage({
  required List<Map<String, String>> parcelasFinanceiras,
  required int mesSelecionado,
  required int anoSelecionado,
  required void Function(int valor) alterarMes,
  required void Function(int valor) alterarAno,
  required VoidCallback exportarFinanceiroExcel,
  required CardResumoFinanceiroBuilder cardResumo,
  required String Function(double valor) formatarMoeda,
  required double Function() calcularValorRecebidoMesAtual,
  required double Function() calcularValorAReceberReal,
  required double Function() calcularValorAtrasadoMesAtual,
  required double Function() calcularTotalPrevistoMesSelecionado,
  required String filtroFinanceiro,
  required void Function(String valor) alterarFiltroFinanceiro,
  required bool Function(Map<String, String> parcela) parcelaEhDoMesSelecionado,
  required bool Function(Map<String, String> parcela) parcelaEstaAtrasada,
  required Future<void> Function(String url) abrirDocumento,
  required Future<void> Function() selecionarArquivo,
  required Future<void> Function(Map<String, String> parcela) darBaixaParcela,
  required void Function(String mensagem) mostrarMensagem,
}) {
  final parcelasDoMes = parcelasFinanceiras.where((p) {
    return lancamentoFinanceiroVisivelNoPeriodo(
      p,
      mesSelecionado,
      anoSelecionado,
    );
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
              onChanged: (valor) {
                if (valor != null) {
                  alterarMes(valor);
                }
              },
            ),

            const SizedBox(width: 16),

            DropdownButton<int>(
              value: anoSelecionado,
              items: List.generate(5, (index) {
                final ano = DateTime.now().year - 2 + index;
                return DropdownMenuItem(
                  value: ano,
                  child: Text(ano.toString()),
                );
              }),
              onChanged: (valor) {
                if (valor != null) {
                  alterarAno(valor);
                }
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
            foregroundColor: Colors.white,
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

        const SizedBox(height: 20),

        Text(
          'Parcelas do mês atual',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: NatusApp.vinho,
          ),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            financeiroFiltroBotao(
              filtro: 'Todos',
              selecionado: filtroFinanceiro == 'Todos',
              onPressed: () => alterarFiltroFinanceiro('Todos'),
            ),
            financeiroFiltroBotao(
              filtro: 'Pagos',
              selecionado: filtroFinanceiro == 'Pagos',
              onPressed: () => alterarFiltroFinanceiro('Pagos'),
            ),
            financeiroFiltroBotao(
              filtro: 'Pendentes',
              selecionado: filtroFinanceiro == 'Pendentes',
              onPressed: () => alterarFiltroFinanceiro('Pendentes'),
            ),
            financeiroFiltroBotao(
              filtro: 'Atrasados',
              selecionado: filtroFinanceiro == 'Atrasados',
              onPressed: () => alterarFiltroFinanceiro('Atrasados'),
            ),
          ],
        ),

        const SizedBox(height: 18),

        if (parcelasDoMes.isEmpty)
          const Text('Nenhuma parcela encontrada para este mês.'),

        ...parcelasDoMes
            .where((p) {
              final pago = parcelaPagaFinanceiro(p);
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
              final pago = parcelaPagaFinanceiro(p);
              final atrasado = parcelaEstaAtrasada(p);

              return financeiroParcelaCard(
                parcela: p,
                pago: pago,
                atrasado: atrasado,
                abrirDocumento: abrirDocumento,
                selecionarArquivo: selecionarArquivo,
                darBaixaParcela: darBaixaParcela,
                mostrarMensagem: mostrarMensagem,
              );
            }),
      ],
    ),
  );
}
