import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class PlansPageCompact extends StatefulWidget {
  const PlansPageCompact({super.key});

  @override
  State<PlansPageCompact> createState() => _PlansPageCompactStateReal();
}

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
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
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

/// Implementation state for PlansPageCompact (the real one)
class _PlansPageCompactStateReal extends State<PlansPageCompact>
    with SingleTickerProviderStateMixin {
  int? activePlanId;
  String activePlanName = 'Carregando...';

  bool loading = false;
  bool changingPlan = false;

  int? activeAssinaturaId;
  String? activeStripeSubscriptionId;
  bool isLinkedToSubscription = false;

  bool cancelling = false;

  List<Plan> plans = [];

  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  late final AnimationController _pulseController;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (!userProv.isLoggedIn) {
      setState(() {
        plans = [];
        activePlanName = 'Offline';
        activePlanId = null;
        activeAssinaturaId = null;
        activeStripeSubscriptionId = null;
        isLinkedToSubscription = false;
      });
      return;
    }

    setState(() => loading = true);
    try {
      await Future.wait([
        _fetchPlans(userProv.user!.token),
        _fetchMyPlan(userProv.user!.token),
      ]);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _fetchPlans(String token) async {
    final uri = Uri.parse("$baseUrl/planos");
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final List<dynamic> body = jsonDecode(res.body);
      setState(() {
        plans = body.map((e) => Plan.fromJson(e)).toList();
      });
    } else {
      print("Erro fetch planos: ${res.statusCode} ${res.body}");
    }
  }

  Future<void> _fetchMyPlan(String token) async {
    final uri = Uri.parse("$baseUrl/planos/me");
    try {
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final plano = data['plano'] ?? data;
        if (plano != null) {
          setState(() {
            activePlanId = plano['id'] is int
                ? plano['id']
                : int.tryParse(plano['id']?.toString() ?? '');
            activePlanName =
                plano['nome'] ?? plano['nome_do_plano'] ?? activePlanName;
          });
        }

        int? assinaturaId;
        String? subscriptionId;

        final maybeAssinaturaId =
            data['assinaturaId'] ??
            data['assinatura']?['id'] ??
            data['subscriptionId'] ??
            data['subscription']?['id'] ??
            data['id'] ??
            data['assinatura_id'];

        if (maybeAssinaturaId != null) {
          if (maybeAssinaturaId is int)
            assinaturaId = maybeAssinaturaId;
          else {
            final parsed = int.tryParse(maybeAssinaturaId.toString());
            if (parsed != null) assinaturaId = parsed;
          }
        }

        final maybeStripeSub =
            data['subscriptionId'] ??
            data['stripe_subscription_id'] ??
            data['stripeSubscriptionId'] ??
            data['subscription']?['stripe_subscription_id'] ??
            data['subscription']?['id'] ??
            data['stripe_subscription'];

        if (maybeStripeSub != null) {
          subscriptionId = maybeStripeSub.toString();
        }

        if (assinaturaId == null) {
          final nested = data['assinatura'] ?? data['assinaturaData'] ?? null;
          if (nested != null && nested['id'] != null) {
            final nid = nested['id'];
            if (nid is int)
              assinaturaId = nid;
            else {
              final parsed = int.tryParse(nid.toString());
              if (parsed != null) assinaturaId = parsed;
            }
          }
        }

        setState(() {
          activeAssinaturaId = assinaturaId;
          activeStripeSubscriptionId = subscriptionId;
          isLinkedToSubscription =
              (activeAssinaturaId != null) || (activeStripeSubscriptionId != null);
        });
      } else {
        setState(() {
          activeAssinaturaId = null;
          activeStripeSubscriptionId = null;
          isLinkedToSubscription = false;
        });
      }
    } catch (e) {
      print("Erro fetchMyPlan: $e");
      setState(() {
        activeAssinaturaId = null;
        activeStripeSubscriptionId = null;
        isLinkedToSubscription = false;
      });
    }
  }

  String _fmtCurrency(double v) {
    final fixed = v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decimals = parts[1];
    final withDots =
        intPart.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $withDots,$decimals';
  }

  Future<void> _createSubscription(
    int planId, {
    List<String>? linkedEmails,
  }) async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (!userProv.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }

    setState(() => changingPlan = true);
    try {
      final uri = Uri.parse(
        "$baseUrl/pagamentosDeAssinaturas/create-subscription",
      );

      final Map<String, dynamic> payload = {'planId': planId};
      if (linkedEmails != null && linkedEmails.isNotEmpty) {
        payload['metadata'] = {'linked_emails': linkedEmails};
      }

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userProv.user!.token}',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final url = body['url'] as String?;
        if (url != null && url.isNotEmpty) {
          if (kIsWeb) {
            await Future.delayed(const Duration(milliseconds: 200));
            final uriToLaunch = Uri.parse(url);
            final launched = await launchUrl(uriToLaunch, webOnlyWindowName: '_self');
            if (!launched) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Não foi possível redirecionar na mesma aba.')),
              );
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Abra este link'),
                  content: SelectableText(url),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            }
          } else {
            final uriToLaunch = Uri.parse(url);
            if (await canLaunchUrl(uriToLaunch)) {
              await launchUrl(
                uriToLaunch,
                mode: LaunchMode.externalApplication,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Abrindo Stripe Checkout... Complete a assinatura no navegador.',
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Não foi possível abrir o navegador para o checkout. Copiando link...',
                  ),
                ),
              );
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Abra este link'),
                  content: SelectableText(url),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resposta inesperada do servidor: url ausente'),
            ),
          );
        }
      } else {
        final err = res.body;
        print('Erro criar subscription: ${res.statusCode} $err');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar subscription: ${res.statusCode}'),
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Exception create subscription: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao iniciar assinatura: $e')));
    } finally {
      if (mounted) setState(() => changingPlan = false);
      _loadData();
    }
  }

  Future<void> _confirmAndSubscribe(Plan p) async {
    List<String>? emailsToLink;
    if (_isEnterprisePlanName(p.nome)) {
      // now pass maximo_colaboradores to the dialog so it enforces the limit
      final result = await _showLinkEmailsDialog(p);
      if (result == null) {
        return;
      }
      emailsToLink = result;
    }

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Confirmar assinatura'),
        content: Text(
          'Assinar o plano "${p.nome}" (ID ${p.id}) por ${_fmtCurrency(p.precoMensal)} / mês?\n'
          '${(emailsToLink != null && emailsToLink.isNotEmpty) ? "\nEmails a vincular: ${emailsToLink.join(", ")}" : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _createSubscription(p.id, linkedEmails: emailsToLink);
    }
  }

  Future<void> _cancelSubscription() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (!userProv.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar assinatura'),
        content: const Text(
          'Tem certeza que deseja cancelar sua assinatura agora? Essa ação pode ser irreversível dependendo da política.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Manter'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar assinatura'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => cancelling = true);

    final uri = Uri.parse("$baseUrl/cancelamentoAssinatura/cancelar");
    final Map<String, dynamic> body = {};
    if (activeAssinaturaId != null) {
      body['assinaturaId'] = activeAssinaturaId;
    } else if (activeStripeSubscriptionId != null) {
      body['subscriptionId'] = activeStripeSubscriptionId;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível identificar sua assinatura para cancelamento.',
          ),
        ),
      );
      setState(() => cancelling = false);
      return;
    }

    try {
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userProv.user!.token}',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assinatura cancelada com sucesso.')),
        );
        await _loadData();
        Navigator.of(context).pop(1);
      } else {
        String msg = res.body;
        try {
          final parsed = jsonDecode(res.body);
          if (parsed is Map && parsed['error'] != null)
            msg = parsed['error'].toString();
          else if (parsed is Map && parsed['message'] != null) msg = parsed['message'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao cancelar: ${res.statusCode} ${msg}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de rede ao cancelar assinatura: $e')),
      );
    } finally {
      if (mounted) setState(() => cancelling = false);
    }
  }

  bool _isEnterprisePlanName(String? name) {
    if (name == null) return false;
    return name.toLowerCase().contains('enterprise');
  }

  Future<List<String>?> _showLinkEmailsDialog(Plan p) async {
    // pass the plan's maximoColaboradores to the dialog
    return await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmailsListDialog(maxEmails: p.maximoColaboradores),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedPlans = plans.isNotEmpty
        ? plans
        : [
            Plan(
              id: 0,
              nome: 'Starter',
              precoMensal: 0,
              quantidadeCreditoMensal: 0,
              prioridade: 0,
              maximoColaboradores: 0,
            ),
            Plan(
              id: 1,
              nome: 'Pro',
              precoMensal: 299,
              quantidadeCreditoMensal: 0,
              prioridade: 1,
              maximoColaboradores: 0,
            ),
            Plan(
              id: 2,
              nome: 'Enterprise',
              precoMensal: 1199,
              quantidadeCreditoMensal: 0,
              prioridade: 2,
              maximoColaboradores: 10,
            ),
          ];

    final Plan? myPlanFromList = (activePlanId != null)
        ? displayedPlans.firstWhere(
            (p) => p.id == activePlanId,
            orElse: () => Plan(
              id: activePlanId ?? 0,
              nome: activePlanName,
              precoMensal: 0,
              quantidadeCreditoMensal: 0,
              prioridade: 0,
              maximoColaboradores: 0,
            ),
          )
        : null;

    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return Scaffold(
          backgroundColor: cm.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (!_bannerDismissed &&
                            (notification is ScrollStartNotification ||
                                notification.metrics.pixels > 0)) {
                          setState(() {
                            _bannerDismissed = true;
                          });
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: SizedBox(
                              width: constraints.maxWidth > 1100
                                  ? (constraints.maxWidth - 64)
                                  : min(1100.0, max(620.0, constraints.maxWidth - 32)),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight > 700 ? (constraints.maxHeight - 48) : 0,
                                ),
                                child: Card(
                                  color: cm.card.withOpacity(0.06),
                                  elevation: 6,
                                  shadowColor: cm.card.withOpacity(0.12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: cm.card.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, box) {
                                      // compute scale here and reuse for header + content
                                      final maxW = box.maxWidth;
                                      final scale = (maxW / 980).clamp(0.80, 1.06);

                                      double planCardWidth;
                                      if (maxW >= 1100) {
                                        planCardWidth = (maxW - 48) / 3;
                                      } else if (maxW >= 760) {
                                        planCardWidth = (maxW - 32) / 2;
                                      } else {
                                        planCardWidth = maxW;
                                      }

                                      final fisicaPlans = displayedPlans.where((p) => !_isEnterprisePlanName(p.nome)).toList();
                                      final juridicaPlans = displayedPlans.where((p) => _isEnterprisePlanName(p.nome)).toList();

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Header integrado no topo do card (novo)
                                          ResultCardHeader(
                                            title: 'Gerenciar Planos & Assinaturas',
                                            leadingIcon: Icons.credit_score_rounded,
                                            primary: cm.primary,
                                            borderRadius: 20.0,
                                            verticalPadding: 14 * scale,
                                            horizontalPadding: 20 * scale,
                                            scale: scale,
                                          ),

                                          // Conteúdo (mantido como antes, só ajustei o padding superior)
                                          Padding(
                                            padding: const EdgeInsets.all(20.0).copyWith(top: 18.0),
                                            child: LayoutBuilder(
                                              builder: (context, inner) {
                                                final scaleInner = scale;
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.info_outline, color: cm.primary, size: 20 * scaleInner),
                                                        SizedBox(width: 10 * scaleInner),
                                                        Expanded(
                                                          child: Text(
                                                            'Escolha um plano abaixo ou atualize sua assinatura. Para contratos Enterprise, vincule usuários diretamente ao assinar.',
                                                            style: TextStyle(color: cm.explicitText.withOpacity(0.8), fontSize: 13 * scaleInner),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 18 * scaleInner),

                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Container(
                                                            padding: EdgeInsets.all(14 * scaleInner),
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors: [cm.background, cm.card.withOpacity(0.04)],
                                                              ),
                                                              borderRadius: BorderRadius.circular(14),
                                                              border: Border.all(
                                                                color: cm.card.withOpacity(0.10),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(Icons.credit_card, color: cm.primary, size: 24 * scaleInner),
                                                                SizedBox(width: 12 * scaleInner),
                                                                Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      'Seu plano atual',
                                                                      style: TextStyle(fontSize: 13 * scaleInner, color: cm.explicitText.withOpacity(0.7)),
                                                                    ),
                                                                    SizedBox(height: 6 * scaleInner),
                                                                    Row(
                                                                      children: [
                                                                        Text(
                                                                          activePlanName,
                                                                          style: TextStyle(fontSize: 17 * scaleInner, fontWeight: FontWeight.w900, color: cm.primary),
                                                                        ),
                                                                        SizedBox(width: 8 * scaleInner),
                                                                        Container(
                                                                          padding: EdgeInsets.symmetric(horizontal: 8 * scaleInner, vertical: 4 * scaleInner),
                                                                          decoration: BoxDecoration(
                                                                            color: cm.ok,
                                                                            borderRadius: BorderRadius.circular(10),
                                                                          ),
                                                                          child: Text(
                                                                            'Atual',
                                                                            style: TextStyle(color: cm.text, fontSize: 12 * scaleInner),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    SizedBox(height: 18 * scaleInner),

                                                    if (activePlanId == null)
                                                      DefaultTabController(
                                                        length: 2,
                                                        initialIndex: 0,
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                                          children: [
                                                            // container que integra visualmente o TabBar ao card
                                                            Container(
                                                              padding: EdgeInsets.all(6 * scaleInner),
                                                              decoration: BoxDecoration(
                                                                color: cm.background,
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 6 * scaleInner, vertical: 6 * scaleInner),
                                                                decoration: BoxDecoration(
                                                                  color: cm.card.withOpacity(0.02),
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                                child: TabBar(
                                                                  indicator: BoxDecoration(
                                                                    color: cm.primary.withOpacity(0.12),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: cm.primary.withOpacity(0.06),
                                                                        blurRadius: 10,
                                                                        offset: const Offset(0, 4),
                                                                      ),
                                                                    ],
                                                                    border: Border.all(color: cm.primary.withOpacity(0.14)),
                                                                  ),
                                                                  indicatorPadding: EdgeInsets.symmetric(horizontal: 6 * scaleInner, vertical: 4 * scaleInner),
                                                                  labelPadding: EdgeInsets.symmetric(horizontal: 12 * scaleInner, vertical: 6 * scaleInner),
                                                                  splashFactory: NoSplash.splashFactory,
                                                                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                                                                  indicatorSize: TabBarIndicatorSize.tab,
                                                                  labelColor: cm.primary,
                                                                  unselectedLabelColor: cm.explicitText.withOpacity(0.78),
                                                                  labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13 * scaleInner),
                                                                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12 * scaleInner),
                                                                  tabs: [
                                                                    Tab(
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        children: [
                                                                          Icon(Icons.person, size: 16 * scaleInner),
                                                                          SizedBox(width: 8 * scaleInner),
                                                                          Text('Pessoa Física'),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Tab(
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        children: [
                                                                          Icon(Icons.business, size: 16 * scaleInner),
                                                                          SizedBox(width: 8 * scaleInner),
                                                                          Text('Pessoa Jurídica'),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),

                                                            SizedBox(height: 12 * scaleInner),

                                                            ConstrainedBox(
                                                              constraints: BoxConstraints(
                                                                maxHeight: 800,
                                                                minHeight: 60,
                                                              ),
                                                              child: TabBarView(
                                                                physics: const NeverScrollableScrollPhysics(),
                                                                children: [
                                                                  // Pessoa Física
                                                                  LayoutBuilder(
                                                                    builder: (context, inner2) {
                                                                      return Wrap(
                                                                        spacing: 16 * scaleInner,
                                                                        runSpacing: 12 * scaleInner,
                                                                        children: fisicaPlans.isNotEmpty
                                                                            ? fisicaPlans.map((p) {
                                                                                return SizedBox(width: planCardWidth - 16, child: _elegantPlanCard(p, p.id == activePlanId, scaleInner, cm));
                                                                              }).toList()
                                                                            : [
                                                                                SizedBox(
                                                                                  width: planCardWidth - 16,
                                                                                  child: Container(
                                                                                    padding: EdgeInsets.all(16 * scaleInner),
                                                                                    decoration: BoxDecoration(
                                                                                      color: cm.card.withOpacity(0.02),
                                                                                      borderRadius: BorderRadius.circular(12),
                                                                                      border: Border.all(color: cm.card.withOpacity(0.06)),
                                                                                    ),
                                                                                    child: Text('Nenhum plano para Pessoa Física encontrado.', style: TextStyle(color: cm.explicitText.withOpacity(0.8))),
                                                                                  ),
                                                                                )
                                                                              ],
                                                                      );
                                                                    },
                                                                  ),
                                                                  // Pessoa Jurídica
                                                                  LayoutBuilder(
                                                                    builder: (context, inner2) {
                                                                      return Wrap(
                                                                        spacing: 16 * scaleInner,
                                                                        runSpacing: 12 * scaleInner,
                                                                        children: juridicaPlans.isNotEmpty
                                                                            ? juridicaPlans.map((p) {
                                                                                return SizedBox(width: planCardWidth - 16, child: _elegantPlanCard(p, p.id == activePlanId, scaleInner, cm));
                                                                              }).toList()
                                                                            : [
                                                                                SizedBox(
                                                                                  width: planCardWidth - 16,
                                                                                  child: Container(
                                                                                    padding: EdgeInsets.all(16 * scaleInner),
                                                                                    decoration: BoxDecoration(
                                                                                      color: cm.card.withOpacity(0.02),
                                                                                      borderRadius: BorderRadius.circular(12),
                                                                                      border: Border.all(color: cm.card.withOpacity(0.06)),
                                                                                    ),
                                                                                    child: Text('Nenhum plano Enterprise encontrado para Pessoa Jurídica.', style: TextStyle(color: cm.explicitText.withOpacity(0.8))),
                                                                                  ),
                                                                                )
                                                                              ],
                                                                      );
                                                                    },
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    else
                                                      const SizedBox.shrink(),

                                                    SizedBox(height: 18 * scaleInner),

                                                    if (isLinkedToSubscription) ...[
                                                      const SizedBox(height: 6),
                                                      _subscriptionSummaryCard(
                                                        myPlanFromList ?? Plan(
                                                          id: activePlanId ?? 0,
                                                          nome: activePlanName,
                                                          precoMensal: 0,
                                                          quantidadeCreditoMensal: 0,
                                                          prioridade: 0,
                                                          maximoColaboradores: 0,
                                                        ),
                                                        cm,
                                                        scaleInner,
                                                      ),
                                                    ],

                                                    SizedBox(height: 8),
                                                    AnimatedSwitcher(
                                                      duration: const Duration(milliseconds: 300),
                                                      child: loading ? LinearProgressIndicator(color: cm.primary) : const SizedBox.shrink(),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

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
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _subscriptionSummaryCard(Plan p, ColorManager cm, double scale) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: cm.card.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cm.card.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: cm.ok, size: 18 * scale),
                SizedBox(width: 8 * scale),
                Text(
                  p.nome,
                  style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w900, color: cm.explicitText),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                  decoration: BoxDecoration(color: cm.ok, borderRadius: BorderRadius.circular(10)),
                  child: Text('Assinatura atual', style: TextStyle(color: cm.text, fontSize: 12 * scale)),
                ),
              ],
            ),
            SizedBox(height: 12 * scale),
            _featureRow(Icons.check, 'Créditos/mês: ${p.quantidadeCreditoMensal}', scale, cm),
            _featureRow(Icons.check, 'Prioridade: ${p.prioridade}', scale, cm),
            _featureRow(Icons.check, 'ID do plano: ${p.id}', scale, cm),
            // show max collaborators if enterprise
            if (_isEnterprisePlanName(p.nome))
              _featureRow(Icons.group, 'Máx. colaboradores: ${p.maximoColaboradores == 0 ? "Ilimitado" : p.maximoColaboradores}', scale, cm),
            SizedBox(height: 12 * scale),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: cancelling ? null : _cancelSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: cm.text,
                      padding: EdgeInsets.symmetric(vertical: 12 * scale),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: cancelling
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cm.text))
                        : const Text('Cancelar assinatura'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * scale),
            Text(
              activeStripeSubscriptionId != null
                  ? 'Subscription: ${activeStripeSubscriptionId}'
                  : (activeAssinaturaId != null ? 'Assinatura local ID: ${activeAssinaturaId}' : ''),
              style: TextStyle(fontSize: 12 * scale, color: cm.explicitText.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _elegantPlanCard(Plan p, bool isActive, double scale, ColorManager cm) {
    return _HoverCard(
      onTap: () async {
        if (p.id == activePlanId) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Já é seu plano')));
          return;
        }
        await _confirmAndSubscribe(p);
      },
      child: Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: [cm.ok.withOpacity(0.14), cm.card.withOpacity(0.04)])
              : LinearGradient(colors: [cm.card.withOpacity(0.03), cm.card.withOpacity(0.01)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? cm.ok.withOpacity(0.28) : cm.card.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: cm.card.withOpacity(isActive ? 0.06 : 0.02), blurRadius: isActive ? 18 : 8, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(isActive ? Icons.star : Icons.star_border, color: isActive ? cm.ok : cm.primary, size: 18 * scale),
                SizedBox(width: 10 * scale),
                Text(p.nome, style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w900, color: isActive ? cm.ok : cm.explicitText)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(p.precoMensal <= 0 ? 'R\$0/mês' : _fmtCurrency(p.precoMensal), style: TextStyle(fontWeight: FontWeight.w700, color: cm.explicitText.withOpacity(0.75), fontSize: 13 * scale)),
                    SizedBox(height: 6 * scale),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
                      decoration: BoxDecoration(
                        color: isActive ? cm.ok.withOpacity(0.14) : cm.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isActive ? cm.ok.withOpacity(0.22) : cm.primary.withOpacity(0.12)),
                      ),
                      child: Text(
                        p.quantidadeCreditoMensal > 0 ? '${p.quantidadeCreditoMensal} créditos/mês' : 'Sem créditos mensais',
                        style: TextStyle(fontSize: 11 * scale, color: cm.explicitText.withOpacity(0.75)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12 * scale),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _featureRow(Icons.check, 'Créditos/mês: ${p.quantidadeCreditoMensal}', scale, cm),
              _featureRow(Icons.check, 'Prioridade: ${p.prioridade}', scale, cm),
              _featureRow(Icons.check, 'ID do plano: ${p.id}', scale, cm),
              // show max collaborators only for juridica (enterprise) plans
              if (_isEnterprisePlanName(p.nome))
                _featureRow(Icons.group, 'Máx. colaboradores: ${p.maximoColaboradores == 0 ? "Ilimitado" : p.maximoColaboradores}', scale, cm),
            ]),
            SizedBox(height: 12 * scale),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: p.id == activePlanId ? null : () async => await _confirmAndSubscribe(p),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.id == activePlanId ? cm.explicitText.withOpacity(0.85) : cm.primary,
                  foregroundColor: cm.text,
                  padding: EdgeInsets.symmetric(vertical: 12 * scale),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w800),
                ),
                child: changingPlan ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cm.text)) : Text(p.id == activePlanId ? 'Seu plano' : 'Assinar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text, double scale, ColorManager cm) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      child: Row(
        children: [
          Icon(icon, size: 16 * scale, color: cm.primary),
          SizedBox(width: 10 * scale),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13 * scale, color: cm.explicitText.withOpacity(0.9)))),
        ],
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _HoverCard({required this.child, this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final transform = hovered ? (pressed ? 0.985 : 1.012) : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapUp: (_) => setState(() => pressed = false),
        onTapCancel: () => setState(() => pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(duration: const Duration(milliseconds: 180), transform: Matrix4.identity()..scale(transform, transform), child: widget.child),
      ),
    );
  }
}

class _EmailsListDialog extends StatefulWidget {
  final int maxEmails; // 0 means unlimited

  const _EmailsListDialog({Key? key, required this.maxEmails}) : super(key: key);

  @override
  State<_EmailsListDialog> createState() => _EmailsListDialogState();
}

class _EmailsListDialogState extends State<_EmailsListDialog> {
  final List<TextEditingController> _controllers = [];
  final List<String?> _errors = [];
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // start with one field (unless max is explicitly 0 meaning unlimited -> still start with one)
    _addItem();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _addItem() {
    // if not unlimited and we've reached the limit, don't allow adding
    if (widget.maxEmails > 0 && _controllers.length >= widget.maxEmails) return;

    setState(() {
      final c = TextEditingController();
      _controllers.add(c);
      _errors.add(null);
      c.addListener(() {
        final idx = _controllers.indexOf(c);
        if (idx != -1) _validateAt(idx);
        setState(() {}); // update counters dynamically
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _removeAt(int i) {
    if (i < 0 || i >= _controllers.length) return;
    setState(() {
      _controllers[i].dispose();
      _controllers.removeAt(i);
      _errors.removeAt(i);
    });
  }

  bool _isValidEmail(String e) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(e);
  }

  void _validateAt(int i) {
    final txt = _controllers[i].text.trim();
    setState(() {
      if (txt.isEmpty) {
        _errors[i] = null;
      } else if (!_isValidEmail(txt)) {
        _errors[i] = 'Email inválido';
      } else {
        _errors[i] = null;
      }
    });
  }

  bool get _anyInvalid => _errors.any((e) => e != null);

  List<String> get _validEmails => _controllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty && _isValidEmail(s)).toList();

  bool get _exceedsMax {
    if (widget.maxEmails == 0) return false; // unlimited
    return _validEmails.length > widget.maxEmails;
  }

  bool get _canAddMore {
    if (widget.maxEmails == 0) return true; // unlimited
    return _controllers.length < widget.maxEmails;
  }

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;
    final unlimited = widget.maxEmails == 0;
    final currentValid = _validEmails.length;
    final allowedText = unlimited ? 'Ilimitado' : widget.maxEmails.toString();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cm.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.group_add, color: cm.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vincular emails (Enterprise)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cm.explicitText)),
                  const SizedBox(height: 4),
                  Text('Adicione os emails que deseja vincular — cada item fica empilhado abaixo. Use Adicionar para criar um novo e o ícone de lixeira para remover.', style: TextStyle(fontSize: 13, color: cm.explicitText.withOpacity(0.7))),
                ]),
              ),
              IconButton(onPressed: () => Navigator.of(context).pop(null), icon: Icon(Icons.close, color: cm.explicitText.withOpacity(0.6))),
            ]),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Limite de colaboradores: ', style: TextStyle(fontSize: 13, color: cm.explicitText.withOpacity(0.8))),
                Text(allowedText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cm.primary)),
                const SizedBox(width: 12),
                Text('Emails válidos: ', style: TextStyle(fontSize: 13, color: cm.explicitText.withOpacity(0.7))),
                Text('$currentValid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cm.ok)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cm.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: cm.card.withOpacity(0.08))),
                child: Scrollbar(
                  controller: _scroll,
                  radius: const Radius.circular(8),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    itemCount: _controllers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final ctrl = _controllers[i];
                      final err = _errors[i];
                      return Material(
                        color: cm.card.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: ctrl,
                                decoration: InputDecoration(
                                  labelText: 'Email ${i + 1}',
                                  hintText: 'usuario@empresa.com',
                                  errorText: err,
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.alternate_email),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(onPressed: () => _removeAt(i), icon: Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: 'Remover'),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _canAddMore ? _addItem : null,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container()),
              TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_anyInvalid || _exceedsMax) ? null : () {
                  final emails = _validEmails;
                  Navigator.of(context).pop(emails);
                },
                child: const Text('Confirmar'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ]),
            if (_exceedsMax)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Número de emails válidos excede o limite permitido.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
          ]),
        ),
      ),
    );
  }
}

