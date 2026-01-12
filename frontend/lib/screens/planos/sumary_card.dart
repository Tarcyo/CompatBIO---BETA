import 'dart:math';
import 'package:flutter/material.dart';
import 'package:planos/screens/planos/plans_page_campact.dart';
import 'package:planos/styles/syles.dart';

/// Small central card that shows "Meus Créditos / Meu Plano" and redirects to PlansPageCompact.
class CreditsSummaryCard extends StatelessWidget {
  
  final String currentPlan;
  final int creditsIncludedPerMonth;
  final int creditsAvailable;

  const CreditsSummaryCard({
    super.key,
    required this.currentPlan,
    required this.creditsIncludedPerMonth,
    required this.creditsAvailable,
  });

  @override
  Widget build(BuildContext context) {
    // Reage a mudanças do ColorManager sem quebrar nada
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        // Responsividade horizontal e vertical:
        // - em larguras grandes: largura = parentWidth - 32 (margem curta nas laterais)
        // - em alturas grandes: altura = parentHeight - 48 (margem curta top/bottom)
        return LayoutBuilder(builder: (context, box) {
          final parentW = box.maxWidth;
          final parentH = box.maxHeight;
          final cardWidth = parentW > 900
              ? parentW - 32
              : min(820.0, max(360.0, parentW - 24));

          final bool fillHeight = parentH.isFinite && parentH > 700;
          final double? cardHeight =
              fillHeight ? (parentH - 48.0).clamp(320.0, parentH) : null;

          final card = Card(
            // card principal mais suave
            color: cm.card.withOpacity(0.12),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: cm.card.withOpacity(0.6), width: 1.4),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // header
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: cm.primary, size: 26),
                      const SizedBox(width: 12),
                      Text(
                        'Meus Créditos',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: cm.explicitText,
                        ),
                      ),
                      const Spacer(),
                      // quick action to go to plans (button with themed colors)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlansPageCompact()),
                        ),
                        icon: Icon(Icons.upgrade, size: 18, color: cm.text),
                        label: Text(
                          'Planos',
                          style: TextStyle(color: cm.text),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cm.primary,
                          foregroundColor: cm.text,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Compact row: plan mini-card + CTA (responsive)
                  LayoutBuilder(builder: (context, box) {
                    final isNarrow = box.maxWidth < 560;
                    if (isNarrow) {
                      // vertical stacking on narrow screens
                      return Column(
                        children: [
                          _planMiniTile(context, cm),
                          const SizedBox(height: 12),
                          _creditsMiniTile(context, cm),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(child: _planMiniTile(context, cm)),
                          const SizedBox(width: 14),
                          Expanded(child: _creditsMiniTile(context, cm)),
                        ],
                      );
                    }
                  }),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: cm.explicitText.withOpacity(0.45)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Compre créditos avulsos quando precisar',
                          style: TextStyle(
                            color: cm.explicitText.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          // Se cardHeight foi definido, envolvemos em SizedBox para forçar altura mínima/ocupação.
          return SizedBox(
            width: cardWidth.clamp(340.0, parentW),
            child: cardHeight != null ? SizedBox(height: cardHeight, child: card) : card,
          );
        });
      },
    );
  }

  Widget _planMiniTile(BuildContext context, ColorManager cm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cm.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cm.card.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: cm.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plano atual',
                    style: TextStyle(fontSize: 13, color: cm.explicitText.withOpacity(0.7))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      currentPlan,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: cm.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cm.ok,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Atual',
                        style: TextStyle(
                          color: cm.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _creditsMiniTile(BuildContext context, ColorManager cm) {
    return InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansPageCompact())),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cm.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cm.card.withOpacity(0.20)),
        ),
        child: Row(
          children: [
            Icon(Icons.credit_score, color: cm.text, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meus créditos',
                      style: TextStyle(fontSize: 13, color: cm.text.withOpacity(0.9))),
                  const SizedBox(height: 4),
                  Text(
                    '$creditsAvailable disponíveis • $creditsIncludedPerMonth/mês',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cm.text,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cm.text.withOpacity(0.85), size: 20),
          ],
        ),
      ),
    );
  }
}
