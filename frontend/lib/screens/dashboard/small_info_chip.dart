import 'package:flutter/material.dart';

class SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;

  const SmallInfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: Colors.teal.shade50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * scale, color: Colors.teal),
          SizedBox(width: 8 * scale),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13 * scale)),
        ],
      ),
    );
  }
}
