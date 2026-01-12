// FILE: lib/widgets/create_produto_dialog.dart

import 'package:flutter/material.dart';
import 'package:planos/screens/adminProduto/createProduto.dart';

class CreateProdutoDialog extends StatelessWidget {
  const CreateProdutoDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CreateProdutoForm(),
        ],
      ),
    );
  }
}