class Plan {
  final int id;
  final String nome;
  final double precoMensal;
  final int quantidadeCreditoMensal;
  final int prioridade;
  final int maximoColaboradores; // 0 -> ilimitado

  Plan({
    required this.id,
    required this.nome,
    required this.precoMensal,
    required this.quantidadeCreditoMensal,
    required this.prioridade,
    required this.maximoColaboradores,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    double parsedPreco = 0;
    final precoRaw = json['preco_mensal'] ?? json['precoMensal'] ?? json['preco'];
    if (precoRaw != null) {
      if (precoRaw is num)
        parsedPreco = precoRaw.toDouble();
      else
        parsedPreco = double.tryParse(precoRaw.toString().replaceAll(',', '.')) ?? 0;
    }

    // parse maximo_colaboradores (accept both snake_case and camelCase)
    int parsedMax = 0;
    final rawMax = json['maximo_colaboradores'] ?? json['maximoColaboradores'] ?? json['max_colaboradores'] ?? json['maximo'];
    if (rawMax != null) {
      if (rawMax is int) parsedMax = rawMax;
      else {
        parsedMax = int.tryParse(rawMax.toString()) ?? 0;
      }
    }

    return Plan(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      nome: json['nome'] ?? 'Plano',
      precoMensal: parsedPreco,
      quantidadeCreditoMensal: json['quantidade_credito_mensal'] is int
          ? json['quantidade_credito_mensal']
          : int.tryParse((json['quantidade_credito_mensal'] ?? '0').toString()) ?? 0,
      prioridade: json['prioridade_de_tempo'] is int
          ? json['prioridade_de_tempo']
          : int.tryParse((json['prioridade_de_tempo'] ?? '0').toString()) ?? 0,
      maximoColaboradores: parsedMax,
    );
  }
}
