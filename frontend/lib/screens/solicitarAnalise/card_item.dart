class CartItem {
  final String? chemical;
  final String? biological;
  final bool manual;
  CartItem({this.chemical, this.biological, this.manual = false});

  String get display {
    final left = (chemical == null || chemical!.isEmpty) ? '(nenhum químico)' : chemical!;
    final right = (biological == null || biological!.isEmpty) ? '(nenhum biológico)' : biological!;
    return '$left → $right${manual ? ' • manual' : ''}';
  }
}

extension StrExt on String {
  String? ifEmptyNull() {
    final t = trim();
    return t.isEmpty ? null : t;
  }
}
