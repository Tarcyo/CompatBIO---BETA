// FILE: lib/screens/planos_screen.dart

import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/listaDePlanos/planoCard.dart';
import 'package:planos/screens/listaDePlanos/plano_class.dart';
import 'package:planos/screens/listaDePlanos/plano_inline_form.dart';
import 'package:planos/screens/listaDePlanos/plano_service.dart';
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
          // round only the top so it visually blends with the card
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

class PlanosScreen extends StatefulWidget {
  const PlanosScreen({Key? key}) : super(key: key);

  @override
  State<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends State<PlanosScreen> {
  final PlanoService _service = PlanoService();
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  List<Plano> planos = [];
  bool loading = false;
  Plano? editingPlano;

  // Scroll hint state
  bool _showScrollHint = true;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    fetchPlanos();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (userProv.user == null) return null;
    return userProv.user!.token;
  }

  Future<void> fetchPlanos() async {
    if (mounted) setState(() => loading = true);
    try {
      final token = await _getTokenFromProvider();
      final list = await _service.fetchPlanos(token);
      if (!mounted) return;
      setState(() => planos = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao carregar planos: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _startEdit(Plano p) => setState(() => editingPlano = p);

  Future<void> _deletePlano(int id) async {
    final token = await _getTokenFromProvider();
    if (token == null) {
      _showSnack('Usuário não autenticado');
      return;
    }
    try {
      final resp = await _service.deletePlano(token, id);
      if (resp.statusCode == 200) {
        _showSnack('Plano removido');
        await fetchPlanos();
      } else {
        _showSnack('Erro ao remover plano: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      _showSnack('Erro: $e');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

  bool _isEnterprisePlano(Plano p) {
    // Heuristic preserved from other screens: detect Enterprise via name.
    // If you have an explicit field like p.tipo, replace this function accordingly.
    final nome = p.nome.toLowerCase();
    return nome.contains('enterprise') || nome.contains('juridic') || nome.contains('jurídica') || nome.contains('pj');
  }

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.of(context).size.width;
    final scale = vw > 1400 ? 1.12 : (vw > 1000 ? 1.04 : 1.0);
    final isMobile = vw < 700;
    final isDesktop = vw > 1200;

    // Reage a mudanças do ColorManager
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

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
                // Outer scroll view wrapping whole page (card will be a block inside)
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 18 * scale),
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
                              side: BorderSide(
                                  color: cm.card.withOpacity(0.6), width: 1.2),
                            ),
                            elevation: 0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18 * scale),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // integrated header (part of the card)
                                  ChemicalCardHeader(
                                    title: 'Gerenciar planos',
                                    leadingIcon: Icons.view_list_rounded,
                                    primary: cm.primary,
                                    borderRadius: 18 * scale,
                                    verticalPadding: 14 * scale,
                                    horizontalPadding: 16 * scale,
                                    scale: scale,
                                  ),

                                  // Card body (non-scrollable). Outer scroll handles scrolling.
                                  Padding(
                                    padding: EdgeInsets.all(18 * scale),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(height: 12 * scale),

                                        // Inline form
                                        PlanoInlineForm(
                                          key: ValueKey(editingPlano?.id ?? 'novo'),
                                          baseUrl: baseUrl,
                                          existing: editingPlano,
                                          onSaved: (ok) {
                                            if (ok == true) fetchPlanos();
                                            setState(() => editingPlano = null);
                                          },
                                          onCancel: () =>
                                              setState(() => editingPlano = null),
                                        ),

                                        SizedBox(height: 16 * scale),

                                        if (loading)
                                          Center(
                                              child: CircularProgressIndicator(
                                                  color: cm.primary))
                                        else if (planos.isEmpty)
                                          _emptyState(scale, cm)
                                        else
                                          _gridArea(isMobile, isDesktop, scale, cm),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // allow extra space so user can scroll past the card
                          SizedBox(height: 28 * scale),
                        ],
                      ),
                    ),
                  ),
                ),

                // banner overlaid on mobile only
                if (isMobile && _showScrollHint && !_bannerDismissed)
                  _buildScrollBanner(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(double scale, ColorManager cm) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24 * scale),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list_alt_outlined,
                size: 64, color: cm.explicitText.withOpacity(0.45)),
            SizedBox(height: 12 * scale),
            Text('Nenhum plano',
                style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w800,
                    color: cm.explicitText)),
            SizedBox(height: 6 * scale),
            Text('Crie o primeiro plano usando o formulário acima.',
                style: TextStyle(color: cm.explicitText.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _gridArea(bool isMobile, bool isDesktop, double scale, ColorManager cm) {
    final cross = isMobile ? 1 : (isDesktop ? 3 : 2);
    final aspect = isMobile ? 2.6 : (isDesktop ? 1.9 : 2.1);

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
      itemCount: planos.length,
      itemBuilder: (ctx, i) {
        final plano = planos[i];
        final isEnterprise = _isEnterprisePlano(plano);

        // Wrap the PlanoCard in a Stack so we can overlay the "Máx. colaboradores" badge
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The existing card widget (keeps all original interactions)
            PlanoCard(
              plano: plano,
              scale: scale,
              onEdit: () => _startEdit(plano),
              onDelete: () async {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return StatefulBuilder(
                      builder: (contextDialog, setStateDialog) {
                        // closure state
                        final state = {'deleting': false};

                        void _setDeleting(bool v) {
                          state['deleting'] = v;
                          setStateDialog(() {});
                        }

                        return AlertDialog(
                          title: const Text('Confirmar exclusão'),
                          content: Text('Deseja remover o plano "${plano.nome}"?'),
                          actions: [
                            TextButton(
                              onPressed: state['deleting'] == true
                                  ? null
                                  : () {
                                      Navigator.of(dialogContext).pop();
                                    },
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: state['deleting'] == true
                                  ? null
                                  : () async {
                                      _setDeleting(true);
                                      try {
                                        await _deletePlano(plano.id);
                                        if (mounted) Navigator.of(dialogContext).pop();
                                      } catch (_) {
                                        _setDeleting(false);
                                      }
                                    },
                              child: state['deleting'] == true
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Remover'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            // Badge positioned at top-right showing the max collaborators for Enterprise plans.
            if (isEnterprise)
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: cm.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cm.card.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, size: 14 * scale, color: cm.explicitText.withOpacity(0.9)),
                        const SizedBox(width: 6),
                        Text(
                          plano.maximoColaboradores == 0
                              ? 'Ilimitado'
                              : '${plano.maximoColaboradores}',
                          style: TextStyle(
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w700,
                            color: cm.explicitText.withOpacity(0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
