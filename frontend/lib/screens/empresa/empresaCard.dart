// FILE: lib/widgets/empresa_card.dart
import 'package:flutter/material.dart';
import 'package:planos/screens/empresa/details_dialog.dart';
import 'package:planos/screens/empresa/empresaClass.dart';
import 'package:planos/styles/syles.dart';

class EmpresaCard extends StatelessWidget {
  final Empresa empresa;
  final String baseUrl;
  final double scale;
  final VoidCallback onEdit;

  const EmpresaCard({
    Key? key,
    required this.empresa,
    required this.baseUrl,
    required this.scale,
    required this.onEdit,
  }) : super(key: key);

  String _absoluteLogo(String? logo) {
    if (logo == null) return '';
    if (logo.startsWith('http')) return logo;
    return baseUrl + (logo.startsWith('/') ? '' : '/') + logo;
  }

  Color _colorFromHex(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) return Color(int.parse('0xFF$h'));
    } catch (_) {}
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final e = empresa;
    final cm = ColorManager.instance;

    final thumbSize = 100.0 * (scale.clamp(0.9, 1.4));
    final borderRadius = BorderRadius.circular(12 * scale);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () async {
          await showDialog(
            context: context,
            builder: (_) => EmpresaDetailsDialog(
              baseUrl: baseUrl,
              empresa: e,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: cm.card.withOpacity(0.12),
            borderRadius: borderRadius,
            border: Border.all(color: cm.card.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 6 * scale,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _colorFromHex(e.corTema),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12 * scale),
                    bottomLeft: Radius.circular(12 * scale),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * scale,
                    vertical: 14 * scale,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          color: cm.card.withOpacity(0.08),
                          child: e.logo == null || e.logo!.isEmpty
                              ? Center(
                                  child: Icon(
                                    Icons.apartment_rounded,
                                    size: 44 * scale,
                                    color: cm.explicitText.withOpacity(0.6),
                                  ),
                                )
                              : Image.network(
                                  _absoluteLogo(e.logo),
                                  key: ValueKey(e.logo), // força reload quando a URL muda
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) => Center(
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      color: cm.explicitText.withOpacity(0.6),
                                      size: 44 * scale,
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(width: 16 * scale),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              e.nome,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16 * scale,
                                color: cm.explicitText,
                              ),
                            ),
                           
                           
                          ],
                        ),
                      ),

                      // Removido o botão dedicado para abrir detalhes.
                      // Mantemos apenas o botão de edição (onEdit).
                      Container(
                        margin: EdgeInsets.only(right: 8 * scale),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkResponse(
                              onTap: onEdit,
                              radius: 22,
                              child: CircleAvatar(
                                radius: 18 * scale,
                                backgroundColor: cm.text,
                                child: Icon(
                                  Icons.edit_rounded,
                                  color: cm.explicitText,
                                  size: 18 * scale,
                                ),
                              ),
                            ),
                          ],
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
}
