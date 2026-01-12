import 'package:flutter/material.dart';

/// Reimplementação do helper _pair do arquivo original.
/// Recebe `left` e `right` e decide se empilha (mobile) ou coloca em duas
/// colunas (desktop), mantendo exatamente o comportamento visual.
class PairColumns extends StatelessWidget {
  final Widget left;
  final Widget right;

  const PairColumns({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final isNarrow = box.maxWidth < 720;
      // aumenta espaçamento horizontal em telas largas (desktop)
      final spacing = box.maxWidth > 1100 ? 20.0 : 12.0;
      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, SizedBox(height: spacing), right],
        );
      } else {
        return Row(
          children: [Expanded(child: left), SizedBox(width: spacing), Expanded(child: right)],
        );
      }
    });
  }
}
