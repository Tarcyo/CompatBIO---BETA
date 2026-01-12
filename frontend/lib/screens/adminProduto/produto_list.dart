// FILE: lib/screens/adminProduto/produto_list_item.dart

import 'package:flutter/material.dart';
import 'package:planos/screens/adminProduto/produtoItem.dart';
import 'package:planos/styles/syles.dart';

class ProdutoListItem extends StatelessWidget {
  final ProdutoItem produto;
  final bool isMobile;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProdutoListItem({
    Key? key,
    required this.produto,
    required this.isMobile,
    this.onTap,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Responsive scale based on available width
    final vw = MediaQuery.of(context).size.width;
    final double baseScale = vw < 360 ? 0.88 : (vw < 420 ? 0.95 : 1.0);

    final isBio = produto.categoria == ProdutoCategoria.biologico;

    final cardBg = ColorManager.instance.card.withOpacity(0.06);
    final leadingBg = isBio
        ? ColorManager.instance.ok.withOpacity(0.08)
        : ColorManager.instance.primary.withOpacity(0.08);
    final leadingIconColor = isBio ? ColorManager.instance.ok : ColorManager.instance.primary;
    final pillBg = isBio ? ColorManager.instance.ok.withOpacity(0.08) : ColorManager.instance.primary.withOpacity(0.08);
    final pillTextColor = isBio ? ColorManager.instance.ok : ColorManager.instance.primary;
    final titleColor = ColorManager.instance.explicitText;
    final subtitleColor = ColorManager.instance.explicitText.withOpacity(0.8);

    // Sizes (adaptive)
    final double leadingSize = (44.0 * baseScale).clamp(36.0, 56.0);
    final double iconSize = (18.0 * baseScale).clamp(14.0, 24.0);
    final double titleFont = (15.0 * baseScale).clamp(13.0, 18.0);
    final double subtitleFont = (13.0 * baseScale).clamp(11.0, 14.0);
    final double actionIconSize = (20.0 * baseScale).clamp(18.0, 24.0);
    final double pillFont = (12.0 * baseScale).clamp(11.0, 14.0);

    // Demo/icon helpers
    Widget demoStatusIcon({double size = 18}) {
      if (produto.demo) {
        return Tooltip(
          message: 'Demo',
          child: Icon(
            Icons.close_rounded,
            size: size,
            color: ColorManager.instance.emergency,
          ),
        );
      } else {
        return Tooltip(
          message: 'Sem demo',
          child: Icon(
            Icons.emoji_events_rounded,
            size: size,
            color: ColorManager.instance.ok,
          ),
        );
      }
    }

    // Action buttons (kept consistent; wrapped to ensure minimum tap area)
    Widget actionButtons({required bool compact}) {
      final double btnSize = compact ? 40.0 : 44.0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: Icon(Icons.edit_rounded, color: ColorManager.instance.primary, size: actionIconSize),
            ),
          ),
          SizedBox(width: 8 * baseScale),
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              tooltip: 'Deletar',
              onPressed: onDelete,
              icon: Icon(Icons.delete_rounded, color: ColorManager.instance.emergency, size: actionIconSize),
            ),
          ),
        ],
      );
    }

    // MOBILE: Apenas ícone, nome e botões editar/deletar (visual limpo)
    if (isMobile) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12 * baseScale, vertical: 10 * baseScale),
            child: Row(
              children: [
                // Icon
                Container(
                  width: leadingSize,
                  height: leadingSize,
                  decoration: BoxDecoration(
                    color: leadingBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBio ? Icons.eco_rounded : Icons.science_rounded,
                    color: leadingIconColor,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: 12 * baseScale),
                // Apenas o nome (legível, truncado)
                Expanded(
                  child: Text(
                    produto.nome,
                    style: TextStyle(fontWeight: FontWeight.w700, color: titleColor, fontSize: titleFont),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 12 * baseScale),
                // Ações (editar / deletar) — visíveis no mobile
                actionButtons(compact: true),
              ],
            ),
          ),
        ),
      );
    }

    // DESKTOP/TABLET: versão completa (nome, tipo, categoria, demo, ações)
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * baseScale, vertical: 12 * baseScale),
      decoration: BoxDecoration(
        color: ColorManager.instance.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              produto.nome,
              style: TextStyle(fontWeight: FontWeight.w700, color: titleColor, fontSize: titleFont),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              produto.tipo,
              style: TextStyle(color: subtitleColor, fontSize: subtitleFont),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * baseScale, vertical: 6 * baseScale),
              decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
              child: Text(isBio ? 'Biológico' : 'Químico', style: TextStyle(color: pillTextColor, fontWeight: FontWeight.w700, fontSize: pillFont), textAlign: TextAlign.center),
            ),
          ),
          SizedBox(width: 8 * baseScale),
          SizedBox(
            width: 48 * baseScale,
            child: Center(child: demoStatusIcon(size: (20.0 * baseScale).clamp(16.0, 24.0))),
          ),
          SizedBox(width: 8 * baseScale),
          actionButtons(compact: false),
        ],
      ),
    );
  }
}
