import 'package:flutter/material.dart';

Widget barraFinanceiraBonitaWidget({
  required double percentual,
  required Color cor,
}) {
  return Container(
    height: 14,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(30),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: LinearProgressIndicator(
        value: percentual.clamp(0.0, 1.0),
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation(cor),
      ),
    ),
  );
}

Widget cardFinanceiroResumo({
  required String titulo,
  required String valor,
  required IconData icone,
  required Color cor,
}) {
  return Container(
    width: 260,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: cor.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icone, color: cor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Text(
                valor,
                style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.bold,
                  fontSize: 21,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget financeiroFiltroBotao({
  required String filtro,
  required bool selecionado,
  required VoidCallback onPressed,
}) {
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: selecionado ? const Color(0xFF7B3A44) : Colors.white,
      foregroundColor: selecionado ? Colors.white : const Color(0xFF7B3A44),
      side: BorderSide(color: const Color(0xFF7B3A44).withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    child: Text(filtro, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

String rotuloParcelaFinanceiraWidget(Map<String, String> parcela) {
  final tipo = (parcela['tipo'] ?? '').trim().toLowerCase();
  final descricao = (parcela['descricao'] ?? '').trim();

  if (tipo == 'entrada') return 'Entrada';
  if (descricao.isNotEmpty) return descricao;

  final numero = (parcela['numero'] ?? '').trim();
  if (numero == '0') return 'Entrada';
  if (numero.isNotEmpty) return '${numero}ª Parcela';

  return 'Parcela';
}

Widget financeiroParcelaCard({
  required Map<String, String> parcela,
  required bool pago,
  required bool atrasado,
  required Future<void> Function(String url) abrirDocumento,
  required Future<void> Function() selecionarArquivo,
  required Future<void> Function(Map<String, String> parcela) darBaixaParcela,
  required void Function(String mensagem) mostrarMensagem,
}) {
  final cor = pago
      ? Colors.green
      : atrasado
      ? Colors.red
      : const Color(0xFF7B3A44);

  final nome =
      parcela['nomeGestante'] ??
      parcela['gestante'] ??
      parcela['nome'] ??
      'Gestante';

  final valor =
      parcela['valor'] ??
      parcela['valorParcela'] ??
      parcela['valorPlano'] ??
      '-';

  final vencimento = parcela['vencimento'] ?? parcela['dataVencimento'] ?? '-';

  final comprovante =
      parcela['comprovanteUrl'] ?? parcela['urlComprovante'] ?? '';
  final rotulo = rotuloParcelaFinanceiraWidget(parcela);

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cor.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: cor.withValues(alpha: 0.05),
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
            Icon(
              pago
                  ? Icons.check_circle
                  : atrasado
                  ? Icons.warning_rounded
                  : Icons.pending_actions,
              color: cor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nome,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Text(
              pago
                  ? 'Pago'
                  : atrasado
                  ? 'Atrasado'
                  : 'Pendente',
              style: TextStyle(color: cor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Valor: R\$ $valor'),
        Text('Vencimento: $vencimento'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (comprovante.trim().isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  await abrirDocumento(comprovante);
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Comprovante'),
              ),
            if (!pago)
              ElevatedButton.icon(
                onPressed: () async {
                  await selecionarArquivo();
                  await darBaixaParcela(parcela);
                },
                icon: const Icon(Icons.check),
                label: const Text('Dar baixa'),
              ),
          ],
        ),
      ],
    ),
  );
}
