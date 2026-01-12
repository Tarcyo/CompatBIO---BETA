import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/histoy/card_large.dart';
import 'package:planos/screens/histoy/models.dart';
import 'package:planos/services/getSolicitacoes.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';

/// Header usado no topo do Card — mesmo estilo visual do `ChemicalCardHeader`.
/// Observação: esta versão NÃO possui botão de voltar.
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

  Color _foregroundFor(Color bg) => bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    final primaryMid = _darken(primary, 0.08);
    final primaryEnd = _darken(primary, 0.20);
    final shadowColor = _darken(primary, 0.45).withOpacity(0.22);

    final iconSize = 16.0 * scale + 8.0;
    final titleFont = 18.0 * scale + 4.0;
    final fg = _foregroundFor(primary);

    return Container(
      // The header assumes it's attached to the top of the Card — rounded only on top corners.
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
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(leadingIcon, color: fg, size: iconSize),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: fg,
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

class HistoryLargeDemoPage extends StatefulWidget {
  const HistoryLargeDemoPage({super.key});

  @override
  _HistoryLargeDemoPageState createState() => _HistoryLargeDemoPageState();
}

class _HistoryLargeDemoPageState extends State<HistoryLargeDemoPage> {
  late Future<List<HistoryItem>> _futureHistory;

  // Dados carregados e filtrados localmente
  List<HistoryItem> _allItems = [];
  List<HistoryItem> _filteredItems = [];

  // filtros (estado local e UI)
  String _statusFilter = 'Todas';
  DateTimeRange? _dateRange;
  String _searchQuery = '';

  // flag local para controlar exibição do banner (dismiss)
  bool _bannerDismissed = false;
  bool _notifiedScroll = false; // para notificar apenas uma vez

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _futureHistory = HistoryService(userProvider).fetchHistory();

    // Depois que o fetch completar, gravamos itens locais e aplicamos filtros
    _futureHistory.then((list) {
      if (mounted) {
        setState(() {
          _allItems = List<HistoryItem>.from(list);
          _applyFilters();
        });
      }
    }).catchError((_) {
      // Erros são tratados no FutureBuilder; aqui não precisamos de ação.
    });
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();
    final status = _statusFilter;
    final range = _dateRange;

    _filteredItems = _allItems.where((item) {
      final s = item.toString().toLowerCase();

      // Busca por texto usando toString() (defensiva — não presume campos específicos).
      final matchesSearch = q.isEmpty || s.contains(q);

      // Status: tentamos acessar dinamicamente `status` se existir, senão caímos no toString().
      bool matchesStatus = true;
      if (status != 'Todas') {
        try {
          final dynStatus = (item as dynamic).status;
          if (dynStatus != null) {
            matchesStatus = dynStatus.toString().toLowerCase() == status.toLowerCase();
          } else {
            matchesStatus = s.contains(status.toLowerCase());
          }
        } catch (_) {
          matchesStatus = s.contains(status.toLowerCase());
        }
      }

      // Data: tentamos extrair propriedades comuns (`data`, `date`, `createdAt`) e comparar se for DateTime.
      bool matchesDate = true;
      if (range != null) {
        try {
          final dyn = item as dynamic;
          DateTime? itemDate;
          if (dyn.data is DateTime) {
            itemDate = dyn.data as DateTime;
          } else if (dyn.date is DateTime) {
            itemDate = dyn.date as DateTime;
          } else if (dyn.createdAt is DateTime) {
            itemDate = dyn.createdAt as DateTime;
          } else {
            final cand = (dyn.data ?? dyn.date ?? dyn.createdAt);
            if (cand is String) {
              itemDate = DateTime.tryParse(cand);
            }
          }
          if (itemDate != null) {
            matchesDate = !itemDate.isBefore(range.start) && !itemDate.isAfter(range.end);
          } else {
            matchesDate = true;
          }
        } catch (_) {
          matchesDate = true;
        }
      }

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  // Callback: chamado quando a página é rolada (NotificationListener na SingleChildScrollView)
  void _onUserScrolled() {
    if (!_bannerDismissed && !_notifiedScroll && mounted) {
      setState(() {
        _bannerDismissed = true;
        _notifiedScroll = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;
    final vw = MediaQuery.of(context).size.width;
    final vh = MediaQuery.of(context).size.height;

    final horizontalMargin = vw >= 1400 ? 40.0 : (vw >= 1000 ? 28.0 : 16.0);
    final verticalMargin = vh >= 900 ? 28.0 : 18.0;
    final cardWidth = (vw - (horizontalMargin * 2)).clamp(360.0, 1400.0);

    // Observação: o card agora expande para mostrar TODOS os itens. A página inteira é rolável.
    return Scaffold(
      backgroundColor: cm.background,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (!_notifiedScroll && notification is ScrollStartNotification) {
              _onUserScrolled();
            }
            return false;
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: cardWidth, maxWidth: cardWidth),
                child: Card(
                  color: cm.card.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: cm.card.withOpacity(0.6), width: 1.6),
                  ),
                  elevation: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChemicalCardHeader(
                        title: 'Histórico de solicitações',
                        leadingIcon: Icons.history_rounded,
                        primary: cm.primary,
                        borderRadius: 20.0,
                        verticalPadding: 14.0,
                        horizontalPadding: 16.0,
                        scale: 1.0,
                        trailing: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),

                      // Conteúdo dentro do Card — sem altura fixa. O HistoryCardLarge expande para mostrar todos os itens.
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: FutureBuilder<List<HistoryItem>>(
                          future: _futureHistory,
                          builder: (context, snapshot) {
                            // enquanto carrega e ainda não temos _allItems, mostramos indicador
                            if (snapshot.connectionState == ConnectionState.waiting && _allItems.isEmpty) {
                              return SizedBox(
                                height: 160,
                                child: Center(child: CircularProgressIndicator(color: cm.primary)),
                              );
                            }

                            if (snapshot.hasError && _allItems.isEmpty) {
                              return SizedBox(
                                height: 120,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error_outline_rounded, color: cm.emergency, size: 28),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Erro ao carregar histórico: ${snapshot.error}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 16, color: cm.explicitText),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final displayItems = _filteredItems.isNotEmpty ||
                                    _searchQuery.isNotEmpty ||
                                    _dateRange != null ||
                                    _statusFilter != 'Todas'
                                ? _filteredItems
                                : (snapshot.data ?? _allItems);

                            if (displayItems.isEmpty) {
                              return SizedBox(
                                height: 120,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.history_rounded, color: cm.primary, size: 28),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Nenhuma solicitação encontrada.',
                                        style: TextStyle(fontSize: 16, color: cm.explicitText),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Passa onUserScrolled apenas para compatibilidade; a notificação real vem da página.
                            return HistoryCardLarge(
                              items: displayItems,
                              onUserScrolled: _onUserScrolled,
                              bottomInset: !_bannerDismissed ? 72.0 : 16.0,
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
      // Banner de dica de scroll — posicionado na parte inferior; exibido somente se não dismissado
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: !_bannerDismissed
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ScrollHintBanner(
                onDismissed: () {
                  if (mounted) {
                    setState(() {
                      _bannerDismissed = true;
                    });
                  }
                },
              ),
            )
          : null,
    );
  }
}
