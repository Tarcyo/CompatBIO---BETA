import 'package:flutter/material.dart';
import 'package:planos/screens/histoy/models.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';

/// Header reutilizável similar ao ChemicalCardHeader da tela original,
/// mas com nome distinto para evitar colisões.
class ResultCardHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final Color primary;
  final double borderRadius;
  final Widget? trailing;
  final double verticalPadding;
  final double horizontalPadding;
  final double scale;

  const ResultCardHeader({
    Key? key,
    required this.title,
    required this.leadingIcon,
    required this.primary,
    this.trailing,
    this.borderRadius = 18,
    this.verticalPadding = 14,
    this.horizontalPadding = 16,
    this.scale = 1.0,
  }) : super(key: key);

  Color _darken(Color color, [double amount = 0.12]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final primaryMid = _darken(primary, 0.08);
    final primaryEnd = _darken(primary, 0.20);
    final shadowColor = _darken(primary, 0.45).withOpacity(0.22);

    final iconSize = 16.0 * scale + 8.0;
    final titleFont = 18.0 * scale + 4.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.55, 1.0],
          colors: [primary, primaryMid, primaryEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(leadingIcon, color: Colors.white, size: iconSize),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: titleFont,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class HistoryResultPage extends StatefulWidget {
  final HistoryItem item;
  const HistoryResultPage({super.key, required this.item});

  @override
  State<HistoryResultPage> createState() => _HistoryResultPageState();
}

class _HistoryResultPageState extends State<HistoryResultPage> {
  bool _showDetail = false;
  bool _bannerDismissed = false;

  // remove acentos e normaliza para lowercase
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

  // Decide o status a partir do resultadoFinal (preferível) e do status original
  HistoryStatus _displayStatusFromItem(HistoryItem it) {
    final rf = _norm(it.resultFinal);
    if (rf.isNotEmpty) {
      // checar incompatível primeiro
      if (rf.contains('incompat') ||
          rf.contains('incomp') ||
          (rf.contains('nao') && rf.contains('compat')) ||
          rf.contains('not compatible') ||
          rf.contains('incompatible')) {
        return HistoryStatus.incompatible;
      }
      if (rf.contains('parc') || rf.contains('partial')) return HistoryStatus.partial;
      if (rf.contains('compat') || rf.contains('compatible')) return HistoryStatus.compatible;
    }

    // fallback: usa o status fornecido no item
    return it.status;
  }

  String _displayLabelFromItem(HistoryItem it) {
    final rf = (it.resultFinal ?? '').trim();
    if (rf.isNotEmpty) return rf;
    return _displayStatusFromItem(it).label;
  }

  // Retorna a frase coerente para o resumo rápido (apenas aqui, na tela de resultado)
  String _resultSummarySentence(HistoryStatus st) {
    switch (st) {
      case HistoryStatus.compatible:
        return 'O resultado indica compatibilidade total entre os produtos.';
      case HistoryStatus.partial:
        return 'O resultado indica compatibilidade parcial entre os produtos.';
      case HistoryStatus.incompatible:
        return 'O resultado indica incompatibilidade entre os produtos.';
      case HistoryStatus.inProgress:
    }
    return "Resultado pendente.";
  }

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;
    final item = widget.item;
    final displayStatus = _displayStatusFromItem(item);
    final statusColor = displayStatus.color;
    final icon = displayStatus.icon;
    final label = _displayLabelFromItem(item);
    final description = item.description;

    final media = MediaQuery.of(context);
    final vw = media.size.width;
   // final vh = media.size.height;

    // Responsividade: classificações para mobile / tablet / desktop
    final isMobile = vw < 700;
    final isTablet = vw >= 700 && vw < 1100;
    final isDesktop = vw >= 1100;

    // Escalas adaptativas
    final baseScale = isDesktop ? 1.12 : (isTablet ? 1.0 : 0.95);
    final uiScale = baseScale * (isMobile ? 0.98 : 1.0);
    final horizontalMargin = isDesktop ? 40.0 : (isTablet ? 28.0 : 16.0);
    final verticalMargin = isDesktop ? 28.0 : (isTablet ? 20.0 : 14.0);

    final borderColor = statusColor.withOpacity(0.28);

    return Scaffold(
      backgroundColor: cm.background,
      body: SafeArea(
        child: Stack(
          children: [
            // O conteúdo principal escuta notificações de scroll para descartar o banner
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (!_bannerDismissed &&
                    (notification is ScrollStartNotification || (notification.metrics.pixels > 0))) {
                  setState(() {
                    _bannerDismissed = true;
                  });
                }
                return false;
              },
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalMargin,
                    vertical: verticalMargin,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 320,
                      maxWidth: isDesktop ? 1100 : (isTablet ? 900 : 720),
                    ),
                    child: Card(
                      color: cm.card.withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20 * baseScale),
                        side: BorderSide(
                          color: cm.card.withOpacity(0.6),
                          width: 1.6,
                        ),
                      ),
                      elevation: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header muito parecido com a primeira tela
                          ResultCardHeader(
                            title: 'Resultado da análise',
                            leadingIcon: Icons.article_rounded,
                            primary: cm.primary,
                            borderRadius: 20 * baseScale,
                            verticalPadding: 14 * uiScale,
                            horizontalPadding: 16 * uiScale,
                            scale: uiScale,
                            trailing: Padding(
                              padding: EdgeInsets.only(left: 8.0 * uiScale),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14.0 * uiScale),
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    constraints: BoxConstraints(minWidth: 72 * uiScale),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12 * uiScale, vertical: 8 * uiScale),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12 * uiScale),
                                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.close_rounded, color: Colors.white, size: 18 * uiScale),
                                        SizedBox(width: 8 * uiScale),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'FECHAR',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13 * uiScale,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Conteúdo
                          Padding(
                            padding: EdgeInsets.all(18 * uiScale),
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final maxW = box.maxWidth;
                                final isWide = maxW >= 900;
                                final textScale = (maxW / 900).clamp(0.75, 1.15) * uiScale;

                                Widget statusBlock(double rectW, double rectH) {
                                  return Container(
                                    width: rectW,
                                    height: rectH,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [statusColor.withOpacity(0.78), statusColor],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14 * textScale),
                                      border: Border.all(color: borderColor, width: 1.6),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(icon, size: (isMobile ? 46 : 64) * textScale, color: Colors.white),
                                          SizedBox(height: 8 * textScale),
                                          Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 10 * textScale),
                                            child: Text(
                                              label,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: (isMobile ? 15 : 18) * textScale,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // Mobile / narrow: empilhado verticalmente com espaços reduzidos
                                if (!isWide) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded,
                                              color: cm.explicitText.withOpacity(0.7), size: 16 * textScale),
                                          SizedBox(width: 8 * textScale),
                                          Flexible(
                                            child: Text(
                                              formatDate(item.date),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13 * textScale,
                                                color: cm.explicitText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12 * textScale),

                                      // chemical
                                      Container(
                                        padding: EdgeInsets.all(12 * textScale),
                                        decoration: BoxDecoration(
                                          color: cm.background,
                                          borderRadius: BorderRadius.circular(12 * textScale),
                                          border: Border.all(color: statusColor.withOpacity(0.10)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Icon(Icons.science_rounded,
                                                  color: cm.primary, size: 16 * textScale),
                                              SizedBox(width: 8 * textScale),
                                              Text('Químico',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: cm.primary,
                                                    fontSize: 13 * textScale,
                                                  )),
                                            ]),
                                            SizedBox(height: 8 * textScale),
                                            Text(item.chemical,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15 * textScale,
                                                    color: cm.explicitText)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 12 * textScale),

                                      // biological
                                      Container(
                                        padding: EdgeInsets.all(12 * textScale),
                                        decoration: BoxDecoration(
                                          color: cm.background,
                                          borderRadius: BorderRadius.circular(12 * textScale),
                                          border: Border.all(color: statusColor.withOpacity(0.10)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Icon(Icons.bug_report_rounded,
                                                  color: cm.primary, size: 16 * textScale),
                                              SizedBox(width: 8 * textScale),
                                              Text('Biológico',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: cm.primary,
                                                    fontSize: 13 * textScale,
                                                  )),
                                            ]),
                                            SizedBox(height: 8 * textScale),
                                            Text(item.biological,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15 * textScale,
                                                    color: cm.explicitText)),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 14 * textScale),

                                      // status visual
                                      statusBlock(double.infinity, 140 * textScale),

                                      SizedBox(height: 14 * textScale),

                                      Text('Resumo rápido',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15 * textScale,
                                              color: cm.explicitText)),
                                      SizedBox(height: 8 * textScale),
                                      Text(_resultSummarySentence(displayStatus),
                                          style: TextStyle(color: cm.explicitText.withOpacity(0.9), fontSize: 14 * textScale)),

                                      SizedBox(height: 12 * textScale),

                                      // Botões: em mobile, quebram em coluna quando não couberem na mesma linha
                                      Wrap(
                                        spacing: 12 * textScale,
                                        runSpacing: 8 * textScale,
                                        alignment: WrapAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: (maxW >= 360) ? (maxW - 32) : double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          'Reabrindo análise para ${item.chemical} • ${item.biological} (simulado)')),
                                                );
                                              },
                                              icon: Icon(Icons.replay_rounded, color: cm.text),
                                              label: Text('Re-analisar', style: TextStyle(color: cm.text)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: cm.primary,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12 * textScale)),
                                                padding: EdgeInsets.symmetric(vertical: 14 * textScale),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 8 * textScale),

                                      OutlinedButton.icon(
                                        onPressed: () => setState(() => _showDetail = !_showDetail),
                                        icon: Icon(Icons.info_outline_rounded, color: cm.primary),
                                        label: Text(_showDetail ? 'Ocultar detalhe' : 'Detalhar resultado',
                                            style: TextStyle(color: cm.primary)),
                                        style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: cm.primary.withOpacity(0.14))),
                                      ),

                                      SizedBox(height: 12 * textScale),
                                      AnimatedCrossFade(
                                        firstChild: const SizedBox.shrink(),
                                        secondChild: Container(
                                          padding: EdgeInsets.all(12 * textScale),
                                          decoration: BoxDecoration(
                                            color: cm.background,
                                            borderRadius: BorderRadius.circular(12 * textScale),
                                            border: Border.all(color: statusColor.withOpacity(0.10)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Resumo do resultado',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      color: cm.explicitText,
                                                      fontSize: 14 * textScale)),
                                              SizedBox(height: 8 * textScale),
                                              Text(description ?? 'Nenhuma descrição adicional disponível.',
                                                  style: TextStyle(color: cm.explicitText, fontSize: 14 * textScale)),
                                            ],
                                          ),
                                        ),
                                        crossFadeState:
                                            _showDetail ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                        duration: const Duration(milliseconds: 220),
                                      ),

                                      SizedBox(height: 56), // espaço para o banner flutuante
                                    ],
                                  );
                                }

                                // Desktop / tablet layout — duas colunas, bloco de status à direita
                                final rectW = (maxW * 0.28).clamp(140.0 * textScale, 320.0 * textScale);
                                final rectH = (180.0 * textScale).clamp(140.0 * textScale, 260.0 * textScale);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // left column
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today_rounded,
                                                      color: cm.explicitText.withOpacity(0.7)),
                                                  SizedBox(width: 10 * textScale),
                                                  Text(formatDate(item.date),
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 14 * textScale,
                                                          color: cm.explicitText)),
                                                ],
                                              ),
                                              SizedBox(height: 12 * textScale),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 14 * textScale, vertical: 14 * textScale),
                                                decoration: BoxDecoration(
                                                  color: cm.background,
                                                  borderRadius: BorderRadius.circular(12 * textScale),
                                                  border: Border.all(color: statusColor.withOpacity(0.10)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Row(children: [
                                                      Icon(Icons.science_rounded, color: cm.primary),
                                                      SizedBox(width: 8 * textScale),
                                                      Text('Químico',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.w800,
                                                              color: cm.primary)),
                                                    ]),
                                                    SizedBox(height: 10 * textScale),
                                                    Text(item.chemical,
                                                        style: TextStyle(
                                                            fontSize: 17 * textScale,
                                                            fontWeight: FontWeight.w700,
                                                            color: cm.explicitText)),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: 12 * textScale),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 14 * textScale, vertical: 14 * textScale),
                                                decoration: BoxDecoration(
                                                  color: cm.background,
                                                  borderRadius: BorderRadius.circular(12 * textScale),
                                                  border: Border.all(color: statusColor.withOpacity(0.10)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Row(children: [
                                                      Icon(Icons.bug_report_rounded, color: cm.primary),
                                                      SizedBox(width: 8 * textScale),
                                                      Text('Biológico',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.w800,
                                                              color: cm.primary)),
                                                    ]),
                                                    SizedBox(height: 10 * textScale),
                                                    Text(item.biological,
                                                        style: TextStyle(
                                                            fontSize: 17 * textScale,
                                                            fontWeight: FontWeight.w700,
                                                            color: cm.explicitText)),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: 18 * textScale),
                                              Text('Resumo rápido',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 16 * textScale,
                                                      color: cm.explicitText)),
                                              SizedBox(height: 8 * textScale),
                                              Text(_resultSummarySentence(displayStatus),
                                                  style: TextStyle(color: cm.explicitText.withOpacity(0.9), fontSize: 14 * textScale)),
                                              SizedBox(height: 14 * textScale),
                                              Wrap(
                                                spacing: 12 * textScale,
                                                runSpacing: 8 * textScale,
                                                children: [
                                                 
                                                  OutlinedButton.icon(
                                                    onPressed: () => setState(() => _showDetail = !_showDetail),
                                                    icon: Icon(Icons.info_outline_rounded, color: cm.primary),
                                                    label: Text(_showDetail ? 'Ocultar detalhe' : 'Detalhar resultado',
                                                        style: TextStyle(color: cm.primary)),
                                                    style: OutlinedButton.styleFrom(
                                                        side: BorderSide(color: cm.primary.withOpacity(0.14))),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        SizedBox(width: 20 * textScale),

                                        // right column: bloco de status
                                        SizedBox(
                                          width: rectW,
                                          child: statusBlock(rectW, rectH),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 18 * textScale),

                                    AnimatedCrossFade(
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Container(
                                        padding: EdgeInsets.all(16 * textScale),
                                        decoration: BoxDecoration(
                                          color: cm.background,
                                          borderRadius: BorderRadius.circular(12 * textScale),
                                          border: Border.all(color: statusColor.withOpacity(0.10)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Resumo do resultado',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16 * textScale,
                                                    color: cm.explicitText)),
                                            SizedBox(height: 8 * textScale),
                                            Text(description ?? 'Nenhuma descrição disponível para este resultado.',
                                                style: TextStyle(color: cm.explicitText, fontSize: 14 * textScale)),
                                          ],
                                        ),
                                      ),
                                      crossFadeState:
                                          _showDetail ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 220),
                                    ),

                                    SizedBox(height: 56), // espaço para o banner flutuante
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Scroll hint banner posicionado na parte inferior, exibido apenas se não foi descartado
            if (!_bannerDismissed)
              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: ScrollHintBanner(
                    onDismissed: () {
                      if (mounted) {
                        setState(() {
                          _bannerDismissed = true;
                        });
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
