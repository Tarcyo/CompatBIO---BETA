// FILE: lib/screens/adminProduto/produtos_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/adminProduto/createProdutoSheet.dart';
import 'package:planos/screens/adminProduto/create_produto_dialog.dart';
import 'package:planos/screens/adminProduto/produtoItem.dart';
import 'package:planos/screens/adminProduto/produtoService.dart';
import 'package:planos/screens/adminProduto/produto_list.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import do header gradiente reutilizável
import 'package:planos/screens/resultadosAdmin/header_row.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({Key? key}) : super(key: key);

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen>
    with SingleTickerProviderStateMixin {
  final ProdutosService _service = ProdutosService();
  bool _loading = false;
  String? _error;

 // final Object _fabHeroTag = UniqueKey();
  List<ProdutoItem> _all = [];
  List<ProdutoItem> _filtered = [];

  final TextEditingController _searchController = TextEditingController();
  ProdutoCategoria _filterCategoria = ProdutoCategoria.todos;
  String? _filterTipo;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  // Usamos esse controller como scroll principal da tela (antes era só da lista)
  final ScrollController _pageController = ScrollController();
  bool _showScrollHint = true;
  bool _bannerDismissed = false;

  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProdutos();
      _animController.forward();
    });

    // Listener no controller principal (top-level) para esconder banner quando rolar
    _pageController.addListener(() {
      if (!_pageController.hasClients) return;
      if (_pageController.position.pixels > 24 && _showScrollHint) {
        if (mounted) setState(() => _showScrollHint = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchProdutos() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Usuário não autenticado.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _service.fetchProdutos(token);
      setState(() {
        _all = list;
        _filtered = List.of(_all);
        _filterTipo = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        if (_filterCategoria == ProdutoCategoria.biologico &&
            p.categoria != ProdutoCategoria.biologico) return false;
        if (_filterCategoria == ProdutoCategoria.quimico &&
            p.categoria != ProdutoCategoria.quimico) return false;
        if (_filterTipo != null && _filterTipo!.isNotEmpty && p.tipo != _filterTipo) return false;
        if (q.isEmpty) return true;
        return p.nome.toLowerCase().contains(q) || p.tipo.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _openCreateSheetOrDialog() async {
    final vw = MediaQuery.of(context).size.width;
    final isDesktop = vw >= 900;

    if (isDesktop) {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: const CreateProdutoDialog(),
          ),
        ),
      );

      if (created == true) {
        await _fetchProdutos();
        _applyFilters();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto criado')));
        }
      }
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateProdutoSheet(),
    );

    if (created == true) {
      await _fetchProdutos();
      _applyFilters();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto criado')));
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copiado')));
    }
  }

  // ---------- Editar produto (chama backend PUT) ----------
  Future<void> _editProduto(ProdutoItem p) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }

    final TextEditingController tipoController = TextEditingController(text: p.tipo);
    final TextEditingController nomeController = TextEditingController(text: p.nome);
    bool newDemo = p.demo;

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) {
          return AlertDialog(
            title: const Text('Editar produto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 8),
                TextFormField(controller: tipoController, decoration: const InputDecoration(labelText: 'Tipo')),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: newDemo,
                  title: const Text('Demo'),
                  subtitle: const Text('Marque se o produto é uma amostra de demostração'),
                  onChanged: (v) => setStateDialog(() => newDemo = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salvar')),
            ],
          );
        },
      ),
    );

    if (changed != true) return;

    final newTipo = tipoController.text.trim();
    final newNome = nomeController.text.trim();
    if (newTipo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tipo não pode ser vazio')));
      return;
    }
    if (newNome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome não pode ser vazio')));
      return;
    }

    final nomeMudou = newNome != p.nome;
    final tipoMudou = newTipo != p.tipo;
    final demoMudou = newDemo != p.demo;
    if (!nomeMudou && !tipoMudou && !demoMudou) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma alteração realizada')));
      return;
    }

    final path = p.categoria == ProdutoCategoria.biologico ? 'biologicos' : 'quimicos';
    final encodedOldName = Uri.encodeComponent(p.nome);
    final url = Uri.parse('${dotenv.env['BASE_URL']}/produtos/$path/$encodedOldName');

    final bodyMap = <String, dynamic>{};
    if (tipoMudou) bodyMap['tipo'] = newTipo;
    if (nomeMudou) bodyMap['nome'] = newNome;
    if (demoMudou) bodyMap['demo'] = newDemo;

    try {
      final resp = await http.put(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }, body: jsonEncode(bodyMap));

      if (resp.statusCode == 404 && nomeMudou) {
        final tryUrlNew = Uri.parse('${dotenv.env['BASE_URL']}/produtos/$path/${Uri.encodeComponent(newNome)}');
        final resp2 = await http.put(tryUrlNew, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }, body: jsonEncode(bodyMap));
        if (resp2.statusCode >= 200 && resp2.statusCode < 300) {
          if (!mounted) return;
          setState(() {
            final idx = _all.indexWhere((e) => e.id != null ? e.id == p.id : (e.nome == p.nome && e.categoria == p.categoria));
            if (idx != -1) {
              _all[idx] = ProdutoItem(id: p.id, nome: newNome, tipo: newTipo, categoria: p.categoria, demo: newDemo);
            }
            _applyFilters();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto atualizado')));
          return;
        }
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        setState(() {
          final idx = _all.indexWhere((e) => e.id != null ? e.id == p.id : (e.nome == p.nome && e.categoria == p.categoria));
          if (idx != -1) {
            _all[idx] = ProdutoItem(id: p.id, nome: newNome, tipo: newTipo, categoria: p.categoria, demo: newDemo);
          }
          _applyFilters();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto atualizado')));
      } else {
        String message = 'Erro ao atualizar (status ${resp.statusCode})';
        if (resp.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(resp.body);
            if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
    }
  }

  // ---------- Deletar produto (chama backend DELETE) ----------
  Future<void> _deleteProduto(ProdutoItem p) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja excluir o produto "${p.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm != true) return;

    final encodedName = Uri.encodeComponent(p.nome);
    final path = p.categoria == ProdutoCategoria.biologico ? 'biologicos' : 'quimicos';
    final url = Uri.parse('${dotenv.env['BASE_URL']}/produtos/$path/$encodedName');

    try {
      final resp = await http.delete(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        setState(() {
          _all.removeWhere((e) => e.id != null ? e.id == p.id : (e.nome == p.nome && e.categoria == p.categoria));
          _applyFilters();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto excluído')));
      } else {
        String message = 'Erro ao excluir (status ${resp.statusCode})';
        if (resp.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(resp.body);
            if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  // Dismiss handler para o banner
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
            label: 'Dica: deslize para ver mais conteúdo',
            hint: 'Toque para dispensar',
            child: Center(child: ScrollHintBanner(onDismissed: _dismissBanner)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardSoft = ColorManager.instance.card.withOpacity(0.12);
    //final cardSoftLight = ColorManager.instance.card.withOpacity(0.08);
    final surfaceBg = ColorManager.instance.background;
    final primary = ColorManager.instance.primary;
    final textPrimary = ColorManager.instance.explicitText;

    final tiposSet = <String>{};
    for (final p in _all) tiposSet.add(p.tipo);
    final tipos = tiposSet.toList()..sort();

    final vw = MediaQuery.of(context).size.width;
    //final vh = MediaQuery.of(context).size.height;
    final scale = vw > 1200 ? 1.12 : (vw > 900 ? 1.04 : 1.0);
    final isMobile = vw < 700;
    final isTablet = vw >= 700 && vw < 900;
    final isDesktop = vw >= 900;

    final maxWidth = isDesktop ? 1100.0 : (isTablet ? 900.0 : vw - 24);
    final cardRadius = BorderRadius.circular(isMobile ? 14 : 20);
    final innerPadding = EdgeInsets.all((isMobile ? 12 : 18) * scale);

    // Header (integrado ao card) — usa ChemicalCardHeader com trailing leve.
    Widget headerIntegrated() {
      final double headerBorderRadius = isMobile ? 14.0 : 20.0;
      final double scaleHeader = scale;
      final Widget trailing = Padding(
        padding: EdgeInsets.only(left: 8.0 * scaleHeader),
        child: isDesktop
            ? TextButton.icon(
                onPressed: _openCreateSheetOrDialog,
                icon: Icon(Icons.add_rounded, color: Colors.white, size: 18 * scaleHeader),
                label: Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scaleHeader, vertical: 8 * scaleHeader),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            : GestureDetector(
                onTap: _openCreateSheetOrDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * scaleHeader, vertical: 8 * scaleHeader),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary.withOpacity(0.95), primary]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: primary.withOpacity(0.16), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: ColorManager.instance.text, size: 18 * scaleHeader),
                      SizedBox(width: 8 * scaleHeader),
                      Text('Novo', style: TextStyle(color: ColorManager.instance.text, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
      );

      return ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(headerBorderRadius)),
        child: ChemicalCardHeader(
          title: 'Produtos',
          leadingIcon: Icons.inventory_2_rounded,
          primary: primary,
          borderRadius: headerBorderRadius,
          verticalPadding: 12 * scaleHeader,
          horizontalPadding: 14 * scaleHeader,
          scale: scaleHeader,
          trailing: trailing,
        ),
      );
    }

    Widget searchAndCount() {
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: primary),
                  hintText: 'Buscar',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 14),
                ),
              ),
            ),
          ),
          SizedBox(width: 12 * scale),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: isMobile ? 8 * scale : 10 * scale),
            decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(12)),
            child: Text('Exibindo ${_filtered.length}', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
          ),
        ],
      );
    }

    // Em mobile usar Dropdown para categoria; em desktop manter ChoiceChips
    Widget filtersWrap() {
      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
              decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<ProdutoCategoria>(
                value: _filterCategoria,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: surfaceBg,
                items: [
                  DropdownMenuItem(value: ProdutoCategoria.todos, child: Text('Todos')),
                  DropdownMenuItem(value: ProdutoCategoria.biologico, child: Row(children: [Icon(Icons.eco_rounded, size: 16), const SizedBox(width: 8), Text('Biológicos')])),
                  DropdownMenuItem(value: ProdutoCategoria.quimico, child: Row(children: [Icon(Icons.science_rounded, size: 16), const SizedBox(width: 8), Text('Químicos')])),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _filterCategoria = v;
                    _applyFilters();
                  });
                },
              ),
            ),
            SizedBox(height: 8 * scale),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
              decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<String?>(
                value: _filterTipo,
                underline: const SizedBox(),
                dropdownColor: surfaceBg,
                hint: const Text('Tipo'),
                isExpanded: true,
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  ...tipos.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                ],
                onChanged: (v) => setState(() {
                  _filterTipo = v;
                  _applyFilters();
                }),
              ),
            ),
          ],
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _filterCategoria == ProdutoCategoria.todos,
              onSelected: (_) => setState(() {
                _filterCategoria = ProdutoCategoria.todos;
                _applyFilters();
              }),
            ),
            SizedBox(width: 8 * scale),
            ChoiceChip(
              label: const Text('Biológicos'),
              selected: _filterCategoria == ProdutoCategoria.biologico,
              onSelected: (_) => setState(() {
                _filterCategoria = ProdutoCategoria.biologico;
                _applyFilters();
              }),
              avatar: const Icon(Icons.eco_rounded, size: 16),
            ),
            SizedBox(width: 8 * scale),
            ChoiceChip(
              label: const Text('Químicos'),
              selected: _filterCategoria == ProdutoCategoria.quimico,
              onSelected: (_) => setState(() {
                _filterCategoria = ProdutoCategoria.quimico;
                _applyFilters();
              }),
              avatar: const Icon(Icons.science_rounded, size: 16),
            ),
            SizedBox(width: 12 * scale),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
              decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<String?>(
                value: _filterTipo,
                underline: const SizedBox(),
                dropdownColor: surfaceBg,
                hint: const Text('Tipo'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  ...tipos.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                ],
                onChanged: (v) => setState(() {
                  _filterTipo = v;
                  _applyFilters();
                }),
              ),
            ),
          ],
        ),
      );
    }

    Widget listHeader() {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 10 * scale),
        decoration: BoxDecoration(color: surfaceBg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(flex: 5, child: Text('Nome', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * scale, color: textPrimary))),
            Expanded(flex: 4, child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * scale, color: textPrimary))),
            Expanded(flex: 2, child: Text('Categoria', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * scale, color: textPrimary))),
            SizedBox(width: 12 * scale),
            SizedBox(width: 48 * scale, child: Text('   ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * scale, color: textPrimary), textAlign: TextAlign.center)),
            SizedBox(width: 12 * scale),
            SizedBox(width: 48 * scale, child: Text('   ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * scale, color: textPrimary), textAlign: TextAlign.center)),
            SizedBox(width: 12 * scale),
          ],
        ),
      );
    }

    // listArea: agora é NÃO-ROLÁVEL internamente; o scroll acontece no SingleChildScrollView principal.
    Widget listArea() {
      if (_loading && _all.isEmpty) {
        return Center(child: CircularProgressIndicator(color: primary));
      }
      if (_error != null && _all.isEmpty) {
        return Center(child: Text(_error!, style: TextStyle(color: ColorManager.instance.emergency)));
      }

      // ListView shrinkWrapped and never-scrollable so top-level scroll handles everything.
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
        itemBuilder: (context, index) {
          final p = _filtered[index];
          return ProdutoListItem(
            produto: p,
            isMobile: isMobile,
            onTap: () => _showProdutoDetails(context, p),
            onEdit: () => _editProduto(p),
            onDelete: () => _deleteProduto(p),
          );
        },
      );
    }

    Widget buildCard() {
      return Container(
        decoration: BoxDecoration(color: cardSoft, borderRadius: cardRadius, border: Border.all(color: ColorManager.instance.card.withOpacity(0.6), width: 1.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header integrado ao painel (não flutuante)
            headerIntegrated(),
            // Conteúdo do painel
            Padding(
              padding: innerPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 12 * scale),
                  searchAndCount(),
                  SizedBox(height: 12 * scale),
                  filtersWrap(),
                  SizedBox(height: 12 * scale),
                  if (!isMobile) ...[listHeader(), SizedBox(height: 10 * scale)],
                  // Aqui listArea é shrinkWrapped e big — o scroll é do SingleChildScrollView acima
                  listArea(),
                ],
              ),
            ),
          ],
        ),
      );
    }


    // Top-level: RefreshIndicator + SingleChildScrollView (único scroll da tela)
    Widget screenBody = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: (isMobile ? 12 : 20) * scale, vertical: (isMobile ? 12 : 18) * scale),
          child: buildCard(),
        ),
      ),
    );

    screenBody = RefreshIndicator(
      onRefresh: _fetchProdutos,
      color: primary,
      child: SingleChildScrollView(
        controller: _pageController, // agora o scroll principal usa esse controller
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 80),
        child: SizedBox(width: double.infinity, child: screenBody),
      ),
    );

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surfaceBg,
        foregroundColor: ColorManager.instance.explicitText,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ScaleTransition(scale: _scaleAnim, child: screenBody),
            if (isMobile && _showScrollHint && !_bannerDismissed) _buildScrollBanner(context),
          ],
        ),
      ),
    );
  }

  void _showProdutoDetails(BuildContext context, ProdutoItem p) {
    final isBio = p.categoria == ProdutoCategoria.biologico;
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorManager.instance.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isBio ? Icons.eco_rounded : Icons.science_rounded, color: isBio ? ColorManager.instance.ok : ColorManager.instance.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.nome,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColorManager.instance.explicitText),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: ColorManager.instance.explicitText)),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.label_rounded, color: ColorManager.instance.explicitText), const SizedBox(width: 8), Text('Tipo: ${p.tipo}', style: TextStyle(color: ColorManager.instance.explicitText))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.category_rounded, color: ColorManager.instance.explicitText), const SizedBox(width: 8), Text('Categoria: ${isBio ? 'Biológico' : 'Químico'}', style: TextStyle(color: ColorManager.instance.explicitText))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.play_circle_fill_rounded, color: p.demo ? ColorManager.instance.ok : ColorManager.instance.explicitText), const SizedBox(width: 8), Text('Demo: ${p.demo ? 'Sim' : 'Não'}', style: TextStyle(color: ColorManager.instance.explicitText))]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(onPressed: () => _copyToClipboard(p.nome, 'Nome'), icon: Icon(Icons.copy_rounded, color: ColorManager.instance.primary)),
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Fechar', style: TextStyle(color: ColorManager.instance.primary))),
            ]),
          ],
        ),
      ),
    );
  }
}
