// lib/screens/resultadosAdmin/resultados_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/resultadosAdmin/crate_result.dart';
import 'package:planos/screens/resultadosAdmin/header_row.dart';
import 'package:planos/screens/resultadosAdmin/product_simple.dart';
import 'package:planos/screens/resultadosAdmin/result_utils.dart';
import 'package:planos/screens/resultadosAdmin/resultadoItem.dart';
import 'package:planos/screens/resultadosAdmin/resultados_list.dart';
import 'package:planos/screens/resultadosAdmin/searchFiles.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ResultadosScreen extends StatefulWidget {
  const ResultadosScreen({Key? key}) : super(key: key);

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen>
    with SingleTickerProviderStateMixin {
  final String _urlResultados = '${dotenv.env['BASE_URL']}/resultados';
  final String _urlProdutos = '${dotenv.env['BASE_URL']}/produtos';

  bool _loading = false;
  String? _error;

  List<ResultadoItem> _itens = [];
  List<ResultadoItem> _filtrados = [];

  List<ProdutoSimple> _biologicos = [];
  List<ProdutoSimple> _quimicos = [];

  final TextEditingController _searchController = TextEditingController();
  final ResultadosFilter _filter = ResultadosFilter();

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  bool _showScrollHint = true;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.user?.token;
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchProdutos(), _fetchResultados()]);
  }

  Future<void> _fetchProdutos() async {
    final token = await _getTokenFromProvider();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Usuário não autenticado. Token ausente.');
      return;
    }

    try {
      final resp = await http.get(
        Uri.parse(_urlProdutos),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(resp.body);
        final List<ProdutoSimple> bios = [];
        final List<ProdutoSimple> quims = [];

        if (parsed['produtos_biologicos'] is Map) {
          final Map biologicos = parsed['produtos_biologicos'];
          biologicos.forEach((tipo, nomes) {
            if (nomes is List) {
              for (var n in nomes) {
                final nome = n?.toString() ?? '';
                bios.add(
                  ProdutoSimple(
                    nome: nome,
                    tipo: tipo?.toString() ?? 'não_informado',
                  ),
                );
              }
            }
          });
        }
        if (parsed['produtos_quimicos'] is Map) {
          final Map quimicos = parsed['produtos_quimicos'];
          quimicos.forEach((tipo, nomes) {
            if (nomes is List) {
              for (var n in nomes) {
                final nome = n?.toString() ?? '';
                quims.add(
                  ProdutoSimple(
                    nome: nome,
                    tipo: tipo?.toString() ?? 'não_informado',
                  ),
                );
              }
            }
          });
        }

        final uniqB = {for (var p in bios) p.nome: p}.values.toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
        final uniqQ = {for (var p in quims) p.nome: p}.values.toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));

        if (!mounted) return;
        setState(() {
          _biologicos = uniqB;
          _quimicos = uniqQ;
        });
      } else {
        debugPrint('Falha ao buscar produtos: ${resp.statusCode} ${resp.body}');
      }
    } catch (e, st) {
      debugPrint('Erro ao buscar produtos: $e\n$st');
    }
  }

  Future<void> _fetchResultados() async {
    final token = await _getTokenFromProvider();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Usuário não autenticado. Token ausente.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await http.get(
        Uri.parse(_urlResultados),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final List parsed = json.decode(resp.body) as List;
        final itens = parsed
            .map((e) => ResultadoItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() {
          _itens = itens;
          _filtrados = List.of(_itens);
          _loading = false;
        });
        _applyFilters();
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        if (!mounted) return;
        setState(() {
          _error = 'Acesso negado: verifique suas permissões (admin required).';
          _loading = false;
        });
      } else {
        final message = resp.body;
        if (!mounted) return;
        setState(() {
          _error = 'Erro ${resp.statusCode}: $message';
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Erro ao buscar resultados: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'Erro de rede/servidor: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    if (!mounted) return;
    setState(() {
      _filtrados = _itens.where((r) {
        if (_filter.resultadoFinal != null &&
            _filter.resultadoFinal!.isNotEmpty) {
          final rf = (r.resultadoFinal ?? '').toLowerCase();
          if (!matchResultadoFinal(rf, _filter.resultadoFinal!)) return false;
        }
        if (q.isEmpty) return true;
        return r.nomeBiologico.toLowerCase().contains(q) ||
            r.nomeQuimico.toLowerCase().contains(q) ||
            (r.descricao ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await copyToClipboardAndNotify(context, text, label);
  }

  Future<bool?> _openCreate() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateResultadoSheet(biologicos: _biologicos, quimicos: _quimicos),
    );
  }

  void _handleItemUpdated(ResultadoItem updated) {
    if (!mounted) return;
    setState(() {
      final idx = _itens.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        _itens[idx] = updated;
      } else {
        _itens.insert(0, updated);
      }
      _applyFilters();
    });
  }

  void _handleItemDeletedById(int id) {
    if (!mounted) return;
    setState(() {
      _itens.removeWhere((e) => e.id == id);
      _applyFilters();
    });
  }

  void _dismissBanner() {
    if (!mounted) return;
    setState(() {
      _bannerDismissed = true;
      _showScrollHint = false;
    });
  }

  Widget _buildScrollBanner(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final visible = _showScrollHint && !_bannerDismissed;

    return Positioned(
      bottom: size.height * 0.03,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Semantics(
            label: 'Dica: deslize para ver mais conteúdo',
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;

    final cardMaxWidth = isMobile ? double.infinity : 880.0;
    final cardPadding = isMobile ? 12.0 : 18.0;
    final radius = BorderRadius.circular(isMobile ? 12.0 : 18.0);

    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

      

        // Painel principal: Container decorado (não Card) e HeaderRow é o primeiro filho,
        // portanto o header faz parte do painel/card (não flutuante).
        final panel = Container(
          decoration: BoxDecoration(
            color: cm.card.withOpacity(0.12),
            borderRadius: radius,
            border: Border.all(color: cm.card.withOpacity(0.6), width: 1.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER: integrado ao painel — HeaderRow retorna ChemicalCardHeader
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 12.0 : 18.0)),
                child: HeaderRow(isMobile: isMobile, onRefresh: _openCreate),
              ),

              // Conteúdo do painel dentro de Padding separado para ficar visualmente harmonioso
              Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: isMobile ? 12 : 8),
                    SearchFilter(
                      isMobile: isMobile,
                      searchController: _searchController,
                      filter: _filter,
                      onApplyFilters: _applyFilters,
                      biologicos: _biologicos,
                      quimicos: _quimicos,
                    ),
                    const SizedBox(height: 12),
                    // ResultadosList agora não controla scroll — é não-rolável (shrinkWrap).
                    ResultadosList(
                      isMobile: isMobile,
                      loading: _loading,
                      error: _error,
                      items: _itens,
                      filtrados: _filtrados,
                      onRefresh: _fetchResultados,
                      copyCallback: (t, l) => _copyToClipboard(t, l),
                      onItemUpdated: (updated) => _handleItemUpdated(updated),
                      onItemDeleted: (id) => _handleItemDeletedById(id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // Tela: único ScrollView no nível superior com RefreshIndicator
        Widget bodyContent = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: panel,
            ),
          ),
        );

        bodyContent = RefreshIndicator(
          onRefresh: _fetchResultados,
          color: cm.primary,
          backgroundColor: cm.background,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: 80),
            child: SizedBox(
              width: double.infinity,
              child: bodyContent,
            ),
          ),
        );

        if (isMobile) {
          return Scaffold(
            backgroundColor: cm.background,
            body: SafeArea(
              child: Stack(
                children: [
                  bodyContent,
                  if (_showScrollHint && !_bannerDismissed)
                    _buildScrollBanner(context),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: cm.background,
          body: SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Stack(
                  children: [
                    bodyContent,
                    if (_showScrollHint && !_bannerDismissed) _buildScrollBanner(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
