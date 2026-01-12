// lib/screens/resultadosAdmin/resultados_list.dart
import 'package:flutter/material.dart';
import 'package:planos/screens/resultadosAdmin/resuk_row.dart';
import 'package:planos/screens/resultadosAdmin/resultadoItem.dart';
import 'package:planos/styles/syles.dart';

class ResultadosList extends StatelessWidget {
  final bool isMobile;
  final bool loading;
  final String? error;
  final List<ResultadoItem> items;
  final List<ResultadoItem> filtrados;
  final Future<void> Function() onRefresh;
  final void Function(String text, String label) copyCallback;

  // callbacks para atualizar a UI no pai
  final void Function(ResultadoItem updated)? onItemUpdated;
  final void Function(int id)? onItemDeleted;

  const ResultadosList({
    super.key,
    required this.isMobile,
    required this.loading,
    required this.error,
    required this.items,
    required this.filtrados,
    required this.onRefresh,
    required this.copyCallback,
    this.onItemUpdated,
    this.onItemDeleted,
  });

  @override
  Widget build(BuildContext context) {
    Widget tableHeader(ColorManager cm) {
      if (isMobile) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cm.card.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cm.card.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text('Químico', style: TextStyle(fontWeight: FontWeight.bold, color: cm.explicitText))),
            Expanded(flex: 3, child: Text('Biológico', style: TextStyle(fontWeight: FontWeight.bold, color: cm.explicitText))),
            Expanded(flex: 3, child: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold, color: cm.explicitText))),
            Expanded(flex: 2, child: Text('Resultado', style: TextStyle(fontWeight: FontWeight.bold, color: cm.explicitText))),
            Expanded(flex: 2, child: Text('Criado em', style: TextStyle(fontWeight: FontWeight.bold, color: cm.explicitText))),
            const SizedBox(width: 24),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        // content: não rolável — o scroll é do SingleChildScrollView exterior
        final Widget content = filtrados.isEmpty
            ? Column(
                children: [
                  const SizedBox(height: 24),
                  Center(child: Text('Nenhum resultado encontrado.', style: TextStyle(color: cm.explicitText))),
                  const SizedBox(height: 24),
                ],
              )
            : Column(
                children: [
                  // lista não-rolável, shrinkWrap
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = filtrados[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: ResultRow(
                          r: r,
                          isMobile: isMobile,
                          copyCallback: copyCallback,
                          onUpdated: (updated) {
                            if (onItemUpdated != null) onItemUpdated!(updated);
                          },
                          onDeleted: () {
                            if (onItemDeleted != null) onItemDeleted!(r.id);
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text('Exibindo ${filtrados.length}', style: TextStyle(color: cm.explicitText.withOpacity(0.7), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              );

        final Widget body = loading && items.isEmpty
            ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(cm.primary)))
            : error != null && items.isEmpty
                ? Center(child: Text(error!, style: TextStyle(color: cm.emergency)))
                : content;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cm.card.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cm.card.withOpacity(0.6)),
          ),
          child: Column(
            children: [
              tableHeader(cm),
              const SizedBox(height: 12),
              body,
            ],
          ),
        );
      },
    );
  }
}
