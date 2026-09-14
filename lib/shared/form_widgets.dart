import 'package:flutter/material.dart';
import 'natus_app.dart';

Widget bloco(String titulo, List<Widget> children) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: NatusApp.vinho.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: NatusApp.vinho,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(spacing: 12, runSpacing: 12, children: children),
        ),
      ],
    ),
  );
}

Widget dropdown(
  String label,
  String valor,
  List<String> itens,
  Function(String) onChange,
) {
  final itensTratados = itens
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  final valorTratado = itensTratados.contains(valor.trim())
      ? valor.trim()
      : null;

  return SizedBox(
    width: 230,
    child: DropdownButtonFormField<String>(
      initialValue: valorTratado,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: itensTratados
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChange(v);
      },
    ),
  );
}

Widget dropdownPopup(
  String valor,
  List<String> opcoes,
  Function(String) aoMudar,
) {
  final opcoesTratadas = opcoes
      .map((opcao) => opcao.trim())
      .where((opcao) => opcao.isNotEmpty)
      .toSet()
      .toList();

  final valorTratado = opcoesTratadas.contains(valor.trim())
      ? valor.trim()
      : null;

  return Container(
    width: 260,
    margin: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      initialValue: valorTratado,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: opcoesTratadas
          .map((opcao) => DropdownMenuItem(value: opcao, child: Text(opcao)))
          .toList(),
      onChanged: (v) {
        if (v != null) aoMudar(v);
      },
    ),
  );
}

Widget dropdownGrande(
  String label,
  String valor,
  List<String> itens,
  Function(String) onChange,
) {
  final itensTratados = itens
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  final valorTratado = itensTratados.contains(valor.trim())
      ? valor.trim()
      : null;

  return SizedBox(
    width: 360,
    child: DropdownButtonFormField<String>(
      initialValue: valorTratado,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: itensTratados
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChange(v);
      },
    ),
  );
}
