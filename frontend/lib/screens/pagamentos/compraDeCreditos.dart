// file: plans_page_compact_responsive.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/pagamentos/creditos.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreditBuyPage extends StatefulWidget {
  const CreditBuyPage({super.key});

  @override
  State<CreditBuyPage> createState() => _CreditBuyPageState();
}

class _CreditBuyPageState extends State<CreditBuyPage> {
  double unitPrice = 49.0; // atualizado a partir do servidor
  int buyQuantity = 1; // INICIAL: 1, conforme solicitado

  bool loading = false;

  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  late TextEditingController _qtyController;

  // controle local para exibir/descartar o banner de dica de scroll
  bool _bannerDismissed = false;

  // --- ScrollController para verificar overflow e detectar rolagem ---
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: buyQuantity.toString());

    // inicializa o controller e adiciona listener que fecha o banner se o usuário rolar
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _evaluateScrollable(); // checa se há conteúdo escondido e decide mostrar/ocultar banner
    });
  }

  // listener do scroll controller
  void _onScrollController() {
    if (!_bannerDismissed && _scroll_controllerHasClients()) {
      // se o usuário rolou alguns pixels, consideramos que ele já percebeu que há mais conteúdo
      if (_scrollController.position.pixels > 5) {
        setState(() => _bannerDismissed = true);
      }
    }
  }

  bool _scroll_controllerHasClients() => _scrollController.hasClients;

  // checa se o conteúdo é rolável (overflow). tenta novamente se controller ainda não tem clients.
  void _evaluateScrollable() {
    if (!_scrollController.hasClients) {
      // tenta novamente em curto intervalo até que o controller tenha clients
      Future.delayed(const Duration(milliseconds: 50), _evaluateScrollable);
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    // Se não houver espaço adicional para rolar, não mostramos o banner
    if (maxExtent <= 0) {
      if (mounted) setState(() => _bannerDismissed = true);
    } else {
      // Há overflow: mantemos o banner visível, a não ser que já tenha sido dismissado manualmente
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    // remove listener e dispose do controller
    _scrollController.removeListener(_onScrollController);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);

    setState(() => loading = true);
    try {
      await _fetchUnitPrice(userProv.user?.token ?? '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _fetchUnitPrice(String token) async {
    if (token.isEmpty) return;
    try {
      final uri = Uri.parse("$baseUrl/preco-credito");
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        final raw = body['preco_do_credito'] ?? body['preco'] ?? body['precoDoCredito'];
        double? parsed;
        if (raw != null) {
          if (raw is num) {
            parsed = raw.toDouble();
          } else {
            parsed = double.tryParse(raw.toString().replaceAll(',', '.'));
          }
        }
        if (parsed != null && parsed.isFinite) {
          if (mounted) setState(() => unitPrice = parsed!);
        } else {
          // mantém unitPrice anterior se parsing falhar
          // ignore: avoid_print
          print('preco_credito: parsing falhou, mantendo valor local: $raw');
        }
      } else {
        // ignore: avoid_print
        print('Erro ao buscar preco_do_credito: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Exceção ao buscar preco_do_credito: $e');
    }
  }

  String _fmtCurrency(double v) {
    // Retorna string no formato brasileiro com R$ e separador de milhares (ponto) e decimais (vírgula).
    if (!v.isFinite) return 'R\$ 0,00';

    final sign = v < 0 ? '-' : '';
    final absV = v.abs();

    // Trabalha em centavos para evitar problemas de precisão
    final int cents = (absV * 100).round();
    final int intPart = cents ~/ 100;
    final String decimals = (cents % 100).toString().padLeft(2, '0');

    // Insere separador de milhares: ex. 1234567 -> 1.234.567
    final String intStr = intPart.toString();
    final String formattedInt = intStr.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match _) => '.',
    );

    return '${sign}R\$ $formattedInt,$decimals';
  }

  Future<void> _performPurchase() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (!userProv.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }
    if (buyQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade inválida para compra')),
      );
      return;
    }

    setState(() => loading = true);
    Navigator.of(context)
        .push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            PaymentBeautifulPage(fixedAmountCents: (unitPrice * buyQuantity * 100).toInt()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    )
        .then((_) {
      // depois de voltar do fluxo de pagamento, recarregamos preço (caso tenha mudado)
      final userProvReload = Provider.of<UserProvider>(context, listen: false);
      if (userProvReload.isLoggedIn) _fetchUnitPrice(userProvReload.user!.token);
      if (mounted) setState(() => loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Valores básicos de responsividade
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW >= 900;

    // contentWidth mantém consistência com a versão original, mas ajusta para mobile
    final contentWidth = screenW > 1000 ? (screenW - 48) : min(1100.0, max(580.0, screenW - 32));
    final baseScale = (contentWidth / 960).clamp(0.78, 1.05);

    final subtotal = buyQuantity * unitPrice;
    final total = subtotal;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // fecha teclado ao tocar fora
      child: AnimatedBuilder(
        animation: ColorManager.instance,
        builder: (context, _) {
          final cm = ColorManager.instance;

          return Scaffold(
            backgroundColor: cm.background,
            body: SafeArea(
              child: Stack(
                children: [
                  // NotificationListener vinculado ao Scroll principal da tela
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (!_bannerDismissed &&
                          (notification is ScrollStartNotification || notification.metrics.pixels > 0)) {
                        setState(() {
                          _bannerDismissed = true;
                        });
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(vertical: 20 * baseScale),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: isWide
                                ? (MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical - 40 * baseScale)
                                : 0,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: contentWidth,
                              child: Card(
                                color: cm.card.withOpacity(0.10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: cm.card.withOpacity(0.12), width: 1),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // --- Header: elegante, integrado ao topo do card ---
                                    _ElegantHeader(
                                      primary: cm.primary,
                                      title: 'Créditos avulsos',
                                      onBack: () => Navigator.of(context).pop(),
                                      borderRadius: 20.0 * baseScale,
                                      scale: baseScale,
                                      icon: Icons.credit_score,
                                    ),

                                    // padding interior do card (mantido)
                                    Padding(
                                      padding: EdgeInsets.all(18 * baseScale),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(height: 8 * baseScale),

                                          // Conteúdo principal: usa Row em telas largas e Column em telas pequenas
                                          LayoutBuilder(builder: (context, constraints) {
                                            final useRow = constraints.maxWidth >= 760;

                                            return AnimatedCrossFade(
                                              firstChild: _buildHorizontalMain(cm, baseScale, total),
                                              secondChild: _buildVerticalMain(cm, baseScale, total),
                                              crossFadeState: useRow ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                              duration: const Duration(milliseconds: 300),
                                              firstCurve: Curves.easeInOut,
                                              secondCurve: Curves.easeInOut,
                                            );
                                          }),

                                          if (loading) ...[
                                            SizedBox(height: 16 * baseScale),
                                            LinearProgressIndicator(color: cm.primary),
                                          ],
                                        ],
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
                  ),

                  // Banner de dica de scroll
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
          );
        },
      ),
    );
  }

  Widget _buildHorizontalMain(ColorManager cm, double scale, double total) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: purchase card
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cm.card.withOpacity(0.06), cm.card.withOpacity(0.02)],
              ),
              border: Border.all(color: cm.card.withOpacity(0.12)),
            ),
            padding: EdgeInsets.all(16 * scale),
            child: _buildPurchaseContent(cm, scale, total),
          ),
        ),

        SizedBox(width: 14 * scale),

        // Right: summary
        SizedBox(
          width: min(360.0, 360 * scale),
          child: Container(
            padding: EdgeInsets.all(14 * scale),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cm.card.withOpacity(0.08),
              border: Border.all(color: cm.card.withOpacity(0.12)),
            ),
            child: _buildSummary(cm, scale, total),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalMain(ColorManager cm, double scale, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cm.card.withOpacity(0.06), cm.card.withOpacity(0.02)],
            ),
            border: Border.all(color: cm.card.withOpacity(0.12)),
          ),
          padding: EdgeInsets.all(16 * scale),
          child: _buildPurchaseContent(cm, scale, total),
        ),

        SizedBox(height: 12 * scale),

        Container(
          padding: EdgeInsets.all(14 * scale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: cm.card.withOpacity(0.08),
            border: Border.all(color: cm.card.withOpacity(0.12)),
          ),
          child: _buildSummary(cm, scale, total),
        ),
      ],
    );
  }

  Widget _buildPurchaseContent(ColorManager cm, double scale, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantidade', style: TextStyle(fontWeight: FontWeight.w800, color: cm.explicitText)),
        SizedBox(height: 8 * scale),

        Row(
          children: [
            // Minus: garante que não vai abaixo de 1
            _buildSquareIconButton(
              icon: Icons.remove,
              onTap: () => setState(() {
                buyQuantity = max(1, buyQuantity - 1);
                _qtyController.text = buyQuantity.toString();
                _qtyController.selection = TextSelection.collapsed(offset: _qtyController.text.length);
              }),
              cm: cm,
              scale: scale,
            ),

            SizedBox(width: 10 * scale),

            // Quantity input with flexible width — facilitado para digitar:
            // - seleciona todo ao focar
            // - filtra apenas dígitos
            // - normaliza para mínimo 1
            Expanded(
              child: SizedBox(
                height: 46 * scale,
                child: TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cm.card.withOpacity(0.14))),
                    filled: true,
                    fillColor: cm.card.withOpacity(0.06),
                  ),
                  onTap: () {
                    // facilita a edição: seleciona todo o texto quando o campo é tocado
                    _qtyController.selection = TextSelection(baseOffset: 0, extentOffset: _qtyController.text.length);
                  },
                  onChanged: (v) {
                    final parsed = int.tryParse(v) ?? 0;
                    setState(() {
                      // força mínimo 1 para evitar quantidades inválidas
                      buyQuantity = parsed >= 1 ? parsed : 1;
                      final normalized = buyQuantity.toString();
                      if (_qtyController.text != normalized) {
                        _qtyController.text = normalized;
                        _qtyController.selection = TextSelection.fromPosition(TextPosition(offset: normalized.length));
                      }
                    });
                  },
                  onFieldSubmitted: (_) {
                    // garante que não fica vazio/zero após submissão
                    if (_qtyController.text.isEmpty) {
                      setState(() {
                        buyQuantity = 1;
                        _qtyController.text = '1';
                        _qtyController.selection = TextSelection.collapsed(offset: 1);
                      });
                    }
                  },
                ),
              ),
            ),

            SizedBox(width: 10 * scale),

            // Plus
            _buildSquareIconButton(
              icon: Icons.add,
              onTap: () => setState(() {
                buyQuantity = (buyQuantity + 1).clamp(1, 99999);
                _qtyController.text = buyQuantity.toString();
                _qtyController.selection = TextSelection.collapsed(offset: _qtyController.text.length);
              }),
              cm: cm,
              scale: scale,
            ),

            SizedBox(width: 8 * scale),

            // Observação: removi presets para atender ao pedido do usuário
          ],
        ),

        SizedBox(height: 18 * scale),

        // Total and CTA
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: TextStyle(fontSize: 13 * scale, color: cm.explicitText.withOpacity(0.8))),
                  SizedBox(height: 6 * scale),
                  Text(_fmtCurrency(total), style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w900, color: cm.explicitText)),
                ],
              ),
            ),

            SizedBox(width: 12 * scale),

            SizedBox(
              width: 160 * scale,
              height: 48 * scale,
              child: ElevatedButton(
                onPressed: buyQuantity > 0
                    ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirmar compra'),
                            content: Text('Comprar $buyQuantity créditos por ${_fmtCurrency(total)}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _performPurchase();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.instance.primary,
                  foregroundColor: ColorManager.instance.text,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ColorManager.instance.text))
                    : Text('Pagar', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(ColorManager cm, double scale, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(Icons.receipt_long, color: cm.primary, size: 18 * scale), SizedBox(width: 8 * scale), Text('Resumo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14 * scale, color: cm.explicitText))]),
        SizedBox(height: 12 * scale),
        Row(children: [Icon(Icons.confirmation_num_outlined, size: 16 * scale, color: cm.primary), SizedBox(width: 8 * scale), Text('Quantidade', style: TextStyle(fontSize: 14 * scale, color: cm.explicitText)), Spacer(), Text('$buyQuantity', style: TextStyle(fontWeight: FontWeight.w900, color: cm.explicitText))]),
        SizedBox(height: 10 * scale),
        Row(children: [Icon(Icons.monetization_on_outlined, size: 16 * scale, color: cm.primary), SizedBox(width: 8 * scale), Text('Unitário', style: TextStyle(fontSize: 14 * scale, color: cm.explicitText)), Spacer(), Text(_fmtCurrency(unitPrice), style: TextStyle(fontWeight: FontWeight.w700, color: cm.explicitText))]),
        SizedBox(height: 10 * scale),
        Divider(color: cm.card.withOpacity(0.16)),
        SizedBox(height: 10 * scale),
        Row(children: [Icon(Icons.payments_outlined, size: 16 * scale, color: cm.primary), SizedBox(width: 8 * scale), Text('Total', style: TextStyle(fontSize: 15 * scale, color: cm.explicitText)), Spacer(), Text(_fmtCurrency(total), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15 * scale, color: cm.explicitText))]),
        SizedBox(height: 14 * scale),
        Text('Você será redirecionado ao fluxo de pagamento. Após concluir, retorne ao app.', style: TextStyle(fontSize: 12 * scale, color: cm.explicitText.withOpacity(0.75))),
      ],
    );
  }

  Widget _buildSquareIconButton({required IconData icon, required VoidCallback onTap, required ColorManager cm, required double scale}) {
    return Material(
      color: cm.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44 * scale,
          height: 44 * scale,
          alignment: Alignment.center,
          child: Icon(icon, size: 20 * scale, color: cm.primary),
        ),
      ),
    );
  }
}

/// Elegant header widget used at the top of the card.
/// Kept purely visual — "onBack" preserves existing navigation behavior.
class _ElegantHeader extends StatelessWidget {
  final Color primary;
  final String title;
  final VoidCallback onBack;
  final double borderRadius;
  final double scale;
  final IconData icon;

  const _ElegantHeader({
    Key? key,
    required this.primary,
    required this.title,
    required this.onBack,
    this.borderRadius = 20.0,
    this.scale = 1.0,
    this.icon = Icons.credit_score,
  }) : super(key: key);

  Color _darken(Color c, [double amount = 0.12]) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
  //  final cm = ColorManager.instance;
    final primaryMid = _darken(primary, 0.06);
    final primaryEnd = _darken(primary, 0.18);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryMid, primaryEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: Offset(0, 6 * scale),
            blurRadius: 18 * scale,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 14 * scale),
      child: Row(
        children: [
        


          // Leading icon
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(icon, color: Colors.white, size: 18 * scale),
          ),

          SizedBox(width: 12 * scale),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16 * scale,
                  ),
                ),
             
              ],
            ),
          ),

          // small action placeholder (keeps UI balanced)
         
        ],
      ),
    );
  }
}
