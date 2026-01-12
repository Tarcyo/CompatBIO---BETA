// FILE: lib/screens/empresa_screen.dart
import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/empresa/empresaCard.dart';
import 'package:planos/screens/empresa/empresaClass.dart';
import 'package:planos/screens/empresa/empresaService.dart';
import 'package:planos/screens/empresa/inlineForm.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: verticalPadding),
        child: Row(
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
            SizedBox(width: 8 * scale),
            if (trailing != null)
              Builder(builder: (ctx) {
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

class EmpresaScreen extends StatefulWidget {
  const EmpresaScreen({Key? key}) : super(key: key);

  @override
  State<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  final EmpresaService _service = EmpresaService();
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  List<Empresa> empresas = [];
  bool loading = false;
  Empresa? editingEmpresa;

  // scroll hint state
  bool _showScrollHint = true;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    fetchEmpresas();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (userProv.user == null) return null;
    return userProv.user!.token;
  }

  Future<void> fetchEmpresas() async {
    if (mounted) setState(() => loading = true);
    try {
      final token = await _getTokenFromProvider();
      final list = await _service.fetchEmpresas(token);
      if (!mounted) return;
      setState(() {
        empresas = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro carregando empresas: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _startEdit(Empresa e) {
    setState(() => editingEmpresa = e);
  }

  // Dismiss handler for the scroll hint banner
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
    final cm = ColorManager.instance;
    final vw = MediaQuery.of(context).size.width;
    final scale = vw > 1400 ? 1.12 : (vw > 1000 ? 1.04 : 1.0);
    final isMobile = vw < 700;
    final isDesktop = vw > 1200;

    // Outer scroll view wraps whole screen content (not only inside the card)
    return Scaffold(
      backgroundColor: cm.background,
      appBar: AppBar(
        backgroundColor: cm.background,
        foregroundColor: cm.explicitText,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
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
                        color: cm.card.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18 * scale),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18 * scale),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // integrated header (part of the card)
                              ChemicalCardHeader(
                                title: 'Gerenciar empresas',
                                leadingIcon: Icons.business_rounded,
                                primary: cm.primary,
                                borderRadius: 18 * scale,
                                verticalPadding: 14 * scale,
                                horizontalPadding: 16 * scale,
                                scale: scale,
                              ),

                              // card body (non-scrollable) — page-level scroll handles scrolling
                              Padding(
                                padding: EdgeInsets.all(18 * scale),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Inline form
                                    EmpresaInlineForm(
                                      key: const ValueKey('empresa_form'),
                                      baseUrl: baseUrl,
                                      existing: editingEmpresa,
                                      onSaved: (ok) {
                                        if (ok == true) fetchEmpresas();
                                        setState(() => editingEmpresa = null);
                                      },
                                      onCancel: () =>
                                          setState(() => editingEmpresa = null),
                                    ),

                                    const SizedBox(height: 16),

                                    if (loading)
                                      Center(
                                        child: CircularProgressIndicator(
                                          color: cm.primary,
                                        ),
                                      )
                                    else if (empresas.isEmpty)
                                      _emptyState(scale)
                                    else
                                      _gridArea(isMobile, isDesktop, scale),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // additional spacing so user can scroll past card
                      SizedBox(height: 28 * scale),
                    ],
                  ),
                ),
              ),
            ),

            // banner overlaid only on mobile, same behavior as examples
            if (isMobile && _showScrollHint && !_bannerDismissed)
              _buildScrollBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(double scale) {
    final cm = ColorManager.instance;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24 * scale),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: cm.explicitText.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma empresa',
              style: TextStyle(
                fontSize: 18 * scale,
                fontWeight: FontWeight.w800,
                color: cm.explicitText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Crie a primeira empresa usando o formulário acima.',
              style: TextStyle(color: cm.explicitText.withOpacity(0.65)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridArea(bool isMobile, bool isDesktop, double scale) {
    final cross = isMobile ? 1 : (isDesktop ? 3 : 2);
    final aspect = isMobile ? 3.0 : (isDesktop ? 2.4 : 2.6);

    return GridView.builder(
      padding: EdgeInsets.symmetric(vertical: 8 * scale),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        childAspectRatio: aspect,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: empresas.length,
      itemBuilder: (ctx, i) {
        final e = empresas[i];
        return EmpresaCard(
          empresa: e,
          baseUrl: baseUrl,
          scale: scale,
          onEdit: () => _startEdit(e),
        );
      },
    );
  }
}
