import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/solicitarAnalise/screen.dart';
import 'package:planos/screens/solicitarAnalise/card_item.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:planos/styles/syles.dart'; // <-- usa ColorManager
import 'package:flutter_dotenv/flutter_dotenv.dart';

// import do banner de dica de scroll
import 'package:planos/utils/scroll_hint_banner.dart';

/// Reusable header with gradient, icon and trailing area.
/// Accepts a `scale` so we can enlarge text/icons consistently.
class ChemicalCardHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final Color primary;
  final double borderRadius;
  final Widget? trailing;
  final Widget? leftWidget; // novo: widget opcional à esquerda do ícone
  final double verticalPadding;
  final double horizontalPadding;
  final double scale;

  const ChemicalCardHeader({
    Key? key,
    required this.title,
    required this.leadingIcon,
    required this.primary,
    this.trailing,
    this.leftWidget,
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
    final titleFont = 13.0 * scale + 4.0;

    return Container(
      // This decoration makes the header visually attached to the top of the Card.
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
          if (leftWidget != null) ...[
            leftWidget!,
            SizedBox(width: 8 * scale),
          ],
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

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;
  final SaldoCreditos credits;
  const CartScreen({super.key, required this.cart, required this.credits});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int? _selectedIndex;

  // --- ADIÇÃO: controlador de scroll e flag de banner ---
  late final ScrollController _scrollController;
  bool _bannerDismissed = false;

  void _removeItem(int index) {
    setState(() => widget.cart.removeAt(index));
    // adjust selection if needed
    if (_selectedIndex != null) {
      if (widget.cart.isEmpty)
        _selectedIndex = null;
      else if (_selectedIndex! >= widget.cart.length) _selectedIndex = widget.cart.length - 1;
    }
  }

  Future<void> _finalize() async {
    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nenhum item no carrinho.')));
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.token;

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não autenticado.')));
      return;
    }

    final url = Uri.parse('${dotenv.env['BASE_URL']}/solicitacoes');

    int totalCusto = 0;
    int sucesso = 0;
    int falhas = 0;

    for (final item in widget.cart) {
      final nomeQuimico = item.chemical ?? item.display;
      final nomeBiologico = item.biological ?? item.display;

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'nome_produto_quimico': nomeQuimico,
            'nome_produto_biologico': nomeBiologico,
          }),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final custo = data['custo_em_creditos'] ?? 0;
          totalCusto += (custo is int) ? custo : (custo as num).toInt();
          sucesso++;

          // Imprime custo individual
          print(
            '✅ Solicitação criada para "$nomeBiologico" x "$nomeQuimico" — Custo: $custo créditos',
          );
        } else {
          falhas++;
          // tenta decodificar mensagem do servidor, senão mostra body cru
          String detalhe;
          try {
            final decoded = jsonDecode(response.body);
            detalhe = decoded.toString();
          } catch (_) {
            detalhe = response.body;
          }
          print('❌ Falha ao criar solicitação para "$nomeBiologico" x "$nomeQuimico": ${response.statusCode} — $detalhe');
        }
      } catch (e) {
        falhas++;
        print('⚠️ Erro de rede para "$nomeBiologico" x "$nomeQuimico": $e');
      }
    }

    // Imprime o total após enviar todos os itens
    print('💰 Total gasto em créditos: $totalCusto');

    if (sucesso > 0) {
      setState(() => widget.cart.clear());
      widget.credits.creditos = widget.credits.creditos - totalCusto;
      Navigator.pop(context);
    }

    // Mostra resumo no app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Solicitações concluídas: $sucesso sucesso(s), $falhas falha(s). Total gasto: $totalCusto créditos.',
        ),
      ),
    );
  }

  void _toggleSelect(int index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  @override
  void initState() {
    super.initState();
    // inicializa o scroll controller e adiciona listener que fecha o banner ao rolar
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollController);

    // checar overflow após o primeiro frame para decidir mostrar/ocultar banner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateScrollable();
    });
  }

  // Listener que desabilita o banner quando o usuário rolar alguns pixels
  void _onScrollController() {
    if (!_bannerDismissed && _scrollController.hasClients) {
      if (_scrollController.position.pixels > 5) {
        setState(() => _bannerDismissed = true);
      }
    }
  }

  // Avalia se existe overflow (conteúdo escondido). Re-tenta se controller ainda não tiver clients.
  void _evaluateScrollable() {
    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), _evaluateScrollable);
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      if (mounted) setState(() => _bannerDismissed = true);
    } else {
      // há overflow: mantemos o banner disponível (a não ser que já tenha sido dismissado)
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollController);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final vw = media.size.width;
    final vh = media.size.height;

    final horizontalMargin = vw >= 1400 ? 40.0 : (vw >= 1000 ? 28.0 : 16.0);
    final verticalMargin = vh >= 900 ? 28.0 : 18.0;
    final double desktopScale = vw >= 1400 ? 1.18 : (vw >= 1000 ? 1.08 : 1.0);

    final cardWidth = (vw - (horizontalMargin * 2)).clamp(360.0, 1400.0);
    final minCardHeight = (vh - (verticalMargin * 2)).clamp(480.0, vh);

    ///final screenHeight = MediaQuery.of(context).size.height;

    // adjusted multipliers when an item is selected to reduce overflow
    final leftColumnWidthFactor = _selectedIndex != null ? 0.60 : 0.65;
    final rightColumnWidthFactor = _selectedIndex != null ? 0.28 : 0.30;
    //final listMaxHeightFactor = _selectedIndex != null ? 0.6 : 0.68;

    // smaller item sizes to avoid overflow
    final itemIconSize = 14 * desktopScale;
    final itemTitleSize = 13 * desktopScale;
    final itemTrailingSize = 18 * desktopScale;
    final itemVerticalMargin = 6 * desktopScale;

    // breakpoints
    //final isWideScreen = cardWidth >= 900;
    //final isSmall = cardWidth < 600;

    return Scaffold(
      backgroundColor: ColorManager.instance.background,
      body: SafeArea(
        child: Center(
          child: Stack(
            children: [
              // Conteúdo principal (SingleChildScrollView recebe o controller)
              SingleChildScrollView(
                controller: _scrollController, // controlador adicionado
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
                      elevation: 0, // sombra removida
                      shadowColor: Colors.transparent, // garante sem sombra
                      surfaceTintColor:
                          Colors.transparent, // evita tint de superfície
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final localWidth = box.maxWidth;
                          final isWide = localWidth >= 900;
                          final isTiny = localWidth < 600;
                          final titleSize = isTiny
                              ? 16.0
                              : (isWide ? 26.0 * desktopScale : 22.0 * desktopScale);

                          // HEADER: colocado as the very first child of the Card so it is NOT floating.
                          final header = ChemicalCardHeader(
                            title: isTiny ? 'Carrinho' : 'Carrinho de análises',
                            leadingIcon: Icons.shopping_cart_rounded,
                            primary: ColorManager.instance.primary,
                            borderRadius: 20 * desktopScale,
                            verticalPadding: 14 * desktopScale,
                            horizontalPadding: 16 * desktopScale,
                            scale: desktopScale,

                            // botão "Voltar" colocado dentro do header, à esquerda do ícone circular
                            leftWidget: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(20 * desktopScale),
                              child: Container(
                                padding: EdgeInsets.all(8 * desktopScale),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.14),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 16 * desktopScale,
                                ),
                              ),
                            ),
                            trailing: _buildHeaderTrailing(isTiny, titleSize, desktopScale),
                          );

                          // Helper: gera lista de widgets dos itens (evita ListView)
                          List<Widget> buildItemWidgets(double maxWidth) {
                            final widgets = <Widget>[];
                            for (var i = 0; i < widget.cart.length; i++) {
                              final item = widget.cart[i];
                              final selected = _selectedIndex == i;
                              widgets.add(AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: EdgeInsets.symmetric(vertical: itemVerticalMargin),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: selected ? 4 : 2,
                                  color: ColorManager.instance.background,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12 * desktopScale,
                                      vertical: selected ? 8 * desktopScale : 10 * desktopScale,
                                    ),
                                    onTap: () => _toggleSelect(i),
                                    leading: Icon(
                                      item.manual
                                          ? Icons.edit_note_rounded
                                          : (item.chemical != null ? Icons.science_rounded : Icons.bug_report_rounded),
                                      color: ColorManager.instance.primary,
                                      size: itemIconSize,
                                    ),
                                    title: Text(
                                      item.display,
                                      style: TextStyle(
                                        fontSize: itemTitleSize,
                                        color: ColorManager.instance.explicitText,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: ColorManager.instance.emergency,
                                            size: itemTrailingSize,
                                          ),
                                          onPressed: () => _removeItem(i),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ));
                            }
                            return widgets;
                          }

                          Widget contentArea() {
                            // If wide screen: two columns side-by-side.
                            if (isWide) {
                              final leftMaxWidth = localWidth * leftColumnWidthFactor;
                              final rightMaxWidth = localWidth * rightColumnWidthFactor;
                              return Padding(
                                padding: EdgeInsets.all(20 * desktopScale),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left column: items (as Column inside SingleChildScrollView)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: leftMaxWidth,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          ...buildItemWidgets(leftMaxWidth),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12 * desktopScale),
                                    // Right column: resumo / ações
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: rightMaxWidth,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(12 * desktopScale),
                                            decoration: BoxDecoration(
                                              color: ColorManager.instance.background,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: ColorManager.instance.card.withOpacity(0.2),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.list_alt_rounded,
                                                  color: ColorManager.instance.primary,
                                                  size: 18 * desktopScale,
                                                ),
                                                SizedBox(width: 10 * desktopScale),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Itens',
                                                        style: TextStyle(
                                                          fontSize: 13 * desktopScale,
                                                          color: ColorManager.instance.explicitText,
                                                        ),
                                                      ),
                                                      SizedBox(height: 6 * desktopScale),
                                                      Text(
                                                        '${widget.cart.length} ${widget.cart.length == 1 ? 'item' : 'itens'}',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 16 * desktopScale,
                                                          color: ColorManager.instance.explicitText,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 12 * desktopScale),
                                          Card(
                                            elevation: 0,
                                            color: ColorManager.instance.card.withOpacity(0.12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(12 * desktopScale),
                                              child: Text(
                                                'Revise os itens e finalize a solicitação. Você pode remover itens clicando no ícone de lixeira.',
                                                style: TextStyle(
                                                  color: ColorManager.instance.explicitText,
                                                  fontSize: 13 * desktopScale,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 12 * desktopScale),
                                          ElevatedButton.icon(
                                            onPressed: _finalize,
                                            icon: const Icon(Icons.send_rounded),
                                            label: const Text('Finalizar Solicitação'),
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 16 * desktopScale,
                                              ),
                                              backgroundColor: ColorManager.instance.primary,
                                              foregroundColor: ColorManager.instance.text,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12 * desktopScale),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 12 * desktopScale),
                                          Container(
                                            padding: EdgeInsets.all(10 * desktopScale),
                                            decoration: BoxDecoration(
                                              color: ColorManager.instance.background,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: ColorManager.instance.card.withOpacity(0.08)),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.account_balance_wallet_rounded, size: 18 * desktopScale, color: ColorManager.instance.primary),
                                                SizedBox(width: 8 * desktopScale),
                                                Expanded(
                                                  child: Text(
                                                    'Meus créditos: ${_fmt(widget.credits.creditos)}',
                                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13 * desktopScale, color: ColorManager.instance.explicitText),
                                                  ),
                                                )
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Narrow/mobile layout: stack items then summary/actions below
                            return Padding(
                              padding: EdgeInsets.all(16 * desktopScale),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...buildItemWidgets(localWidth),
                                  SizedBox(height: 12 * desktopScale),
                                  Container(
                                    padding: EdgeInsets.all(12 * desktopScale),
                                    decoration: BoxDecoration(
                                      color: ColorManager.instance.background,
                                      borderRadius: BorderRadius.circular(12 * desktopScale),
                                      border: Border.all(
                                        color: ColorManager.instance.card.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.list_rounded, color: ColorManager.instance.primary, size: 18 * desktopScale),
                                            SizedBox(width: 10 * desktopScale),
                                            Text(
                                              '${widget.cart.length} ${widget.cart.length == 1 ? 'item' : 'itens'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13 * desktopScale,
                                                color: ColorManager.instance.explicitText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8 * desktopScale),
                                        Row(
                                          children: [
                                            Icon(Icons.account_balance_wallet_rounded, size: 16 * desktopScale, color: ColorManager.instance.primary),
                                            SizedBox(width: 8 * desktopScale),
                                            Text(
                                              'Meus créditos:',
                                              style: TextStyle(
                                                color: ColorManager.instance.explicitText,
                                                fontSize: 12 * desktopScale,
                                              ),
                                            ),
                                            SizedBox(width: 8 * desktopScale),
                                            Text(
                                              '${_fmt(widget.credits.creditos)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13 * desktopScale,
                                                color: ColorManager.instance.explicitText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 12 * desktopScale),
                                  ElevatedButton.icon(
                                    onPressed: _finalize,
                                    icon: const Icon(Icons.send_rounded),
                                    label: const Text('Finalizar Solicitação'),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16 * desktopScale,
                                      ),
                                      backgroundColor: ColorManager.instance.primary,
                                      foregroundColor: ColorManager.instance.text,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12 * desktopScale),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Build the final Card content with header at top (not floating),
                          // followed by the padded content area.
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // header occupies the full width of the Card's top with rounded corners
                              header,
                              // content area (padded) sits directly below header; no divider -> header appears attached
                              contentArea(),
                              SizedBox(height: 8 * desktopScale),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Banner de dica de scroll — posicionado sobre toda a tela; exibido somente se houver overflow e ainda não dismissado
              if (!_bannerDismissed)
                Positioned(
                  bottom: 24,
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
      ),
    );
  }

  Widget _buildHeaderTrailing(bool isSmall, double titleSize, double desktopScale) {
    // Build a trailing widget similar to the compact credits container used previously.
    return Padding(
      padding: EdgeInsets.only(right: 8.0 * desktopScale),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * desktopScale, vertical: 8 * desktopScale),
        decoration: BoxDecoration(
          color: ColorManager.instance.card.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12 * desktopScale),
          border: Border.all(color: ColorManager.instance.card.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 18 * desktopScale,
              color: ColorManager.instance.text,
            ),
            SizedBox(width: 8 * desktopScale),
            Text(
              isSmall ? '${_fmt(widget.credits.creditos)}' : 'Meus créditos: ${_fmt(widget.credits.creditos)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: (isSmall ? 12 : 13) * desktopScale,
                color: ColorManager.instance.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int value) => value.toString();
}
