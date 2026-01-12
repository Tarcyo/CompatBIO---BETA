// FILE: lib/screens/adminProduto/create_produto_sheet.dart

import 'package:flutter/material.dart';
import 'package:planos/screens/adminProduto/createProduto.dart';
import 'package:planos/styles/syles.dart';

class CreateProdutoSheet extends StatelessWidget {
  const CreateProdutoSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(16));
    final bg = ColorManager.instance.background;
    final handleColor = ColorManager.instance.card.withOpacity(0.12);

    return DraggableScrollableSheet(
      initialChildSize: 0.56,
      minChildSize: 0.32,
      maxChildSize: 0.92,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Stack(
            children: [
              ListView(
                controller: scroll,
                children: [
                  Center(
                    child: SizedBox(
                      width: 48,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: const BorderRadius.all(Radius.circular(6)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The CreateProdutoForm will handle its own internal state and submission
                  const CreateProdutoForm(),
                ],
              ),
              // Note: animation OK indicator is handled inside form
            ],
          ),
        );
      },
    );
  }
}
