// lib/screens/resultadosAdmin/header_row.dart
import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

/// ChemicalCardHeader component (gradiente) — reutilizado para consistência visual
/// Projetado para ser usado como o topo **dentro** do painel/card (não flutuante).
class ChemicalCardHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final Color primary;
  final double borderRadius;
  final Widget? trailing;
  final double verticalPadding;
  final double horizontalPadding;
  final double scale;

  const ChemicalCardHeader({
    Key? key,
    required this.title,
    required this.leadingIcon,
    required this.primary,
    this.trailing,
    this.borderRadius = 18,
    this.verticalPadding = 14,
    this.horizontalPadding = 16,
    this.scale = 1.0,
  }) : super(key: key);

  Color _darken(Color color, [double amount = 0.12]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final primaryMid = _darken(primary, 0.08);
    final primaryEnd = _darken(primary, 0.20);
    final shadowColor = _darken(primary, 0.45).withOpacity(0.18);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final iconSize = (14.0 * scale + 8.0).clamp(18.0, 40.0);
        final titleFont = isCompact
            ? (16.0 * scale).clamp(12.0, 22.0)
            : (18.0 * scale + 4.0).clamp(16.0, 32.0);

        return Container(
          // importante: borda apenas na parte superior para encaixar no card
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(borderRadius),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.55, 1.0],
              colors: [primary, primaryMid, primaryEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: const Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all((8.0 * scale).clamp(6.0, 16.0)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(leadingIcon, color: Colors.white, size: iconSize),
              ),
              SizedBox(width: 10 * scale),
              // título ocupa o restante e evita overflow
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: titleFont,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8 * scale),
              if (trailing != null)
                Builder(
                  builder: (ctx) {
                    if (isCompact) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 120 * scale),
                        child: trailing!,
                      );
                    }
                    return trailing!;
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// HeaderRow — wrapper leve que fornece o header pronto para ser **colocado dentro do card**.
/// Use-o como primeiro filho do seu painel/card para que o header faça parte do card (não flutuante).
class HeaderRow extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onRefresh;

  const HeaderRow({super.key, required this.isMobile, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;
        final double scale = isMobile ? 1.0 : 1.02;

        // trailing pequeno com botão de refresh, mantendo aparência compacta
        final trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Novo', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  side: BorderSide(
                    color: Colors.white,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        );

        return ChemicalCardHeader(
          title: 'Resultados',
          leadingIcon: Icons.task_alt_rounded,
          primary: cm.primary,
          borderRadius: 12,
          verticalPadding: 12 * scale,
          horizontalPadding: 14 * scale,
          scale: scale,
          trailing: trailing,
        );
      },
    );
  }
}
