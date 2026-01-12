// FILE: lib/widgets/plano_card.dart

import 'package:flutter/material.dart';
import 'package:planos/screens/listaDePlanos/plano_class.dart';
import 'package:planos/styles/syles.dart';

class PlanoCard extends StatelessWidget {
  final Plano plano;
  final double scale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlanoCard({
    Key? key,
    required this.plano,
    required this.scale,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  bool _isEnterprisePlano(Plano p) {
    final nome = p.nome.toLowerCase();
    return nome.contains('enterprise') ||
        nome.contains('juridic') ||
        nome.contains('jurídica') ||
        nome.contains('pj');
  }

  @override
  Widget build(BuildContext context) {
    final p = plano;
    final cm = ColorManager.instance;

    // Slightly increased padding and font sizes to make the cards feel taller
    final horizontalPadding = 18.0 * scale;
    final verticalPadding = 16.0 * scale;
    final titleSize = 17.0 * scale;
    final radius = 12.0 * scale;

    final isEnterprise = _isEnterprisePlano(p);
    final maxColText = p.maximoColaboradores == 0 ? 'Ilimitado' : '${p.maximoColaboradores}';

    // Make the whole card tappable for edit by wrapping with InkWell.
    // We keep the delete action as a dedicated button on the right.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            // fundo suave do card seguindo o padrão usado no resto da UI
            color: cm.card.withOpacity(0.12),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: cm.card.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 6 * scale,
                height: double.infinity,
                decoration: BoxDecoration(
                  // faixa lateral usa primary (um pouco mais suave)
                  color: cm.primary.withOpacity(0.35),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    bottomLeft: Radius.circular(radius),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Row(
                    children: [
                      // left content (main text)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Title row: name + optional enterprise badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    p.nome,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: titleSize,
                                      color: cm.explicitText,
                                    ),
                                  ),
                                ),
                                if (isEnterprise)
                                  Container(
                                    margin: EdgeInsets.only(left: 8 * scale),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8 * scale, vertical: 4 * scale),
                                    decoration: BoxDecoration(
                                      color: cm.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cm.primary.withOpacity(0.16)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.business, size: 14 * scale, color: cm.primary),
                                        SizedBox(width: 6 * scale),
                                        Text(
                                          'Enterprise',
                                          style: TextStyle(
                                              fontSize: 11 * scale,
                                              fontWeight: FontWeight.w700,
                                              color: cm.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            SizedBox(height: 6 * scale),

                            Text(
                              'Créditos/mês: ${p.quantidadeCreditoMensal}',
                              style: TextStyle(color: cm.explicitText.withOpacity(0.75)),
                            ),

                            SizedBox(height: 4 * scale),

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Preço mensal: R\$ ${p.precoMensal}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cm.explicitText,
                                    ),
                                  ),
                                ),
                                // If enterprise, show a compact text indicator next to the price
                                if (isEnterprise)
                                  Container(
                                    margin: EdgeInsets.only(left: 8 * scale),
                                    padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
                                    decoration: BoxDecoration(
                                      color: cm.card.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cm.card.withOpacity(0.06)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.group, size: 14 * scale, color: cm.explicitText.withOpacity(0.85)),
                                        SizedBox(width: 6 * scale),
                                        Text(
                                          maxColText,
                                          style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w700, color: cm.explicitText),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            // Additional explicit line (for clarity) showing max collaborators for enterprise plans
                            if (isEnterprise) ...[
                              SizedBox(height: 8 * scale),
                              Text(
                                'Máx. colaboradores: $maxColText',
                                style: TextStyle(fontSize: 13 * scale, color: cm.explicitText.withOpacity(0.85)),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // actions (delete) - keep small and touch-friendly
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // removed dedicated edit button — whole card is tappable for edit
                          InkResponse(
                            onTap: () {
                              // Call delete callback.
                              onDelete();
                            },
                            radius: 22 * scale,
                            child: CircleAvatar(
                              radius: 20 * scale,
                              backgroundColor: cm.background,
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: cm.emergency,
                                size: 18 * scale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
