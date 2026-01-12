import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/solicitarAnalise/bio_picker.dart';
import 'package:planos/screens/solicitarAnalise/card_item.dart';
import 'package:planos/screens/solicitarAnalise/card_screen.dart';
import 'package:planos/screens/solicitarAnalise/chemicalPicker.dart';
import 'package:planos/screens/solicitarAnalise/simpleRow.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


/// Reusable header with gradient, icon and trailing area.
/// Adaptative layout so it doesn't overflow on small screens.
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
            // Expanded ensures the title occupies available space and pushes trailing to the right edge.
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


// IMPORT DO SCROLL HINT BANNER (adicionado conforme pedido)

class LabMinimalScreen extends StatefulWidget {
  const LabMinimalScreen({super.key});

  @override
  State<LabMinimalScreen> createState() => _LabMinimalScreenState();
}

class SaldoCreditos {
  int _creditos; // atributo privado

  // Construtor
  SaldoCreditos(this._creditos);

  // Getter
  int get creditos => _creditos;

  // Setter
  set creditos(int valor) {
    _creditos = valor;
  }
}

class _LabMinimalScreenState extends State<LabMinimalScreen> {
  Map<String, List<String>> chemicalByType = {};
  Map<String, List<String>> bioByType = {};

  String? selectedChemical;
  String? selectedBiological;

  final List<CartItem> cart = [];

  SaldoCreditos? creditos;

  bool isLoading = true;
  String? errorMessage;

  // flag local para controlar se o banner já foi descartado
  bool _bannerDismissed = false;

  bool get canAdd => (selectedChemical != null && selectedBiological != null);

