import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

/// Bottom sheet / dialog para escolha de químico — comportamento idêntico ao
/// showBiologicalPicker, adaptado para dados de químicos.
Future<String?> showChemicalPicker(
  BuildContext context,
  Map<String, List<String>> chemicalByType, {
  double desktopWidthThreshold = 720,
}) {
  if (chemicalByType.isEmpty) {
    return showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => const SizedBox(
        height: 140,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhum químico disponível'),
          ),
        ),
      ),
    );
  }

  final isDesktop = MediaQuery.of(context).size.width >= desktopWidthThreshold;

  if (isDesktop) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: _ChemicalPickerContent(
          chemicalByType: chemicalByType,
          isDialog: true,
        ),
      ),
    );
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    builder: (_) => _ChemicalPickerContent(
      chemicalByType: chemicalByType,
      isDialog: false,
    ),
  );
}

class _ChemicalPickerContent extends StatefulWidget {
  final Map<String, List<String>> chemicalByType;
  final bool isDialog;

  const _ChemicalPickerContent({
    required this.chemicalByType,
    required this.isDialog,
  });

  @override
  State<_ChemicalPickerContent> createState() => _ChemicalPickerContentState();
}

class _ChemicalPickerContentState extends State<_ChemicalPickerContent> {
  late final List<String> keys;
  String? openedKey;
  String query = '';

  @override
  void initState() {
    super.initState();
    keys = widget.chemicalByType.keys.toList();
    openedKey = keys.isNotEmpty ? keys.first : null;
  }

  /// Ícone definido pelo nome do tipo (case-insensitive) para químicos.
  IconData _iconForType(String type) {
    final t = type.toLowerCase();

    if (t.contains('fungicida') || t.contains('fungi') || t.contains('fungo')) {
      return Icons.grass_rounded;
    }
    if (t.contains('inset') || t.contains('inseticida') || t.contains('inseto')) {
      return Icons.bug_report_rounded;
    }
    if (t.contains('herbicida') || t.contains('herbi') || t.contains('erva')) {
      return Icons.local_florist_rounded;
    }
    if (t.contains('acaricida') || t.contains('acari')) {
      return Icons.spa_rounded;
    }

    return Icons.science_rounded; // fallback
  }

  Color _iconColorForType(String type, ColorManager cm) {
    final t = type.toLowerCase();

    if (t.contains('fungicida') || t.contains('fungi') || t.contains('fungo')) {
      return Colors.green;
    }
    if (t.contains('inset') || t.contains('inseticida') || t.contains('inseto')) {
      return Colors.deepOrange;
    }
    if (t.contains('herbicida') || t.contains('herbi') || t.contains('erva')) {
      return Colors.teal;
    }
    if (t.contains('acaricida') || t.contains('acari')) {
      return Colors.brown;
    }

    return cm.primary;
  }

  // Utilitário para escurecer levemente uma cor (para criar variações do gradiente)
  Color _darken(Color color, [double amount = 0.12]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (_, __) {
        final cm = ColorManager.instance;

        final primary = cm.primary;
        final background = cm.background;
        final card = cm.card.withOpacity(0.96);
        final chipBg = cm.highlightText.withOpacity(0.18);

        final OutlineInputBorder border = OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.25)),
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.isDialog ? 820 : double.infinity,
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Material(
              elevation: widget.isDialog ? 16 : 0,
              color: background,
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  // HEADER (gradiente idêntico ao biological picker)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(18)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.55, 1.0],
                        colors: [
                          primary,
                          _darken(primary, 0.08),
                          _darken(primary, 0.20),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _darken(primary, 0.45).withOpacity(0.22),
                          offset: const Offset(0, 6),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: const Icon(
                            Icons.science_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Escolha químico',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(null),
                        ),
                      ],
                    ),
                  ),

                  // SEARCH
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: primary),
                        hintText: 'Pesquisar no tipo aberto...',
                        filled: true,
                        fillColor: card.withOpacity(0.08),
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border.copyWith(
                          borderSide: BorderSide(color: primary.withOpacity(0.45)),
                        ),
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ),

                  // GAVETAS COM ÍCONE DINÂMICO
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SingleChildScrollView(
                        child: ExpansionPanelList.radio(
                          initialOpenPanelValue: openedKey,
                          expandedHeaderPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          animationDuration: const Duration(milliseconds: 200),
                          expansionCallback: (i, isOpen) {
                            setState(() {
                              openedKey = isOpen ? null : keys[i];
                            });
                          },
                          children: keys.map((type) {
                            final items = widget.chemicalByType[type] ?? [];
                            final filtered = type == openedKey && query.isNotEmpty
                                ? items
                                    .where((e) => e.toLowerCase().contains(query.toLowerCase()))
                                    .toList()
                                : items;

                            return ExpansionPanelRadio(
                              value: type,
                              headerBuilder: (_, __) => ListTile(
                                leading: Icon(
                                  _iconForType(type),
                                  color: _iconColorForType(type, cm),
                                ),
                                title: Text(
                                  type,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${items.length} itens',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              canTapOnHeader: true,
                              body: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: filtered.isEmpty
                                    ? Text('Nenhum item encontrado.', style: TextStyle(color: Colors.black.withOpacity(0.6)))
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: filtered.map((p) {
                                          return ActionChip(
                                            backgroundColor: chipBg,
                                            label: ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 220),
                                              child: Text(
                                                p,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            onPressed: () => Navigator.of(context).pop(p),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
