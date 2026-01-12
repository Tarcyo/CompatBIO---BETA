import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

class PlanCard extends StatelessWidget {
  final VoidCallback? onTap;
  final String activePlan;

  const PlanCard({super.key, this.onTap, required this.activePlan});

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cm.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cm.card.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.badge_rounded, color: cm.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meu plano',
                    style: TextStyle(fontSize: 12, color: cm.explicitText.withOpacity(0.65)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        activePlan,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: cm.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cm.ok,
                          borderRadius: BorderRadius.circular(8),
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
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cm.explicitText.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class CreditsCard extends StatelessWidget {
  final VoidCallback? onTap;
  final int creditsAvailable;
  final int creditsIncludedPerMonth;

  const CreditsCard({
    super.key,
    this.onTap,
    required this.creditsAvailable,
    required this.creditsIncludedPerMonth,
  });

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cm.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cm.card.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: cm.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meus créditos',
                    style: TextStyle(fontSize: 12, color: cm.explicitText.withOpacity(0.65)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$creditsAvailable disponíveis • $creditsIncludedPerMonth/mês',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: cm.explicitText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cm.explicitText.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
