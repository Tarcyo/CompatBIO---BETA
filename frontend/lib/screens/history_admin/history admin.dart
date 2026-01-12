// FILE: lib/screens/solicitacoes_todas_screen_responsive.dart
// Versão responsiva e com header no estilo 'ChemicalCardHeader'.
// Mantive 100% das funcionalidades e lógica original.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/history_admin/detalle_model.dart';
import 'package:planos/screens/history_admin/soicitacao.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// import do banner de dica de scroll (mantido)
import 'package:planos/utils/scroll_hint_banner.dart';

/// ChemicalCardHeader (copiado/adaptado da tela anterior)
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

/// Tela principal (mantida lógica original; UI atualizada).
class SolicitacoesTodasScreen extends StatefulWidget {
  const SolicitacoesTodasScreen({Key? key}) : super(key: key);

  @override
  State<SolicitacoesTodasScreen> createState() =>
      _SolicitacoesTodasScreenState();
}

class _SolicitacoesTodasScreenState extends State<SolicitacoesTodasScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;

  Map<int, List<Solicitacao>> _originais = {};
  List<Solicitacao> _flat = [];
  List<Solicitacao> _filtradas = [];

  final String _url = '${dotenv.env['BASE_URL']}/solicitacoes/todas';
  final TextEditingController _searchController = TextEditingController();

  int? _filterPrioridade;
  String? _filterStatus; // null = todos, 'andamento', 'concluido'

  late final AnimationController _anim;
  late final Animation<double> _scale;

  // scroll controller used by the whole card
  final ScrollController _cardScrollController = ScrollController();

  // --- ADIÇÕES relacionadas ao banner ---
  bool _bannerDismissed = false;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);

    _cardScrollController.addListener(_onCardScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSolicitacoes();
      _anim.forward();
      _evaluateScrollable();
    });
  }

  void _onCardScroll() {
    if (!_bannerDismissed && _cardScrollController.hasClients) {
      if (_cardScrollController.position.pixels > 5) {
        setState(() => _bannerDismissed = true);
      }
    }
  }

  void _evaluateScrollable() {
    if (!_cardScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 60), _evaluateScrollable);
      return;
    }
    final maxExtent = _cardScrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      if (mounted) {
        setState(() {
          _showBanner = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _showBanner = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cardScrollController.removeListener(_onCardScroll);
    _cardScrollController.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading && _originais.isEmpty && _error == null) _fetchSolicitacoes();
  }

  Future<void> _fetchSolicitacoes() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Usuário não autenticado. Token ausente.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(response.body);
        final Map<int, List<Solicitacao>> agrupadas = {};
        parsed.forEach((key, value) {
          final prioridade = int.tryParse(key) ?? 0;
          if (value is List) {
            agrupadas[prioridade] = value.map((e) => Solicitacao.fromJson(e)).toList();
          } else {
            agrupadas[prioridade] = [];
          }
        });

        final sorted = Map.fromEntries(
          agrupadas.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
        );

        setState(() {
          _originais = sorted;
          _flat = _originais.values.expand((e) => e).toList();
          _filtradas = List.of(_flat);
          if (_filterPrioridade != null && !_originais.containsKey(_filterPrioridade)) {
            _filterPrioridade = null;
          }
          _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateScrollable());
      } else {
        setState(() {
          _error = 'Erro na requisição (código ${response.statusCode}).';
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Erro ao buscar solicitações: $e\n$st');
      setState(() {
        _error = 'Erro de rede ou servidor: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtradas = _flat.where((s) {
        if (_filterPrioridade != null && s.prioridade != _filterPrioridade) return false;

        final isConcluido = (s.status ?? '').toLowerCase() == 'finalizado' ||
            (s.resultadoFinal ?? '').trim().isNotEmpty;
        final isAndamento = !isConcluido;

        if (_filterStatus == 'andamento' && !isAndamento) return false;
        if (_filterStatus == 'concluido' && !isConcluido) return false;

        final a = s.nomeProdutoQuimico.toLowerCase();
        final b = s.nomeProdutoBiologico.toLowerCase();
        if (q.isEmpty) return true;
        return a.contains(q) || b.contains(q);
      }).toList();
    });
  }

  String _normalize(String? s) {
    if (s == null) return '';
    var str = s.toLowerCase();
    str = str.replaceAll(RegExp('[áàãâä]'), 'a');
    str = str.replaceAll(RegExp('[éèêẽ]'), 'e');
    str = str.replaceAll(RegExp('[íìî]'), 'i');
    str = str.replaceAll(RegExp('[óòôõ]'), 'o');
    str = str.replaceAll(RegExp('[úùû]'), 'u');
    str = str.replaceAll('ç', 'c');
    return str;
  }

  Color _badgeSolidColorForStatus(String? status) {
    final n = _normalize(status);
    final cm = ColorManager.instance;
    if (n.contains('incomp')) return cm.emergency;
    if (n.contains('compat')) return cm.ok;
    if (n.contains('parc')) return cm.alert;
    return cm.emergency;
  }

  Future<void> _showDetalheSheet(Solicitacao s) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorManager.instance.background,
      builder: (_) => DetalleModal(
        s: s,
        onVinculado: (resultado, descricao) async {
          final ok = await _vincularResultado(s, resultado, descricao);
          return ok;
        },
      ),
    );

    if (result == true) {
      _flat = _originais.values.expand((e) => e).toList();
      _applyFilters();
    }
  }

  Future<bool> _vincularResultado(
    Solicitacao s,
    String resultado,
    String descricao,
  ) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.token;
    if (token == null || token.isEmpty) return false;

    final url = Uri.parse(
      '${dotenv.env['BASE_URL']}/solicitacoes/${s.id}/vincular',
    );
    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'resultado_final': resultado,
          'descricao_resultado': descricao,
        }),
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        final updated = s.copyWith(
          resultadoFinal: resultado,
          status: 'finalizado',
          rawData: {
            ...s.rawData,
            'resultado_final': resultado,
            'descricao_resultado': descricao,
            'status': 'finalizado',
          },
        );

        final novos = <int, List<Solicitacao>>{};
        _originais.forEach((p, lista) {
          novos[p] = lista.map((it) => it.id == s.id ? updated : it).toList();
        });

        setState(() {
          _originais = Map.fromEntries(
            novos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
          );
          _flat = _originais.values.expand((e) => e).toList();
          if (_filterPrioridade != null && !_originais.containsKey(_filterPrioridade)) {
            _filterPrioridade = null;
          }
          _applyFilters();
        });

        return true;
      } else {
        debugPrint('Vincular falhou: ${resp.statusCode} ${resp.body}');
        return false;
      }
    } catch (e, st) {
      debugPrint('Erro ao vincular resultado: $e\n$st');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final vw = mq.size.width;
    final vh = mq.size.height;
    final scale = vw > 1400 ? 1.12 : (vw > 1000 ? 1.04 : 1.0);
    final isWide = vw >= 900;
    final isMobile = vw < 700;

    final cm = ColorManager.instance;

    final softCardColor = cm.card.withOpacity(0.12);
    final softCardBorder = BorderSide(
      color: cm.card.withOpacity(0.6),
      width: 1.6,
    );

    final bg = cm.background;
 //   final accent = cm.primary;

    final contentPadding = EdgeInsets.symmetric(
      horizontal: (isMobile ? 8 : 20) * scale,
      vertical: (isMobile ? 10 : 18) * scale,
    );

    // trailing header widget: mostra contagem + botão de refresh
    Widget headerTrailing(double uiScale) {
     // final showing = _filtradas.length;
      //final label = showing > 999 ? '999+' : showing.toString();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // small pills showing count
      
          Material(
            color: Colors.transparent,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _fetchSolicitacoes,
              tooltip: 'Recarregar solicitações',
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cm.background,
        foregroundColor: cm.explicitText.withOpacity(0.87),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1200 : vw - 24,
                maxHeight: vh - 80,
                minWidth: 300,
              ),
              child: Padding(
                padding: contentPadding,
                child: Stack(
                  children: [
                    Card(
                      color: softCardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14 * scale),
                        side: softCardBorder,
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      child: RefreshIndicator(
                        onRefresh: _fetchSolicitacoes,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.maxScrollExtent > 0) {
                              if (!_showBanner && !_bannerDismissed) {
                                setState(() {
                                  _showBanner = true;
                                });
                              }
                            } else {
                              if (_showBanner) {
                                setState(() {
                                  _showBanner = false;
                                });
                              }
                            }
                            return false;
                          },
                          child: SingleChildScrollView(
                            controller: _cardScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header no estilo ChemicalCardHeader
                                ChemicalCardHeader(
                                  title: 'Solicitações',
                                  leadingIcon: Icons.science_rounded,
                                  primary: cm.primary,
                                  borderRadius: 14 * scale,
                                  verticalPadding: 14 * scale,
                                  horizontalPadding: 16 * scale,
                                  scale: (isMobile ? 1.0 : 1.02) * scale,
                                  trailing: Padding(
                                    padding: EdgeInsets.only(right: 8.0 * scale),
                                    child: headerTrailing((isMobile ? 0.88 : 1.0) * scale),
                                  ),
                                ),

                                // Conteúdo interno (mantive sua estrutura, só adaptei espaçamentos)
                                Padding(
                                  padding: EdgeInsets.all((isMobile ? 10 : 16) * scale),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(height: isMobile ? 6 : 10),
                                      // area principal: filtros + lista
                                      if (isWide)
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Flexible(flex: 3, child: _buildListColumn(isMobile)),
                                            SizedBox(width: 12 * scale),
                                            Flexible(
                                              flex: 2,
                                              child: ThinCard(
                                                padding: EdgeInsets.all(12 * scale),
                                                child: SingleChildScrollView(
                                                  child: _buildFiltersContent(scale, isMobile: false),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Column(
                                          children: [
                                            _mobileFiltersTile(scale),
                                            const SizedBox(height: 10),
                                            _buildListColumn(isMobile),
                                          ],
                                        ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Banner de dica de scroll — posicionado sobre toda a tela;
                    if (_showBanner && !_bannerDismissed)
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
          ),
        ),
      ),
   
    );
  }

  Widget _buildListColumn(bool isMobile) {
    final mainBg = ColorManager.instance.card.withOpacity(0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThinCard(
          child: Row(
            children: [
              const Expanded(
                flex: 4,
                child: Text(
                  'Produtos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Expanded(
                flex: 4,
                child: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Resultado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: mainBg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: _loading && _originais.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _originais.isEmpty
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: ColorManager.instance.emergency),
                      ),
                    )
                  : Column(
                      children: [
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: _filtradas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final s = _filtradas[idx];
                            final stripeColor = _badgeSolidColorForStatus(
                              s.resultadoFinal ?? s.status,
                            );
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showDetalheSheet(s),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 72),
                                decoration: BoxDecoration(
                                  color: ColorManager.instance.background,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 6,
                                        decoration: BoxDecoration(
                                          color: stripeColor,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: ColorManager.instance.background,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.02),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.science_rounded,
                                                color: ColorManager.instance.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 4,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        s.nomeProdutoQuimico,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          color: ColorManager.instance.explicitText,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: ColorManager.instance.background.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.flag_rounded,
                                                            size: 12,
                                                            color: ColorManager.instance.explicitText.withOpacity(0.7),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'P${s.prioridade}',
                                                            style: TextStyle(
                                                              color: ColorManager.instance.explicitText.withOpacity(0.7),
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  s.nomeProdutoBiologico,
                                                  style: TextStyle(
                                                    color: ColorManager.instance.explicitText.withOpacity(0.7),
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                       
                                         
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                 ] )         
        ),
      ],
    );
  }

  Widget _buildFiltersContent(double scale, {required bool isMobile}) {
    final cm = ColorManager.instance;
    final grayText = TextStyle(color: cm.explicitText.withOpacity(0.7));
    final andamentoLabel = isMobile ? 'a fazer' : 'Em andamento';

    final List<DropdownMenuItem<int?>> prioridadeItems = [];

    prioridadeItems.add(
      DropdownMenuItem<int?>(
        value: null,
        child: Row(
          children: [
            const Icon(Icons.stacked_bar_chart_rounded, size: 16),
            const SizedBox(width: 8),
            Text(
              'Prioridade',
              style: TextStyle(color: cm.explicitText.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );

    if (_originais.isNotEmpty) {
      final sortedPriorities = _originais.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final p in sortedPriorities) {
        prioridadeItems.add(
          DropdownMenuItem<int?>(
            value: p,
            child: Row(
              children: [
                const Icon(Icons.flag_rounded, size: 16),
                const SizedBox(width: 8),
                Text(
                  '$p',
                  style: TextStyle(color: cm.explicitText.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Filtrar e Buscar',
                style: TextStyle(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w800,
                  color: cm.explicitText,
                ),
              ),
            ),
            Icon(Icons.tune_rounded, color: cm.explicitText.withOpacity(0.7)),
          ],
        ),
        SizedBox(height: 8 * scale),
        Container(
          decoration: BoxDecoration(
            color: cm.background.withOpacity(0.98),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: cm.primary),
              hintText: 'Filtrar por químico ou biológico',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10 * scale),
            ),
          ),
        ),
        SizedBox(height: 10 * scale),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: cm.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String?>(

                  value: _filterStatus,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: Colors.white,
                  hint: Text(
                    'Status',
                    style: TextStyle(color: cm.explicitText.withOpacity(0.7)),
                  ),
                  style: grayText,
                  items: <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Row(
                        children: [
                          const Icon(Icons.list_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Todos',
                            style: TextStyle(
                              color: cm.explicitText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'andamento',
                      child: Row(
                        children: [
                          const Icon(Icons.loop_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            andamentoLabel,
                            style: TextStyle(
                              color: cm.explicitText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'concluido',
                      child: Row(
                        children: [
                          const Icon(Icons.check_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Concluído',
                            style: TextStyle(
                              color: cm.explicitText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _filterStatus = v);
                    _applyFilters();
                  },
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: cm.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int?>(
                  value: _filterPrioridade,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: cm.background,
                  hint: Text(
                    'Prioridade',
                    style: TextStyle(color: cm.explicitText.withOpacity(0.7)),
                  ),
                  style: grayText,
                  items: prioridadeItems,
                  onChanged: (v) {
                    setState(() => _filterPrioridade = v);
                    _applyFilters();
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * scale),
        OutlinedButton.icon(
          onPressed: _fetchSolicitacoes,
          icon: Icon(
            Icons.refresh_rounded,
            color: cm.explicitText.withOpacity(0.87),
          ),
          label: Text(
            'Atualizar',
            style: TextStyle(color: cm.explicitText.withOpacity(0.87)),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12 * scale),
          ),
        ),
       
      ],
    );
  }

  Widget _mobileFiltersTile(double scale) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: ColorManager.instance.background,
        child: ExpansionTile(
          title: const Text('Filtros e busca'),
          leading: const Icon(Icons.tune_rounded),
          childrenPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _buildFiltersContent(scale, isMobile: true),
          ],
        ),
      ),
    );
  }
}

/// Badge que exibe resultado com cor sólida (mesma lógica visual do original)
class ResultBadge extends StatelessWidget {
  final String? result;
  const ResultBadge({Key? key, this.result}) : super(key: key);

  String _normalize(String? s) {
    if (s == null) return '';
    var str = s.toLowerCase();
    str = str.replaceAll(RegExp('[áàãâä]'), 'a');
    str = str.replaceAll(RegExp('[éèêẽ]'), 'e');
    str = str.replaceAll(RegExp('[íìî]'), 'i');
    str = str.replaceAll(RegExp('[óòôõ]'), 'o');
    str = str.replaceAll(RegExp('[úùû]'), 'u');
    str = str.replaceAll('ç', 'c');
    return str;
  }

  Color _badgeSolidColorForStatus(String? status) {
    final n = _normalize(status);
    final cm = ColorManager.instance;
    if (n.contains('incomp')) return cm.emergency;
    if (n.contains('compat')) return cm.ok;
    if (n.contains('parc')) return cm.alert;
    return cm.emergency;
  }

  @override
  Widget build(BuildContext context) {
    final r = result ?? '';
    final n = _normalize(r);
    final solid = _badgeSolidColorForStatus(result);
    String label;
    IconData icon;

    if (n.contains('incomp')) {
      label = 'Incompatível';
      icon = Icons.cancel_rounded;
    } else if (n.contains('compat')) {
      label = 'Compatível';
      icon = Icons.check_circle_rounded;
    } else if (n.contains('parc')) {
      label = 'Parcial';
      icon = Icons.remove_circle_rounded;
    } else {
      label = r.isNotEmpty ? r : 'Incompatível';
      icon = n.contains('parc') ? Icons.remove_circle_rounded : Icons.cancel_rounded;
    }

    const double iconSize = 12;
    const double fontSize = 12;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: solid,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: ColorManager.instance.text),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: ColorManager.instance.text,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// ThinCard: wrapper de aparência reutilizável usado em diversos lugares
class ThinCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const ThinCard({Key? key, required this.child, this.padding}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorManager.instance.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
