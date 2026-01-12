import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

InputDecoration fieldDecoration({
  required String hint,
  required IconData icon,
  double iconSize = 20,
}) {
  final cm = ColorManager.instance;

  return InputDecoration(
    prefixIcon: Icon(icon, size: iconSize, color: cm.primary),
    hintText: hint,
    hintStyle: TextStyle(color: cm.primary.withOpacity(0.7)),
    filled: true,
    fillColor: cm.background,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cm.card.withOpacity(0.18)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cm.card.withOpacity(0.06)),
    ),
  );
}
