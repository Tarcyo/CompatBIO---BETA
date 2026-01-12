// lib/payment_beautiful_reimagined_v2.dart
// Versão reimaginada e refinada: mantém a funcionalidade principal
// - Recupera token do UserProvider e envia Authorization: Bearer <token>
// - Mesmo endpoint backendBaseUrl (ajuste via .env)
// - Responsiva, adaptativa (mobile / tablet / desktop)
// - Design modernizado: tipografia, espaço, animações sutis, feedbacks acessíveis
// Observação: usamos url_launcher para redirecionamento web em vez de dart:html.
// Se for compilar para mobile, mantenha a checagem kIsWeb como antes.

import 'dart:convert';
import 'dart:ui' as ui; // para BackdropFilter blur
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/styles/syles.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// import do ScrollHintBanner (implementação previamente fornecida em utils)
import 'package:planos/utils/scroll_hint_banner.dart';

final String backendBaseUrl = (dotenv.env['BASE_URL'])! + '/pagamentosDeCreditos';
const String currency = 'brl';

/// Tela exportada
class PaymentBeautifulPage extends StatefulWidget {
  final int fixedAmountCents;
  const PaymentBeautifulPage({super.key, required this.fixedAmountCents});

  @override
  State<PaymentBeautifulPage> createState() => _PaymentBeautifulPageState();
}

