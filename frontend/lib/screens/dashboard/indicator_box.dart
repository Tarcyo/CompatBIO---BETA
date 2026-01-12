import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';

class IndicatorBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String badge;
  final double width;
  final double scale;

  const IndicatorBox({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.badge,
    required this.width,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return Container(
          width: width,
          constraints: BoxConstraints(minWidth: 140 * scale, maxWidth: width),
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            color: cm.card.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14 * scale),
            border: Border.all(color: cm.card.withOpacity(0.20), width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10 * scale),
                decoration: BoxDecoration(
                  color: cm.background,
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                child: Icon(icon, color: cm.primary, size: 20 * scale),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13 * scale,
                        color: cm.explicitText.withOpacity(0.85),
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Row(
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w900,
                            color: cm.explicitText,
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        if (badge.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6 * scale, vertical: 4 * scale),
                            decoration: BoxDecoration(
                              color: cm.card.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8 * scale),
                              border:
                                  Border.all(color: cm.card.withOpacity(0.20)),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 11 * scale,
                                fontWeight: FontWeight.w800,
                                color: cm.explicitText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
