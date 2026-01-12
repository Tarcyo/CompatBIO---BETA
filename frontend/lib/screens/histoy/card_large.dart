import 'package:flutter/material.dart';
import 'package:planos/screens/histoy/large_row.dart';
import 'package:planos/screens/histoy/models.dart';
import 'package:planos/screens/histoy/result_page.dart';
import 'package:planos/styles/syles.dart';

typedef VoidCallbackNullable = void Function();

class HistoryCardLarge extends StatefulWidget {
  final List<HistoryItem> items;
  final VoidCallbackNullable? onUserScrolled; // mantido para compatibilidade (chamado pela página)
  final double bottomInset; // altura extra reservada (ex.: banner + teclado) para evitar overflow

  const HistoryCardLarge({
    super.key,
    required this.items,
    this.onUserScrolled,
    this.bottomInset = 0.0,
  });

  @override
  State<HistoryCardLarge> createState() => _HistoryCardLargeState();
}

class _HistoryCardLargeState extends State<HistoryCardLarge> {
  String query = '';
  HistoryFilter filter = HistoryFilter.all;

  List<HistoryItem> get filtered {
    final q = query.trim().toLowerCase();
    return widget.items.where((it) {
      final matchQ =
          q.isEmpty ||
          it.chemical.toLowerCase().contains(q) ||
          it.biological.toLowerCase().contains(q) ||
          formatDate(it.date).contains(q) ||
          (it.resultFinal ?? '').toLowerCase().contains(q) ||
          (it.description ?? '').toLowerCase().contains(q);
      final matchF =
          filter == HistoryFilter.all ||
          (filter == HistoryFilter.inProgress && it.status == HistoryStatus.inProgress) ||
          (filter == HistoryFilter.completed &&
              (it.status == HistoryStatus.compatible ||
                  it.status == HistoryStatus.incompatible ||
                  it.status == HistoryStatus.partial));
      return matchQ && matchF;
    }).toList();
  }

  void _openHistoryItem(HistoryItem it) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoryResultPage(item: it)));
  }

  ChoiceChip _largeChip({
    required String label,
    required HistoryFilter value,
    required double scale,
  }) {
    final selected = filter == value;
    final cm = ColorManager.instance;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value == HistoryFilter.all
                ? Icons.list_rounded
                : (value == HistoryFilter.inProgress ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded),
            size: 18 * scale,
            color: selected ? cm.text : cm.primary,
          ),
          SizedBox(width: 8 * scale),
          Text(
            label,
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w800,
              color: selected ? cm.text : cm.primary,
            ),
          ),
        ],
      ),
      selected: selected,
      selectedColor: cm.ok,
      backgroundColor: cm.background,
      onSelected: (_) => setState(() => filter = value),
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
      final scale = (maxW / 900).clamp(0.65, 1.18);
      final isNarrow = maxW < 700;

      final list = filtered;

      // Construímos o card como Column de tamanho mínimo (mainAxisSize: min),
      // sem ScrollViews internos — todos os itens serão renderizados.
      final children = <Widget>[];

      // Top: busca + chips
      children.add(Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              style: TextStyle(fontSize: 20 * scale, color: cm.explicitText),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, size: 30 * scale, color: cm.primary),
                hintText: 'Buscar por químico ou biológico...',
                hintStyle: TextStyle(fontSize: 17 * scale, color: cm.primary.withOpacity(0.7)),
                filled: true,
                fillColor: cm.background,
                contentPadding: EdgeInsets.symmetric(vertical: 14 * scale),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22 * scale),
                  borderSide: BorderSide(color: cm.card.withOpacity(0.6)),
                ),
              ),
            ),
          ),
          SizedBox(width: isNarrow ? 10 * scale : 22 * scale),
          if (!isNarrow)
            Wrap(
              spacing: 12 * scale,
              children: [
                _largeChip(label: 'Todos', value: HistoryFilter.all, scale: scale),
                _largeChip(label: 'Em análise', value: HistoryFilter.inProgress, scale: scale),
                _largeChip(label: 'Concluída', value: HistoryFilter.completed, scale: scale),
              ],
            ),
        ],
      ));

      if (isNarrow) {
        children.add(Padding(
          padding: EdgeInsets.only(top: 14 * scale),
          child: Wrap(
            spacing: 10 * scale,
            children: [
              _largeChip(label: 'Todos', value: HistoryFilter.all, scale: scale),
              _largeChip(label: 'Em análise', value: HistoryFilter.inProgress, scale: scale),
              _largeChip(label: 'Concluída', value: HistoryFilter.completed, scale: scale),
            ],
          ),
        ));
      }

      children.add(SizedBox(height: 24 * scale));

      if (!isNarrow) {
        children.add(Container(
          padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 16 * scale),
          decoration: BoxDecoration(
            color: cm.background,
            borderRadius: BorderRadius.circular(18 * scale),
            border: Border.all(color: cm.card.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 22 * scale, color: cm.primary),
                    SizedBox(width: 12 * scale),
                    Text('Data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17 * scale, color: cm.explicitText)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.science_rounded, size: 22 * scale, color: cm.primary),
                    SizedBox(width: 12 * scale),
                    Text('Químico', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17 * scale, color: cm.explicitText)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.bug_report_rounded, size: 22 * scale, color: cm.primary),
                    SizedBox(width: 12 * scale),
                    Text('Biológico', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17 * scale, color: cm.explicitText)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assessment_rounded, size: 22 * scale, color: cm.primary),
                      SizedBox(width: 12 * scale),
                      Text('Resultado', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17 * scale, color: cm.explicitText)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
      }

      children.add(SizedBox(height: 16 * scale));

      // Lista de resultados — todos os itens aparecem aqui (sem scroll interno).
      if (list.isEmpty) {
        children.add(SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Nenhum resultado',
              style: TextStyle(color: cm.explicitText.withOpacity(0.6), fontSize: 20 * scale),
            ),
          ),
        ));
      } else {
        for (var i = 0; i < list.length; i++) {
          final it = list[i];
          children.add(LargeHistoryRow(
            item: it,
            dateText: formatDate(it.date),
            onTap: () => _openHistoryItem(it),
            scale: scale,
            isNarrow: isNarrow,
          ));
          if (i != list.length - 1) {
            children.add(SizedBox(height: 16 * scale));
          }
        }
      }

      // bottom inset spacer (opcional) para evitar que o último item fique escondido por um banner/teclado,
      // mas sem adicionar scroll view interno.
      if (widget.bottomInset > 0) {
        children.add(SizedBox(height: widget.bottomInset));
      }

      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW.clamp(340.0, 1200.0),
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // permite expansão conforme conteúdo
            children: children,
          ),
        ),
      );
    });
  }
}
