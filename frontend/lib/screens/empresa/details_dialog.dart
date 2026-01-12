// FILE: lib/widgets/empresa_details_dialog.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:planos/screens/empresa/empresaClass.dart';
import 'package:planos/styles/syles.dart';

class EmpresaDetailsDialog extends StatelessWidget {
  final String baseUrl;
  final Empresa empresa;
  const EmpresaDetailsDialog({Key? key, required this.baseUrl, required this.empresa}) : super(key: key);

  String _abs(String? logo) {
    if (logo == null) return '';
    if (logo.startsWith('http')) return logo;
    return baseUrl + (logo.startsWith('/') ? '' : '/') + logo;
  }

  static Color _staticColorFromHex(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) return Color(int.parse('0xFF$h'));
    } catch (_) {}
    return Colors.grey;
  }

  Widget _row(String label, String value, Color textColor) => Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
          Text(value, style: TextStyle(color: textColor)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;

    // tentativa de interpretar a cor tema. Se falhar, reportamos a exceção e
    // usamos diálogo transparente (pedido do usuário).
    Color? parsedThemeColor;
    bool useTransparentCard = false;
    try {
      final raw = (empresa.corTema ).toString().trim();
      if (raw.isNotEmpty) {
        // tenta com ColorManager.fromHex (aceita RRGGBB ou AARRGGBB ou #...)
        parsedThemeColor = ColorManager.fromHex(raw);
      }
    } catch (e, st) {
      // reporta exceção ao sistema de erros do Flutter para "abrir uma exceção"
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'EmpresaDetailsDialog',
          context: ErrorDescription('Falha ao converter empresa.corTema para Color'),
          informationCollector: () sync* {
            yield DiagnosticsProperty<Empresa>('empresa', empresa, style: DiagnosticsTreeStyle.errorProperty);
            yield DiagnosticsProperty<String>('raw_corTema', empresa.corTema );
          },
        ),
      );
      useTransparentCard = true;
    }

    final backgroundColor = cm.text;
    final logoBgColor = useTransparentCard ? Colors.transparent : cm.card.withOpacity(0.12);
    final textColor = cm.explicitText;

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: logoBgColor,
                      child: empresa.logo == null || empresa.logo!.isEmpty
                          ? Icon(Icons.business, size: 36, color: textColor.withOpacity(0.6))
                          : Image.network(
                              _abs(empresa.logo),
                              fit: BoxFit.cover,
                              errorBuilder: (c, o, s) => Icon(Icons.broken_image, color: textColor.withOpacity(0.6)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      empresa.nome,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: cm.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: textColor.withOpacity(0.12)),
              const SizedBox(height: 8),
              _row('ID', empresa.id.toString(), textColor),
              const SizedBox(height: 8),
              _row('CNPJ', empresa.cnpj, textColor),
              const SizedBox(height: 8),
              Row(children: [
                Text('Cor tema', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(width: 12),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: parsedThemeColor ?? _staticColorFromHex(empresa.corTema),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(empresa.corTema, style: TextStyle(color: textColor)),
              ]),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fechar', style: TextStyle(color: cm.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