  @override
  void initState() {
    super.initState();
    // espera o primeiro frame para ter acesso seguro ao Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
      _fetchCredits(); // busca o saldo do usuário assim que a tela é montada
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Usuário não autenticado. Faça login para carregar os produtos.';
      });
      return;
    }

    try {
      final uri = Uri.parse('${dotenv.env['BASE_URL']}/produtos');

      final resp = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer ${user.token}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() {
          errorMessage =
              'Falha ao carregar produtos (status: ${resp.statusCode})';
          isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> body = json.decode(resp.body);

      // O servidor retorna: { produtos_biologicos: { tipo: [nomes]}, produtos_quimicos: { tipo: [nomes] } }
      final Map<String, dynamic> biologicos = Map<String, dynamic>.from(
        body['produtos_biologicos'] ?? {},
      );
      final Map<String, dynamic> quimicos = Map<String, dynamic>.from(
        body['produtos_quimicos'] ?? {},
      );

      setState(() {
        bioByType = biologicos.map((k, v) => MapEntry(k, List<String>.from(v)));
        chemicalByType = quimicos.map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        );
        isLoading = false;
        errorMessage = null;
      });
    } catch (e, st) {
      debugPrint('Erro ao carregar produtos: $e\n$st');
      setState(() {
        errorMessage = 'Erro ao carregar produtos: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCredits() async {
    // Busca o saldo do usuário autenticado usando a rota /usuarios/saldo
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) {
      setState(() {
        errorMessage =
            'Usuário não autenticado. Faça login para ver seus créditos.';
      });
      return;
    }

    try {
      final uri = Uri.parse('${dotenv.env['BASE_URL']}/usuarios/saldo');
      final resp = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer ${user.token}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() {
          errorMessage =
              'Falha ao carregar créditos (status: ${resp.statusCode})';
        });
        return;
      }

      final Map<String, dynamic> body = json.decode(resp.body);

      // Suporta respostas diferentes: { saldo_em_creditos: 123, user: {...} } ou { user: { saldo_em_creditos: 123 } }
      int? fetched;
      if (body.containsKey('saldo_em_creditos')) {
        final val = body['saldo_em_creditos'];
        fetched = (val is int) ? val : int.tryParse(val.toString());
      } else if (body['user'] != null &&
          body['user']['saldo_em_creditos'] != null) {
        final val = body['user']['saldo_em_creditos'];
        fetched = (val is int) ? val : int.tryParse(val.toString());
      } else if (body['user'] != null &&
          body['user'] is Map &&
          body['user']['saldo_em_creditos'] == null) {
        // às vezes a API pode retornar { valid: true, user: { ... } } — tentamos várias chaves
        final inner = Map<String, dynamic>.from(body['user']);
        if (inner.containsKey('saldo_em_creditos')) {
          final val = inner['saldo_em_creditos'];
          fetched = (val is int) ? val : int.tryParse(val.toString());
        }
      }

      if (fetched != null) {
        setState(() {
          creditos = SaldoCreditos(fetched!);

          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage =
              'Resposta inesperada do servidor (saldo não encontrado)';
        });
      }
    } catch (e, st) {
      debugPrint('Erro ao buscar saldo: $e\n$st');
      setState(() {
        errorMessage = 'Erro ao buscar créditos: ${e.toString()}';
      });
    }
  }

  void _pickChemical() async {
    if (chemicalByType.isEmpty) return _showSnack('Nenhum químico disponível no servidor.');
    final chosen = await showChemicalPicker(context, chemicalByType);
    if (chosen != null) setState(() => selectedChemical = chosen);
  }

  void _pickBiological() async {
    if (bioByType.isEmpty) return _showSnack('Nenhum biológico disponível no servidor.');
    final chosen = await showBiologicalPicker(context, bioByType);
    if (chosen != null) setState(() => selectedBiological = chosen);
  }

  void _addToCart() {
    if (!canAdd) return _showSnack('Selecione químico e biológico antes de adicionar.');
    final item = CartItem(
      chemical: selectedChemical,
      biological: selectedBiological,
    );
    setState(() {
      cart.add(item);
      selectedChemical = null;
      selectedBiological = null;
    });
    _showSnack('Adicionado (itens no carrinho: ${cart.length})');
  }

 

  void _showSnack(String text, {int duration = 2}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: Duration(seconds: duration),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final vw = media.size.width;
    final vh = media.size.height;

    final horizontalMargin = vw >= 1400 ? 40.0 : (vw >= 1000 ? 28.0 : 12.0);
    final verticalMargin = vh >= 900 ? 28.0 : 16.0;

    final double desktopScale = vw >= 1400 ? 1.18 : (vw >= 1000 ? 1.08 : 1.0);

    // increase global UI scale so text and icons become maiores
    final double uiScale = (desktopScale * 1.15).clamp(0.9, 1.35);

    final cardWidth = (vw - (horizontalMargin * 2)).clamp(340.0, 1400.0);
    final minCardHeight = (vh - (verticalMargin * 2)).clamp(420.0, vh);

    return Scaffold(
      backgroundColor: ColorManager.instance.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Conteúdo original agora escutando notificações de scroll para
            // permitir dismiss do banner quando usuário rolar
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Se o usuário iniciar rolagem, descartamos o banner localmente
                if (!_bannerDismissed &&
                    (notification is ScrollStartNotification ||
                        (notification.metrics.pixels > 0))) {
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
                      minWidth: cardWidth,
                      maxWidth: cardWidth,
                      minHeight: minCardHeight,
                    ),
                    child: Center(
                      child: Card(
                        color: ColorManager.instance.card.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20 * desktopScale),
                          side: BorderSide(
                            color: ColorManager.instance.card.withOpacity(0.6),
                            width: 1.6,
                          ),
                        ),
                        elevation: 0, // remove a sombra
                        shadowColor: Colors.transparent, // garante que não haja cor de sombra
                        surfaceTintColor: Colors.transparent, // evita tint causado por elevation em algumas versões
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // HEADER (gradiente idêntico ao biological picker)
                            // Agora integrado como o topo do Card — ocupa toda a largura do card.
                            ChemicalCardHeader(
                              title: 'Solicitar análises',
                              leadingIcon: Icons.biotech_rounded,
                              primary: ColorManager.instance.primary,
                              borderRadius: 20 * desktopScale,
                              verticalPadding: 14 * uiScale,
                              horizontalPadding: 16 * uiScale,
                              scale: uiScale,
                              trailing: _cartSquareWidget(uiScale),
                            ),

                            // Conteúdo interno do card (mantido igual nas funcionalidades)
                            Padding(
                              padding: EdgeInsets.all(18 * uiScale),
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final isWide = box.maxWidth >= 900;
                                  final isSmall = box.maxWidth < 600;
                                  final subtitleSize = isSmall
                                      ? (18.0 * uiScale).clamp(12.0, 22.0)
                                      : (22.0 * uiScale).clamp(16.0, 26.0);
                                  final fieldVerticalPadding = isSmall
                                      ? (12.0 * uiScale).clamp(8.0, 18.0)
                                      : (18.0 * uiScale).clamp(12.0, 26.0);

                                  // Build the actions column (used in wide and narrow layouts)
                                  Widget buildActionsColumn() {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        SimpleRow(
                                          label: 'Químico',
                                          icon: Icons.science_rounded,
                                          value: selectedChemical ?? 'Nenhum',
                                          onTap: _pickChemical,
                                          scale: uiScale,
                                          verticalPadding: fieldVerticalPadding,
                                        ),
                                        SizedBox(height: 12 * uiScale),
                                        SimpleRow(
                                          label: 'Biológico',
                                          icon: Icons.bug_report_rounded,
                                          value: selectedBiological ?? 'Nenhum',
                                          onTap: _pickBiological,
                                          scale: uiScale,
                                          verticalPadding: fieldVerticalPadding,
                                        ),
                                        SizedBox(height: 14 * uiScale),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                           
                                            Flexible(
                                              child: ElevatedButton.icon(
                                                onPressed: canAdd ? _addToCart : null,
                                                icon: Icon(
                                                  Icons.add_circle_outline_rounded,
                                                  size: (20 * uiScale).clamp(12.0, 28.0),
                                                ),
                                                label: Text(
                                                  'Adicionar ao carrinho',
                                                  style: TextStyle(
                                                    fontSize: (15 * uiScale).clamp(12.0, 18.0),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: (14 * uiScale).clamp(10.0, 22.0),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(18),
                                                  ),
                                                  backgroundColor:
                                                      ColorManager.instance.primary,
                                                  foregroundColor:
                                                      ColorManager.instance.text,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Subtitle row (mantido)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.analytics_rounded,
                                            color: ColorManager.instance.primary,
                                            size: (20 * uiScale).clamp(14.0, 28.0),
                                          ),
                                          SizedBox(width: 10 * uiScale),
                                          Text(
                                            'Análise atual',
                                            style: TextStyle(
                                              fontSize: subtitleSize,
                                              fontWeight: FontWeight.w900,
                                              color: ColorManager.instance.explicitText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 14 * uiScale),

                                      if (isLoading)
                                        Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 40.0),
                                            child: CircularProgressIndicator(
                                              color: ColorManager.instance.primary,
                                            ),
                                          ),
                                        )
                                      else if (errorMessage != null)
                                        Column(
                                          children: [
                                            Text(
                                              errorMessage!,
                                              style:
                                                  TextStyle(color: ColorManager.instance.emergency),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                _loadProducts();
                                                _fetchCredits();
                                              },
                                              icon: Icon(Icons.refresh_rounded,
                                                  color: ColorManager.instance.text),
                                              label: Text('Tentar novamente'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: ColorManager.instance.primary,
                                                foregroundColor: ColorManager.instance.text,
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (isWide)
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: buildActionsColumn(),
                                            ),
                                            SizedBox(width: 20 * uiScale),
                                            Expanded(
                                              flex: 1,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(12 * uiScale),
                                                    decoration: BoxDecoration(
                                                      color: ColorManager.instance.background,
                                                      borderRadius: BorderRadius.circular(14),
                                                      border: Border.all(
                                                        color:
                                                            ColorManager.instance.card.withOpacity(0.2),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.account_balance_wallet_rounded,
                                                          color: ColorManager.instance.primary,
                                                          size: (20 * uiScale).clamp(16.0, 26.0),
                                                        ),
                                                        SizedBox(width: 12 * uiScale),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      'Meus créditos',
                                                                      style: TextStyle(
                                                                        fontSize: (14 * uiScale)
                                                                            .clamp(12.0, 16.0),
                                                                        color: ColorManager.instance.explicitText
                                                                            .withOpacity(0.75),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  // botão discreto para atualizar créditos
                                                                  IconButton(
                                                                    padding: EdgeInsets.zero,
                                                                    constraints: BoxConstraints(),
                                                                    icon: Icon(
                                                                      Icons.refresh_rounded,
                                                                      size: (18 * uiScale).clamp(12.0, 22.0),
                                                                      color: ColorManager.instance.primary,
                                                                    ),
                                                                    onPressed: _fetchCredits,
                                                                    tooltip: 'Recarregar créditos',
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(height: 8 * uiScale),
                                                              Text(
                                                                (creditos?.creditos ?? 0).toString() +
                                                                    ' créditos',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w900,
                                                                  fontSize: (18 * uiScale).clamp(14.0, 24.0),
                                                                  color: ColorManager.instance.explicitText,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(height: 14 * uiScale),
                                                 
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        // narrow layout: stack vertically and ensure buttons don't overflow
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            buildActionsColumn(),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: EdgeInsets.all(12 * uiScale),
                                              decoration: BoxDecoration(
                                                color: ColorManager.instance.background,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: ColorManager.instance.card.withOpacity(0.12),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.account_balance_wallet_rounded,
                                                    color: ColorManager.instance.primary,
                                                    size: (18 * uiScale).clamp(14.0, 22.0),
                                                  ),
                                                  SizedBox(width: 10 * uiScale),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Meus créditos',
                                                          style: TextStyle(
                                                            fontSize: (13 * uiScale).clamp(11.0, 15.0),
                                                            color: ColorManager.instance.explicitText.withOpacity(0.75),
                                                          ),
                                                        ),
                                                        SizedBox(height: 6 * uiScale),
                                                        Text(
                                                          (creditos?.creditos ?? 0).toString() + ' créditos',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: (16 * uiScale).clamp(14.0, 20.0),
                                                            color: ColorManager.instance.explicitText,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: BoxConstraints(),
                                                    icon: Icon(Icons.refresh_rounded,
                                                        size: (18 * uiScale).clamp(12.0, 22.0),
                                                        color: ColorManager.instance.primary),
                                                    onPressed: _fetchCredits,
                                                    tooltip: 'Recarregar créditos',
                                                  ),
                                                ],
                                              ),
                                            ),
                                     
                                          ],
                                        ),
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
            ),

            // Scroll hint banner posicionado na parte inferior, exibido apenas se não foi descartado
            if (!_bannerDismissed)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: ScrollHintBanner(
                    // quando o banner terminar a animação de fade ele chamará onDismissed
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

  /// Cart square widget placed in the header trailing area.
  /// Adaptative: on narrow screens it reduces the label and may show compact layout.
  Widget _cartSquareWidget(double uiScale) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;

    // decide compact mode for small widths
    final compact = screenWidth < 420;

    // base sizes that adapt with uiScale
    final double minSize = (compact ? 44.0 : 60.0) * uiScale;
    final double maxSize = (compact ? 120.0 : 160.0) * uiScale;
    final double iconSize = (compact ? 18.0 : 22.0) * uiScale;
    final double badgeSize = (compact ? 16.0 : 18.0) * uiScale;
    final double verticalPadding = (8.0 * uiScale);
    final int count = cart.length;
    final String countLabel = count > 999 ? '999+' : count.toString();

    // gradient that harmonizes with header primary (slightly warmer)
    final Color primary = ColorManager.instance.primary;
    final Color mid = HSLColor.fromColor(primary)
        .withLightness((HSLColor.fromColor(primary).lightness - 0.08).clamp(0.0, 1.0))
        .toColor();
    final Color end = HSLColor.fromColor(primary)
        .withLightness((HSLColor.fromColor(primary).lightness - 0.20).clamp(0.0, 1.0))
        .toColor();

    // desired larger base font for label (will be scaled down by FittedBox if needed)
    final double desiredLabelFont = (compact ? 12.0 : 16.0) * uiScale;

    return Padding(
      padding: EdgeInsets.only(left: 8.0 * uiScale),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0 * uiScale),
          onTap: () async {
            // safety: provide a default SaldoCreditos if creditos is null
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CartScreen(cart: cart, credits: creditos ?? SaldoCreditos(0)),
              ),
            );
            // after returning maybe items changed; refresh small state
            setState(() {});
          },
          child: Container(
            constraints: BoxConstraints(
              minWidth: minSize,
              minHeight: minSize,
              maxWidth: maxSize,
            ),
            padding: EdgeInsets.symmetric(horizontal: (compact ? 8.0 : 12.0) * uiScale, vertical: verticalPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, mid, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.0 * uiScale),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon + optional count badge (stack)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.shopping_cart_rounded,
                      color: Colors.white,
                      size: iconSize,
                    ),
                    if (count > 0)
                      Positioned(
                        right: -6 * uiScale,
                        top: -6 * uiScale,
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: badgeSize,
                            minHeight: badgeSize,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 4 * uiScale),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(badgeSize),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                countLabel,
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: (11 * uiScale).clamp(8.0, 12.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: compact ? 8.0 * uiScale : 12.0 * uiScale),
                // Label area — uses Flexible + FittedBox to avoid overflow and scale down when necessary
                if (!compact)
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'MEU CARRINHO',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: desiredLabelFont,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // in compact mode show short text or nothing
                  SizedBox.shrink(),
                // optional chevron if there is space
                if (!compact) SizedBox(width: 6.0 * uiScale),
                if (!compact)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.92),
                    size: (18 * uiScale).clamp(12.0, 22.0),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// helper: evita conflito entre extensões com o mesmo nome
