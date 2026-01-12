import 'package:flutter/material.dart';
import 'package:planos/screens/histoy/models.dart';
import 'package:planos/styles/syles.dart';

class LargeHistoryRow extends StatelessWidget {
  final HistoryItem item;
  final String dateText;
  final VoidCallback? onTap;
  final double scale;
  final bool isNarrow;
  const LargeHistoryRow({
    required this.item,
    required this.dateText,
    this.onTap,
    required this.scale,
    required this.isNarrow,
  });

  // Normaliza (remove acentos e deixa lowercase)
  String _stripDiacritics(String s) {
    var out = s;
    const from = 'áàãâäÁÀÃÂÄéèêëÉÈÊËíìîïÍÌÎÏóòõôöÓÒÕÔÖúùûüÚÙÛÜçÇñÑ';
    const to = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcCnN';
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  String _norm(String? s) {
    if (s == null) return '';
    return _stripDiacritics(s.toString().trim().toLowerCase());
  }

  HistoryStatus _displayStatusFromItem(HistoryItem it) {
    final rf = _norm(it.resultFinal);
    if (rf.isNotEmpty) {
      if (rf.contains('incompat') ||
          rf.contains('incomp') ||
          (rf.contains('nao') && rf.contains('compat'))) {
        return HistoryStatus.incompatible;
      }
      if (rf.contains('parc') || rf.contains('partial'))
        return HistoryStatus.partial;
      if (rf.contains('compat') || rf.contains('compatible'))
        return HistoryStatus.compatible;
    }
    return it.status;
  }

  String _displayLabelFromItem(HistoryItem it) {
    final rf = (it.resultFinal ?? '').trim();
    if (rf.isNotEmpty) return rf;
    return it.status.label;
  }

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;

    final displayStatus = _displayStatusFromItem(item);
    final color = displayStatus.color;
    final label = _displayLabelFromItem(item);
    final icon = displayStatus.icon;
  //  final isInProgressLike =
     //   displayStatus == HistoryStatus.inProgress ||
    //    displayStatus == HistoryStatus.partial;

    if (isNarrow) {
      return Material(
        color: cm.background,
        borderRadius: BorderRadius.circular(18 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18 * scale),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 18 * scale,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * scale),
              border: Border.all(color: cm.card.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 8 * scale,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                ),
                SizedBox(height: 12 * scale),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18 * scale,
                      color: cm.explicitText.withOpacity(0.65),
                    ),
                    SizedBox(width: 10 * scale),
                    Flexible(
                      child: Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w700,
                          color: cm.explicitText,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12 * scale),
                _smallInfoBlock(
                  icon: Icons.science_rounded,
                  title: 'Químico',
                  text: item.chemical,
                  scale: scale,
                ),
                SizedBox(height: 12 * scale),
                _smallInfoBlock(
                  icon: Icons.bubble_chart_rounded,
                  title: 'Biológico',
                  text: item.biological,
                  scale: scale,
                ),
                SizedBox(height: 14 * scale),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * scale,
                      vertical: 10 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(22 * scale),
                      border: Border.all(
                        color: color.withOpacity(0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18 * scale, color: color),
                        SizedBox(width: 10 * scale),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15 * scale,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
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

    // Desktop / tablet layout
    return Material(
      color: cm.background,
      borderRadius: BorderRadius.circular(20 * scale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20 * scale),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20 * scale),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: (10 * scale).clamp(8.0, 14.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20 * scale),
                      bottomLeft: Radius.circular(20 * scale),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18 * scale,
                      vertical: 20 * scale,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 20 * scale,
                                color: cm.explicitText.withOpacity(0.65),
                              ),
                              SizedBox(width: 12 * scale),
                              Flexible(
                                child: Text(
                                  dateText,
                                  style: TextStyle(
                                    fontSize: 16 * scale,
                                    color: cm.explicitText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: _bigPill(
                                  icon: Icons.science_rounded,
                                  label: item.chemical,
                                  scale: scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: _bigPill(
                                  icon: Icons.bubble_chart_rounded,
                                  label: item.biological,
                                  scale: scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16 * scale,
                                vertical: 12 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(24 * scale),
                                border: Border.all(
                                  color: color.withOpacity(0.28),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 18 * scale, color: color),
                                  SizedBox(width: 12 * scale),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 16 * scale,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallInfoBlock({
    required IconData icon,
    required String title,
    required String text,
    required double scale,
  }) {
    final cm = ColorManager.instance;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: cm.background,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: cm.card.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18 * scale, color: cm.primary),
              SizedBox(width: 8 * scale),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w800,
                  color: cm.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Text(
            text,
            style: TextStyle(
              fontSize: 17 * scale,
              fontWeight: FontWeight.w800,
              color: cm.explicitText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigPill({
    required IconData icon,
    required String label,
    required double scale,
  }) {
    final cm = ColorManager.instance;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 14 * scale,
      ),
      decoration: BoxDecoration(
        color: cm.card.withOpacity(0.06),
        borderRadius: BorderRadius.circular(30 * scale),
        border: Border.all(color: cm.card.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22 * scale, color: cm.primary),
          SizedBox(width: 12 * scale),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17 * scale,
                fontWeight: FontWeight.w800,
                color: cm.explicitText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
