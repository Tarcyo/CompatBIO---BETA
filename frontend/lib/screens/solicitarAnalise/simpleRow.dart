import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

class SimpleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final double scale;
  final double verticalPadding;

  const SimpleRow({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.scale = 1.0,
    this.verticalPadding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    // Usamos LayoutBuilder para obter o espaço disponível e adaptar tudo.
    return LayoutBuilder(builder: (context, constraints) {
      // Ajuste este fator conforme necessário (quanto maior, mais espaço para o valor).
      final double valueWidthFraction = 0.45;
      final double maxValueWidth = constraints.maxWidth * valueWidthFraction;

      return AnimatedBuilder(
        animation: ColorManager.instance,
        builder: (context, _) {
          final cm = ColorManager.instance;

          final bool hasSelection =
              value.trim().isNotEmpty && value.toLowerCase() != 'nenhum' && value != '—';

          final Color containerColor = cm.background;
          final Color borderColor = cm.primary.withOpacity(0.22);
          final Color iconColor = cm.primary;
          final Color labelColor = cm.explicitText;
          final Color noneColor = cm.explicitText.withOpacity(0.6);
          final Color selectionBg = cm.highlightText.withOpacity(0.12);
          final Color selectionText = cm.highlightText;
          final Color chevronColor = cm.explicitText.withOpacity(0.45);

          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18 * scale),
            child: Container(
              // garante um mínimo de altura tocável e padding responsivo
              constraints: BoxConstraints(minHeight: 44 * scale),
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: verticalPadding * scale,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18 * scale),
                color: containerColor,
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Row(
                children: [
                  // LEFT: ícone + label
                  Expanded(
                    child: Row(
                      children: [
                        Icon(icon, color: iconColor, size: 18 * scale),
                        SizedBox(width: 10 * scale),
                        // label ocupa o restante do espaço do lado esquerdo e faz ellipsis se necessário
                        Flexible(
                          fit: FlexFit.tight,
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14 * scale,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // espaçamento curto entre as áreas (mantém tudo alinhado)
                  SizedBox(width: 8 * scale),

                  // RIGHT: valor (com largura limitada) + chevron
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      // garante que a área do valor + chevron não exceda a fração definida
                      maxWidth: maxValueWidth + 40 * scale, // + espaço para o chevron
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // O valor em si tem largura limitada e faz ellipsis
                        Flexible(
                          child: hasSelection
                              ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12 * scale,
                                    vertical: 8 * scale,
                                  ),
                                  // limitamos a largura interna do container do valor
                                  constraints: BoxConstraints(maxWidth: maxValueWidth),
                                  decoration: BoxDecoration(
                                    color: selectionBg,
                                    borderRadius: BorderRadius.circular(18 * scale),
                                  ),
                                  child: Text(
                                    value,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: selectionText,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15 * scale,
                                      height: 1,
                                    ),
                                  ),
                                )
                              : // 'Nenhum' também respeita limites
                              ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxValueWidth),
                                  child: Text(
                                    'Nenhum',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: noneColor,
                                      fontSize: 14 * scale,
                                    ),
                                  ),
                                ),
                        ),

                        SizedBox(width: 8 * scale),

                        // Chevron sempre visível e fora do fluxo de longa string (small fixed size)
                        Icon(Icons.chevron_right, size: 20 * scale, color: chevronColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