class _PaymentBeautifulPageState extends State<PaymentBeautifulPage>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _selectedMethod = 'card';

  late final AnimationController _animController;
  late final Animation<double> _cardScale;

  final List<_Method> _methods = const [
    _Method(
      id: 'card',
      label: 'Cartão',
      icon: Icons.credit_card,
      subtitle: 'Confirmado instantaneamente',
    ),
    _Method(
      id: 'boleto',
      label: 'Boleto',
      icon: Icons.receipt_long,
      subtitle: 'Compensação em até 3 dias',
    ),
  ];

  // --- ADIÇÃO: controlador de scroll e flag para banner ---
  late final ScrollController _scrollController;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _cardScale = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward(from: 0.0);

    // inicializa scroll controller para detectar overflow e rolagem
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollController);

    // checar overflow depois do primeiro frame para decidir se mostramos o banner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateScrollable();
    });
  }

  // listener que fecha o banner quando o usuário rolar alguns pixels
  void _onScrollController() {
    if (!_bannerDismissed && _scrollController.hasClients) {
      if (_scrollController.position.pixels > 5) {
        setState(() => _bannerDismissed = true);
      }
    }
  }

  // tenta avaliar se existe conteúdo escondido (overflow). se controller ainda não tiver clients, tenta novamente.
  void _evaluateScrollable() {
    if (!_scroll_controller_has_clients()) {
      Future.delayed(const Duration(milliseconds: 50), _evaluateScrollable);
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      // nada a rolar -> não mostrar banner
      if (mounted) setState(() => _bannerDismissed = true);
    } else {
      // há overflow: mantemos o banner disponível (a menos que o usuário já o tenha dismissado)
    }
  }

  bool _scroll_controller_has_clients() => _scrollController.hasClients;

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.removeListener(_onScrollController);
    _scroll_controller_safeDispose();
    super.dispose();
  }

  void _scroll_controller_safeDispose() {
    try {
      _scrollController.dispose();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _createCheckoutSession() async {
    final uri = Uri.parse('$backendBaseUrl/create-checkout-session');

    final token = Provider.of<UserProvider>(context, listen: false).user!.token;

    final headers = <String, String>{'Content-Type': 'application/json'};
    headers['Authorization'] = 'Bearer $token';

    // Tenta obter dados do usuário via Provider para popular user_email/metadata
    String userEmail = '';
    String? userId;
    String? userName = '';

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final u = userProvider.user;
      if (u != null) {
        userEmail = u.email ;
        userId = u.id.toString();
        userName = u.nome;
      }
    } catch (_) {
      // ignore
    }

    final localOrderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    final body = {
      'amount': widget.fixedAmountCents,
      'currency': currency,
      'name': 'Compra Rápida',
      'payment_methods': [_selectedMethod],
      // metadata enviado para o servidor. servidor pode propagar para metadata do Stripe
      'user_email': userEmail,
      'user_name': userName,
      'local_order_id': localOrderId,
      // adiciona user_id como metadata (opcional, não inclua token nos metadata por segurança)
      if (userId != null) 'user_id': userId,
    };

    final res = await http.post(uri, headers: headers, body: jsonEncode(body));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Server error ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> _pay() async {
    // Removido bloqueio a mobile: agora o fluxo funciona tanto na web quanto em dispositivos móveis.
    setState(() => _loading = true);
    try {
      final session = await _createCheckoutSession();
      final url = session['url'] as String?;
      if (url == null) throw Exception('Checkout URL não retornado pelo backend.');
      await Future.delayed(const Duration(milliseconds: 200));
      final uri = Uri.parse(url);

      // plataforma web: abrir na mesma aba (mesma lógica anterior para web)
      if (kIsWeb) {
        final launched = await launchUrl(uri, webOnlyWindowName: '_self');
        if (!launched) throw Exception('Não foi possível redirecionar para $url');
        return;
      }

      // mobile/desktop (não-web): abrir no navegador externo (recomendado para Stripe Checkout)
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Não foi possível redirecionar para $url');
    } catch (e) {
      _showSnack('Erro: ${_shortError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _shortError(Object e) {
    final s = e.toString();
    return s.length > 140 ? '${s.substring(0, 137)}...' : s;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    final cm = ColorManager.instance;
    final bg = cm.alert;
    final fg = _contrastColor(bg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: TextStyle(color: fg)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectMethod(String id) {
    if (_selectedMethod == id) return;
    setState(() => _selectedMethod = id);
    _animController.forward(from: 0.0);
  }

  Color _soften(Color c, [double factor = 0.18]) {
    final h = HSLColor.fromColor(c);
    final newLight = (h.lightness + (1.0 - h.lightness) * factor).clamp(0.0, 1.0);
    return h.withLightness(newLight).toColor();
  }

  Color _contrastColor(Color bg) => bg.computeLuminance() > 0.56 ? Colors.black : Colors.white;

  String _formatCurrency(int cents) {
    final major = cents / 100.0;
    final parts = major.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final centsPart = parts[1];
    return 'R\$ $whole,$centsPart';
  }

  // UTIL: executa ação de 'voltar' com checagem
  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      _showSnack('Nenhuma rota anterior.');
    }
  }

  // Pequeno utilitário para escurecer cor
  Color _darken(Color c, [double amount = 0.12]) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (intent) => _handleBack(),
          ),
        },
        child: FocusScope(
          child: AnimatedBuilder(
            animation: ColorManager.instance,
            builder: (context, _) {
              final cm = ColorManager.instance;

              return Scaffold(
                backgroundColor: cm.background,
                body: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      // Conteúdo principal (agora dentro de Stack para sobrepor o banner)
                      Center(
                        child: LayoutBuilder(builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 720;
                          final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1100;
                          final maxCardWidth = isNarrow ? constraints.maxWidth - 28 : 980.0;

                          return SingleChildScrollView(
                            controller: _scrollController, // controlador adicionado
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 12 : 20,
                              vertical: isNarrow ? 18 : 36,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                                  child: ScaleTransition(
                                    scale: _cardScale,
                                    child: _singlePrimaryCard(cm, isNarrow, isTablet),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (isNarrow)
                                  Text(
                                    'Ao prosseguir você será direcionado para o provedor de pagamento.',
                                    style: TextStyle(color: cm.background.withOpacity(0.65)),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),

                      // ScrollHintBanner — posicionado sobre toda a tela; exibido somente se houver overflow e ainda não dismissado
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
        ),
      ),
    );
  }

  Widget _singlePrimaryCard(ColorManager cm, bool isNarrow, bool isTablet) {
    // Card único: fundo usa a cor primária. Conteúdo interno em branco para contraste.
    final primary = cm.primary;

    return Container(
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: EdgeInsets.all(isNarrow ? 14 : 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---------- HEADER ADICIONADO (elegante, harmônico com o restante do app) ----------
          _paymentHeader(primary: primary, scale: isNarrow ? 0.92 : 1.0),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: wide
                  ? Row(children: _singleCardChildren(cm, wide))
                  : Column(children: _singleCardChildren(cm, wide)),
            );
          }),
        ],
      ),
    );
  }

  /// Novo header elegante e coerente — mantém ação de voltar e exibe valor à direita.
  Widget _paymentHeader({required Color primary, double scale = 1.0}) {
   // final cm = ColorManager.instance;
    final primaryMid = _darken(primary, 0.06);
    final primaryEnd = _darken(primary, 0.16);
    final fg = _contrastColor(primary);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primaryMid, primaryEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 12 * scale),
      child: Row(
        children: [
          // back button (mantém comportamento)
          Material(
            color: Colors.white.withOpacity(0.10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * scale)),
            child: InkWell(
              onTap: _handleBack,
              borderRadius: BorderRadius.circular(10 * scale),
              child: Padding(
                padding: EdgeInsets.all(8 * scale),
                child: Icon(Icons.arrow_back, color: fg, size: 18 * scale),
              ),
            ),
          ),
          SizedBox(width: 12 * scale),

          // circular icon
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(Icons.payments, color: fg, size: 18 * scale),
          ),
          SizedBox(width: 12 * scale),

          // title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tela de Pagamentos',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 16 * scale,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  'Compra Rápida — redirecionamento seguro',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg.withOpacity(0.92),
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // valor à direita (badge)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(widget.fixedAmountCents),
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14 * scale,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  'Total',
                  style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 11 * scale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Corrigido: não usar Expanded quando estiver dentro de Column (não-wide)
  List<Widget> _singleCardChildren(ColorManager cm, bool wide) {
    final Widget left = wide ? Expanded(child: _contentInsidePrimary(cm)) : _contentInsidePrimary(cm);
    final Widget right = wide
        ? SizedBox(width: 380, child: _summaryInsidePrimary(cm))
        : SizedBox(width: double.infinity, child: _summaryInsidePrimary(cm));

    if (wide) return [left, const SizedBox(width: 20), right];
    return [left, const SizedBox(height: 18), right];
  }

  Widget _contentInsidePrimary(ColorManager cm) {
    // Conteúdo principal: cada seção em um painel branco (pequena elevação) dentro do card primário.
    final primary = cm.primary;
    final softPrimary = _soften(primary, 0.14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lock, color: primary, size: 20),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Painel branco com preço (mais espaço e tipografia)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valor a pagar',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.88),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: widget.fixedAmountCents / 100.0),
                    duration: const Duration(milliseconds: 720),
                    builder: (context, value, child) => Text(
                      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pagamento em ${currency.toUpperCase()}',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, softPrimary]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: _contrastColor(primary)),
                    const SizedBox(width: 8),
                    Text(
                      'Seguro',
                      style: TextStyle(
                        color: _contrastColor(primary),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        Text(
          'Métodos de pagamento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        const SizedBox(height: 12),

        // métodos com cartões brancos (adicionados foco e hover acessíveis)
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _methods.map((m) {
            final selected = m.id == _selectedMethod;
            return FocusableActionDetector(
              mouseCursor: SystemMouseCursors.click,
              actions: {
                ActivateIntent: CallbackAction(
                  onInvoke: (intent) => _selectMethod(m.id),
                ),
              },
              child: _MethodCard(
                method: m,
                selected: selected,
                onTap: () => _selectMethod(m.id),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Text(
            _methods.firstWhere((mm) => mm.id == _selectedMethod).subtitle,
            key: ValueKey(_selectedMethod),
            style: TextStyle(color: Colors.white.withOpacity(0.92)),
          ),
        ),

        const SizedBox(height: 14),
        // Espaço neutro — removido campo de cupom por solicitação
      ],
    );
  }

  Widget _summaryInsidePrimary(ColorManager cm) {
    // Painel sumário em branco sobre o fundo primário
    final greenButton = const Color(0xFF16A34A); // verde moderno
    final onGreen = _contrastColor(greenButton);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumo',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.95),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Compra Rápida • ${DateTime.now().year}',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.62),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(widget.fixedAmountCents),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.62),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.black.withOpacity(0.04)),
                  const SizedBox(height: 12),

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Método', style: TextStyle(color: Colors.black.withOpacity(0.64))),
                      Text(
                        _methods.firstWhere((m) => m.id == _selectedMethod).label,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.84),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botão verde conforme solicitado
                  SizedBox(
                    width: double.infinity,
                    child: _HoverScale(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _pay,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          backgroundColor: greenButton,
                          foregroundColor: onGreen,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: _loading
                              ? SizedBox(
                                  key: const ValueKey('loading'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: onGreen,
                                  ),
                                )
                              : Row(
                                  key: const ValueKey('label'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_bag_outlined, color: onGreen, size: 18),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Pagar agora',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: onGreen,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Ao clicar em pagar você será redirecionado ao provedor de pagamentos.',
                    style: TextStyle(color: Colors.black.withOpacity(0.58), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Pequeno widget que aplica escala sutil no hover/press (web/desktop)
class _HoverScale extends StatefulWidget {
  final Widget child;
  const _HoverScale({required this.child});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hover = false;
  bool _pressed = false;

  void _setHover(bool v) => setState(() => _hover = v);
  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : (_hover ? 1.03 : 1.0);
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        behavior: HitTestBehavior.translucent,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

// Cartão do método com foco e hover claros; mantém cores internas brancas em texto preto
class _MethodCard extends StatelessWidget {
  final _Method method;
  final bool selected;
  final VoidCallback onTap;
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
        : Colors.grey.withOpacity(0.06);
    return Semantics(
      button: true,
      label: 'Método de pagamento ${method.label}',
      child: _HoverScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade50,
                  child: Icon(method.icon, size: 18, color: selected ? Colors.white : Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.label,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.96),
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method.subtitle,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.62),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Method {
  final String id;
  final String label;
  final IconData icon;
  final String subtitle;
  const _Method({
    required this.id,
    required this.label,
    required this.icon,
    required this.subtitle,
  });
}
