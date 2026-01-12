import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

enum HistoryStatus { inProgress, compatible, incompatible, partial }

extension HistoryStatusProps on HistoryStatus {
  String get label {
    switch (this) {
      case HistoryStatus.inProgress:
        return 'Em análise';
      case HistoryStatus.compatible:
        return 'Compatível';
      case HistoryStatus.incompatible:
        return 'Incompatível';
      case HistoryStatus.partial:
        return 'Parcial';
    }
  }

  Color get color {
    switch (this) {
      case HistoryStatus.inProgress:
      case HistoryStatus.partial:
        return ColorManager.instance.alert;
      case HistoryStatus.compatible:
        return ColorManager.instance.ok;
      case HistoryStatus.incompatible:
        return ColorManager.instance.emergency;
    }
  }

  IconData get icon {
    switch (this) {
      case HistoryStatus.inProgress:
        return Icons.hourglass_top_rounded;
      case HistoryStatus.compatible:
        return Icons.check_circle_rounded;
      case HistoryStatus.incompatible:
        return Icons.cancel_rounded;
      case HistoryStatus.partial:
        return Icons.report_problem_rounded;
    }
  }
}

class HistoryItem {
  final DateTime date;
  final String chemical;
  final String biological;
  final HistoryStatus status;
  final String? resultFinal;
  final String? description;

  HistoryItem({
    required this.date,
    required this.chemical,
    required this.biological,
    required this.status,
    this.resultFinal,
    this.description,
  });
}

enum HistoryFilter { all, inProgress, completed }

String formatDate(DateTime dt) {
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy • $hh:$min';
}
