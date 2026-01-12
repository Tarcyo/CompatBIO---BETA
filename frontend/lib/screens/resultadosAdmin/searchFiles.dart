// lib/screens/resultadosAdmin/searchFiles.dart
import 'package:flutter/material.dart';
import 'package:planos/screens/resultadosAdmin/product_simple.dart';
import 'package:planos/styles/syles.dart';

class ResultadosFilter {
  String q = '';
  String? resultadoFinal;
}

class SearchFilter extends StatelessWidget {
  final bool isMobile;
  final TextEditingController searchController;
  final ResultadosFilter filter;
  final VoidCallback onApplyFilters;
  final List<ProdutoSimple> biologicos;
  final List<ProdutoSimple> quimicos;

  const SearchFilter({
    super.key,
    required this.isMobile,
    required this.searchController,
    required this.filter,
    required this.onApplyFilters,
    required this.biologicos,
    required this.quimicos,
  });

  List<DropdownMenuItem<String?>> _buildResultItems(ColorManager cm) {
    return [
      DropdownMenuItem<String?>(
        value: null,
        child: Text('Todos', style: TextStyle(color: cm.text)),
      ),
      DropdownMenuItem<String?>(
        value: 'Compatível',
        child: Text('Compatível', style: TextStyle(color: cm.text)),
      ),
      DropdownMenuItem<String?>(
        value: 'Incompatível',
        child: Text('Incompatível', style: TextStyle(color: cm.text)),
      ),
      DropdownMenuItem<String?>(
        value: 'Parcial',
        child: Text('Parcial', style: TextStyle(color: cm.text)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;
        final textGray = cm.text;
        final softCard = cm.card.withOpacity(0.7);
        final softBorder = cm.card.withOpacity(0.6);

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: softCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: softBorder),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onApplyFilters(),
                  style: TextStyle(color: cm.explicitText),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: cm.primary,
                    ),
                    hintText: 'Buscar por produto, descrição...',
                    hintStyle: TextStyle(color: textGray),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.clear_rounded, color: cm.primary),
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              searchController.clear();
                              onApplyFilters();
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: softCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: softBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded, color: textGray),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String?>(
                        value: filter.resultadoFinal,
                        iconEnabledColor: Colors.white,
                        focusColor: Colors.black,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: Text(
                          'Filtrar por resultado',
                          style: TextStyle(color: textGray),
                        ),
                        dropdownColor: Colors.blue,
                        items: _buildResultItems(cm),
                        onChanged: (v) {
                          filter.resultadoFinal = v;
                          onApplyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: softCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: softBorder),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onApplyFilters(),
                  style: TextStyle(color: cm.explicitText),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: cm.primary,
                    ),
                    hintText: 'Buscar por produto, descrição...',
                    hintStyle: TextStyle(color: textGray),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.clear_rounded, color: cm.primary),
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              searchController.clear();
                              onApplyFilters();
                            },
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: softCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: softBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, color: textGray),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: filter.resultadoFinal,
                    underline: const SizedBox(),
                    hint: Text(
                      'Filtrar por resultado',
                      style: TextStyle(color: textGray),
                    ),
                    dropdownColor: softCard,
                    items: _buildResultItems(cm),
                    onChanged: (v) {
                      filter.resultadoFinal = v;
                      onApplyFilters();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
