// lib/screens/resultadosAdmin/result_utils.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:planos/styles/syles.dart';

String? tryParseError(String body) {
  try {
    final b = body.isEmpty ? null : body;
    return b;
  } catch (_) {
    return null;
  }
}

IconData iconForResultado(String? resultado) {
  final r = (resultado ?? '').toLowerCase();
  if (r.contains('incomp') ||
      r.contains('incompat') ||
      r.contains('incompativel') ||
      r.contains('incompativel')) {
    return Icons.cancel_rounded;
  }
  if (r.contains('parc')) return Icons.adjust_rounded;
  if (r.contains('compat') || r.contains('compativel') || r.contains('compativel'))
    return Icons.check_circle_rounded;
  return Icons.cancel_rounded;
}

Color badgeColorForResultado(String? resultado) {
  final cm = ColorManager.instance;
  final r = (resultado ?? '').toLowerCase();
  if (r.contains('incomp') ||
      r.contains('incompat') ||
      r.contains('incompativel') ||
      r.contains('incompativel')) return cm.emergency;
  if (r.contains('parc')) return cm.alert;
  if (r.contains('compat') ||
      r.contains('compativel') ||
      r.contains('compativel')) return cm.ok;
  return cm.emergency;
}

String labelForResultado(String? resultado) {
  final r = (resultado ?? '').toLowerCase();
  if (r.contains('incomp') ||
      r.contains('incompat') ||
      r.contains('incompativel') ||
      r.contains('incompativel')) return 'Incompatível';
  if (r.contains('parc')) return 'Parcial';
  if (r.contains('compat') ||
      r.contains('compativel') ||
      r.contains('compativel')) return 'Compatível';
  if (r.trim().isEmpty) return 'Sem resultado';
  final s = resultado!;
  return s.length > 0 ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}

String formatDate(DateTime d) {
  try {
    return DateFormat('dd/MM/yyyy').format(d.toLocal());
  } catch (_) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

String _normalizeForCompare(String s) {
  final lower = (s).toLowerCase();
  var out = lower;
  const replacements = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c'
  };
  replacements.forEach((k, v) => out = out.replaceAll(k, v));
  out = out.replaceAll(RegExp(r'[^a-z0-9]'), '');
  return out;
}

bool matchResultadoFinal(String raw, String filtro) {
  final rn = _normalizeForCompare(raw);
  final fn = _normalizeForCompare(filtro);

  if (fn.isEmpty) return true;

  if (fn.contains('incompat') || fn.contains('incomp')) {
    return rn.contains('incompat') || rn.contains('incomp');
  }
  if (fn.contains('parc')) return rn.contains('parc');
  if (fn.contains('compat')) {
    if (rn.contains('incompat')) return false;
    return rn.contains('compat');
  }
  return fn.isNotEmpty && rn.contains(fn);
}

Future<void> copyToClipboardAndNotify(BuildContext context, String text, String label) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  final cm = ColorManager.instance;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label copiado'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: cm.primary.withOpacity(0.95),
    ),
  );
}
