import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

class CreditsWidget extends StatelessWidget {
  final int credits;
  final double globalScale;

  const CreditsWidget({
    super.key,
    required this.credits,
    this.globalScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final double textScale = MediaQuery.of(context).textScaleFactor;

    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * globalScale,
            vertical: 8 * globalScale,
          ),
          decoration: BoxDecoration(
            color: cm.card.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20 * globalScale),
            border: Border.all(color: cm.card.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 18 * globalScale,
                color: cm.text,
              ),
              SizedBox(width: 8 * globalScale),
              Text(
                'Meus créditos: $credits',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13 * textScale * globalScale,
                  color: cm.text
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
