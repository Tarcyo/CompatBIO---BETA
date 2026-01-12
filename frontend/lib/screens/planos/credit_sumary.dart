import 'package:flutter/material.dart';
import 'package:planos/screens/planos/sumary_card.dart';
import 'package:planos/styles/syles.dart';
// ajuste o path se necessário

/// Demo page entrypoint (mostra o cartão resumido que leva à PlansPageCompact)
class CreditsSummaryDemoPage extends StatelessWidget {
  const CreditsSummaryDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder para reagir a mudanças no ColorManager
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return Scaffold(
          backgroundColor: cm.background,
          body: SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              // Garantir centralização vertical quando couber; senão permitir scroll.
              return SingleChildScrollView(
                padding: const EdgeInsets.all(18.0),
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: CreditsSummaryCard(
                      currentPlan: 'Starter',
                      creditsIncludedPerMonth: 10,
                      creditsAvailable: 7,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
