import 'package:flutter/material.dart';

import 'super_admin_layout.dart';

Widget superAdminCard({
  required String titulo,
  required String valor,
  required IconData icone,
  double? width,
  VoidCallback? onTap,
  Color? destaque,
}) {
  final cor = destaque ?? superAdminVinho;
  return Semantics(
    label: '$titulo: $valor',
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: width ?? 240,
        constraints: const BoxConstraints(minHeight: 128),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: superAdminFundoCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cor.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: cor.withValues(alpha: 0.045),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icone, color: cor, size: 20),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: cor, size: 19),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.w800,
                fontSize: 25,
                height: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SuperAdminResponsiveGrid extends StatelessWidget {
  const SuperAdminResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 14,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final calculadas =
            ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                .floor();
        final colunas = calculadas
            .clamp(1, maxColumns)
            .clamp(1, children.length);
        final largura =
            (constraints.maxWidth - (spacing * (colunas - 1))) / colunas;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: largura, child: child))
              .toList(),
        );
      },
    );
  }
}
