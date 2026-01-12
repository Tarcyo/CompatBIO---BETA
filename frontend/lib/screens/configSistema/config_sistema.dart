// FILE: lib/screens/config_screen.dart

import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/configSistema/confgForm.dart';
import 'package:planos/screens/configSistema/configClass.dart';
import 'package:planos/screens/configSistema/config_service.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';

/// Reusable header with gradient, icon and trailing area.
/// Adaptative layout so it doesn't overflow on small screens.
/// This header is designed to be part of the Card (not floating).
class ChemicalCardHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final Color primary;
  final double borderRadius;
  final Widget? trailing;
  final double verticalPadding;
  final double horizontalPadding;
  final double scale;

  const ChemicalCardHeader({
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

    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 420;
      final iconSize = (14.0 * scale + 8.0).clamp(18.0, 40.0);
      final titleFont = isCompact
          ? (16.0 * scale).clamp(12.0, 22.0)
          : (18.0 * scale + 4.0).clamp(16.0, 32.0);

      return Container(
        decoration: BoxDecoration(
          // only round the top of the header so it visually blends with the card
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(borderRadius)),
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
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: verticalPadding),
        child: Row(
          // Use start so Expanded will push trailing to the far right reliably
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all((8.0 * scale).clamp(6.0, 16.0)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(leadingIcon, color: Colors.white, size: iconSize),
            ),
            SizedBox(width: 10 * scale),
            // Title placed inside Expanded + FittedBox to prevent overflow
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: titleFont,
                  ),
                ),
              ),
            ),
            // Small gap
            SizedBox(width: 8 * scale),
            // Trailing area: if compact we allow trailing to be a small icon-only widget
            if (trailing != null)
              Builder(builder: (ctx) {
                // If there's very little space, wrap trailing in a ConstrainedBox
                if (isCompact) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 120 * scale),
                    child: trailing!,
                  );
                }
                return trailing!;
              }),
          ],
        ),
      );
    });
  }
}

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({Key? key}) : super(key: key);

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final ConfigService _service = ConfigService();
  ConfigSistema? latest;
  bool loading = false;
  bool _editing = false;

  // Controller is now attached to the outer scroll view (page-level)
  final ScrollController _pageController = ScrollController();
  bool _showScrollHint = true;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    fetchLatest();

    _pageController.addListener(() {
      if (!_pageController.hasClients) return;
      final pos = _pageController.position;
      if (pos.hasPixels && pos.pixels > 24 && _showScrollHint) {
        setState(() => _showScrollHint = false);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (userProv.user == null) return null;
    return userProv.user!.token;
  }

  Future<void> fetchLatest() async {
    if (mounted) setState(() => loading = true);
    try {
      final token = await _getTokenFromProvider();
      final cfg = await _service.fetchLatest(token);
      if (!mounted) return;
      setState(() {
        latest = cfg;
        _editing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar configuração: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Dismiss handler for the banner
  void _dismissBanner() {
    if (!mounted) return;
    setState(() {
      _bannerDismissed = true;
      _showScrollHint = false;
    });
  }

  Widget _buildScrollBanner(BuildContext context) {
    final visible = _showScrollHint && !_bannerDismissed;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 18,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Semantics(
            label: 'Dica: deslize para ver mais',
            hint: 'Toque para dispensar',
            child: Center(
              child: ScrollHintBanner(onDismissed: _dismissBanner),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.of(context).size.width;
    final scale = vw > 1400 ? 1.25 : (vw > 1000 ? 1.08 : 1.0);
    final isMobile = vw < 600;

    final bg = ColorManager.instance.background;
    final cardSoft = ColorManager.instance.card.withOpacity(0.06);
    final cardBorder = ColorManager.instance.card.withOpacity(0.18);
    final primaryText = ColorManager.instance.explicitText;
    final mutedText = ColorManager.instance.explicitText.withOpacity(0.6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: primaryText,
      ),
      body: SafeArea(
        // The scroll view now wraps the whole screen content (not only inside the card).
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 18 * scale,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: cardSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24 * scale),
                          side: BorderSide(color: cardBorder, width: 1.4),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        child: ClipRRect(
                          // clip so header's top radius matches card's radius exactly
                          borderRadius: BorderRadius.circular(24 * scale),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header integrated as part of the card (not floating)
                              ChemicalCardHeader(
                                title: 'Painel de Configurações',
                                leadingIcon: Icons.settings_rounded,
                                primary: ColorManager.instance.primary,
                                borderRadius: 24 * scale,
                                verticalPadding: 14 * scale,
                                horizontalPadding: 16 * scale,
                                scale: scale,
                                trailing: Builder(builder: (ctx) {
                                  // single icon on the right of the header to toggle edit mode
                                  return Semantics(
                                    button: true,
                                    label: _editing ? 'Cancelar edição' : 'Editar configuração',
                                    child: IconButton(
                                      tooltip: _editing ? 'Cancelar' : 'Editar',
                                      padding: EdgeInsets.all((6.0 * scale).clamp(6.0, 12.0)),
                                      constraints: BoxConstraints(
                                        minWidth: 40 * scale,
                                        minHeight: 40 * scale,
                                        maxWidth: 48 * scale,
                                        maxHeight: 48 * scale,
                                      ),
                                      icon: Icon(
                                        _editing ? Icons.close_rounded : Icons.edit_rounded,
                                        color: Colors.white,
                                        size: (18.0 * scale).clamp(16.0, 28.0),
                                      ),
                                      onPressed: () {
                                        setState(() => _editing = !_editing);
                                      },
                                    ),
                                  );
                                }),
                              ),
                              // Body inside card (non-scrollable). Outer SingleChildScrollView handles scrolling.
                              Padding(
                                padding: EdgeInsets.all(20 * scale),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // keep spacing consistent
                                    SizedBox(height: 8 * scale),
                                    SizedBox(height: 12 * scale),
                                    _largeLatestCard(scale),
                                    SizedBox(height: 12 * scale),
                                    if (!isMobile)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.touch_app_rounded,
                                            size: 16 * scale,
                                            color: mutedText,
                                          ),
                                          SizedBox(width: 6 * scale),
                                          Text(
                                            'Pressione "Editar" para alterar a configuração',
                                            style: TextStyle(
                                              color: mutedText,
                                              fontSize: 14 * scale,
                                            ),
                                          ),
                                        ],
                                      ),
                                    SizedBox(height: 8 * scale),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // You can add more content below the card if needed; it will scroll with the page.
                      SizedBox(height: 28 * scale),
                    ],
                  ),
                ),
              ),
            ),

            // Scroll hint banner (overlaid). Only appears when mobile and not dismissed.
            if (isMobile && _showScrollHint && !_bannerDismissed)
              _buildScrollBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _largeLatestCard(double scale) {
    final bg = ColorManager.instance.background;
    final cardBorder = ColorManager.instance.card.withOpacity(0.08);
    final primary = ColorManager.instance.primary;
    final primaryText = ColorManager.instance.explicitText;
    final mutedText = ColorManager.instance.explicitText.withOpacity(0.6);

   // final vw = MediaQuery.of(context).size.width;
    //final isMobile = vw < 600;

    // Reduce top spacing between the container border and the first form item:
    return Container(
      // reduced top padding (10 * scale) while keeping other paddings the same
      padding: EdgeInsets.fromLTRB(18 * scale, 10 * scale, 18 * scale, 18 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Removed the previous SizedBox here so first item sits closer to the top border.

                if (latest == null) ...[
                  _sectionTitle(
                    'Nenhuma configuração encontrada',
                    scale: scale,
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    'Crie a primeira configuração abaixo.',
                    style: TextStyle(color: mutedText),
                  ),
                  SizedBox(height: 12 * scale),
                  // create inline form
                  ConfigForm(
                    isEdit: false,
                    dataEstabelecimento: DateTime.now(),
                    onSuccess: fetchLatest,
                  ),
                ] else ...[
                  if (!_editing) ...[
                    // FIRST DIVIDER REMOVED (no divider before the first info block)
                    _infoBlock(
                      icon: Icons.calendar_today_rounded,
                      title: 'Data de estabelecimento',
                      value: _formatDate(latest!.dataEstabelecimento),
                      scale: scale,
                    ),
                    Divider(height: 24),
                    _infoBlock(
                      icon: Icons.monetization_on_rounded,
                      title: 'Preço do crédito',
                      value: latest!.precoDoCredito,
                      scale: scale,
                    ),
                    Divider(height: 24),
                    _infoBlock(
                      icon: Icons.request_page_rounded,
                      title: 'Preço da solicitação',
                      value: '${latest!.precoDaSolicitacaoEmCreditos} créditos',
                      scale: scale,
                    ),
                    Divider(height: 24),
                    _infoBlock(
                      icon: Icons.timer_rounded,
                      title: 'Validade dos pacotes (dias)',
                      value: latest!.validadeEmDias.toString(),
                      scale: scale,
                    ),
                    if (latest!.descricao != null &&
                        latest!.descricao!.trim().isNotEmpty) ...[
                      Divider(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note_rounded, color: primary),
                          SizedBox(width: 12 * scale),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Descrição',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                                SizedBox(height: 6 * scale),
                                Text(
                                  latest!.descricao!,
                                  style: TextStyle(color: primaryText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.update_rounded,
                          color: ColorManager.instance.card.withOpacity(0.7),
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: Text(
                            'Atualizado em',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ),
                        Text(
                          latest!.atualizadoEm.toLocal().toIso8601String(),
                          style: TextStyle(fontSize: 12, color: mutedText),
                        ),
                      ],
                    ),
                  ] else ...[
                    // edit inline form shown when header icon toggles edit mode
                    ConfigForm(
                      isEdit: true,
                      initial: latest,
                      dataEstabelecimento: latest!.dataEstabelecimento,
                      onSuccess: () async {
                        await fetchLatest();
                        if (!mounted) return;
                        setState(() => _editing = false);
                      },
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle, double scale = 1.0}) {
    final primaryText = ColorManager.instance.explicitText;
    final muted = ColorManager.instance.explicitText.withOpacity(0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16 * scale,
            fontWeight: FontWeight.w800,
            color: primaryText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12 * scale, color: muted),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime dt) => dt.toIso8601String().split('T')[0];

  Widget _infoBlock({
    required IconData icon,
    required String title,
    required String value,
    required double scale,
  }) {
    final primary = ColorManager.instance.primary;
    final bg = ColorManager.instance.card.withOpacity(0.06);
    final primaryText = ColorManager.instance.explicitText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36 * scale,
          height: 36 * scale,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primary, size: 18 * scale),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              SizedBox(height: 6 * scale),
              Text(value, style: TextStyle(color: primaryText)),
            ],
          ),
        ),
      ],
    );
  }
}
