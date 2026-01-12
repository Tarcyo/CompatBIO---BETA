
import 'package:flutter/material.dart';
import 'package:planos/screens/pagamentos/compraDeCreditos.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/screens/dashboard/dashboard.dart';
import 'package:planos/screens/histoy/large_page.dart';
import 'package:planos/screens/solicitarAnalise/screen.dart';
import 'package:planos/screens/userProfile/profile.dart';

/// Controller público para controlar o SideBarInterno sem GlobalKey.
/// Instancie no parent e passe para o widget.
class SideBarController {
  void Function()? _reload;

  /// Interno: usado pelo estado para se registrar
  void _attach(void Function() fn) => _reload = fn;

  /// Interno: usado pelo estado para remover registro
  void _detach() => _reload = null;

  /// Chame para forçar o reload do "design" do sidebar sem alterar seleção/navegação
  void reload() => _reload?.call();
}

class SideBarInterno extends StatefulWidget {
  final SideBarController? controller;

  const SideBarInterno({Key? key, this.controller}) : super(key: key);

  @override
  State<SideBarInterno> createState() => _SideBarInternoState();
}

class _SideBarInternoState extends State<SideBarInterno>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;

  final List<String> labels = [
    "Solicitar",
    "Resultados",
    "Meu Perfil",
    "Dashboard",
    "Comprar Créditos",
  ];

  final List<IconData> icons = [
    Icons.grid_view_rounded,
    Icons.check_circle_rounded,
    Icons.person_rounded,
    Icons.analytics_rounded,
    Icons.currency_exchange_rounded,
  ];

  final List<bool> keepTabState = [false, false, false, false, false];

  late List<GlobalKey<NavigatorState>> navigatorKeys;
  late final TabController _tabController;

  // ScrollController para o sidebar rolável (evita erro do Scrollbar).
  late final ScrollController _sidebarScrollController;

  // Keys para forçar reload do design do sidebar sem alterar seleção
  Key _sidebarDesignKey = UniqueKey();
  Key _logoutButtonKeyDesktop = UniqueKey();
  Key _logoutButtonKeyDrawer = UniqueKey();

  /// Método chamado pelo controller para forçar a recriação dos widgets visuais
  void reloadSidebarDesign() {
    setState(() {
      _sidebarDesignKey = UniqueKey();
      _logoutButtonKeyDesktop = UniqueKey();
      _logoutButtonKeyDrawer = UniqueKey();

      // Se houver estado/listenables externos a forçar, notifique-os aqui.
      // Ex.: LogoManager.instance.notifyListeners();
    });
  }

  @override
  void initState() {
    super.initState();
    navigatorKeys = List.generate(
      labels.length,
      (_) => GlobalKey<NavigatorState>(),
    );
    _tabController = TabController(
      length: labels.length,
      vsync: this,
      initialIndex: selectedIndex,
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          selectedIndex = _tabController.index;
        });
      }
    });

    // inicializa o ScrollController do sidebar
    _sidebarScrollController = ScrollController();

    // attach controller se presente
    widget.controller?._attach(reloadSidebarDesign);
  }

  @override
  void didUpdateWidget(covariant SideBarInterno oldWidget) {
    super.didUpdateWidget(oldWidget);
    // troque attachment caso o controller mude
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(reloadSidebarDesign);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _tabController.dispose();
    _sidebarScrollController.dispose(); // descarta o controller
    super.dispose();
  }

  Widget _initialPageForIndex(int index) {
    switch (index) {
      case 0:
        return const LabMinimalScreen();
      case 1:
        return const HistoryLargeDemoPage();
      case 2:
        return UserProfilePage(controller: widget.controller);
      case 3:
        return const DashboardsPage();
      case 4:
        return const CreditBuyPage();

      default:
        return const Center(child: Text('Tela não implementada'));
    }
  }

  Future<bool> _onWillPop() async {
    final currentNavigatorState = navigatorKeys[selectedIndex].currentState;
    if (currentNavigatorState != null && currentNavigatorState.canPop()) {
      currentNavigatorState.pop();
      return false;
    }
    return true;
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Deseja realmente sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sessão finalizada'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: 'Desfazer', onPressed: () {}),
        ),
      );
    }
  }

  void _onTabSelected(int index) {
    if (selectedIndex == index) {
      final nav = navigatorKeys[index].currentState;
      if (nav != null) nav.popUntil((r) => r.isFirst);
      return;
    }

    setState(() {
      selectedIndex = index;
      _tabController.index = index;
    });

    if (!keepTabState[index]) {
      _reloadTab(index);
    }
  }

  void _reloadTab(int index) {
    final navState = navigatorKeys[index].currentState;

    if (navState == null) {
      navigatorKeys[index] = GlobalKey<NavigatorState>();
      setState(() {});
      return;
    }

    navState.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (ctx) => SizedBox.expand(child: _initialPageForIndex(index)),
      ),
      (route) => false,
    );
  }

  /// Constrói a área lateral (desktop). Garante que os itens nunca fiquem
  /// ocultos usando uma área rolável com cálculo responsivo de altura por item.
  Widget _buildSidebar(double height, double sidebarWidth, double buttonScale) {
    return CustomPaint(
      painter: SidebarBackgroundPainter(),
      child: Container(
        height: height,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Espaço superior / possível logo - deixamos para a parte externa que já o fornece.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: LayoutBuilder(builder: (context, constraints) {
                  // Disponível para os itens (para cálculo responsivo)
                  final double availableHeight = constraints.maxHeight;
                  // Reserve um mínimo de espaço para footer (logout) + spacing
                  final double reservedBottom = 24.0 * buttonScale + 16.0;
                  final double usableHeight =
                      (availableHeight - reservedBottom).clamp(80.0, availableHeight);

                  // Altura por item calculada para garantir que todos caibam,
                  // mas nunca menor que um alvo mínimo (para acessibilidade)
                  final double minItemHeight = (56.0 * buttonScale).clamp(48.0, 72.0);
                  final double targetItemHeight = (90.0 * buttonScale);
                  final double computedItemHeight = (usableHeight / labels.length);
                  final double itemHeight = computedItemHeight.clamp(minItemHeight, targetItemHeight);

                  return Scrollbar(
                    controller: _sidebarScrollController, // <-- controller adicionado
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _sidebarScrollController, // <-- controller adicionado
                      padding: EdgeInsets.symmetric(vertical: 8.0 * buttonScale),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(labels.length, (index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.0 * buttonScale),
                            child: SizedBox(
                              width: sidebarWidth * 0.9,
                              height: itemHeight,
                              child: _SideButton(
                                icon: icons[index],
                                label: labels[index],
                                active: selectedIndex == index,
                                onTap: () => _onTabSelected(index),
                                height: itemHeight,
                                fontScale: buttonScale,
                                iconSize: (24 * buttonScale).clamp(16.0, 34.0),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Alterado: aceita flag para pintar apenas os itens do menu (drawer) em preto.
  Drawer _buildDrawer(double buttonScale, {bool menuItemsBlack = false}) {
    final cm = ColorManager.instance;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 24 * buttonScale,
                    fontWeight: FontWeight.bold,
                    color: cm.explicitText,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: labels.length,
                itemBuilder: (context, index) {
                  final active = index == selectedIndex;
                  final iconColor = menuItemsBlack ? Colors.black : (active ? cm.primary : null);
                  final textColor = menuItemsBlack ? Colors.black : cm.text;
                  return ListTile(
                    leading: Icon(
                      icons[index],
                      size: 24 * buttonScale,
                      color: iconColor,
                    ),
                    title: Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 16 * buttonScale,
                        color: textColor,
                      ),
                    ),
                    selected: active,
                    onTap: () {
                      _onTabSelected(index);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0 * buttonScale,
                vertical: 12.0 * buttonScale,
              ),
              child: LogoutButton(
                key: _logoutButtonKeyDrawer,
                scale: buttonScale,
                flipIcon: true,
                label: 'Sair do aplicativo',
                onLogout: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                onUndo: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ação desfeita')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cm = ColorManager.instance;
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          color: cm.background,
          child: Stack(
            fit: StackFit.expand,
            children: List.generate(labels.length, (index) {
              final isActive = selectedIndex == index;
              final targetOffset = isActive
                  ? Offset.zero
                  : const Offset(0.2, 0);
              final targetOpacity = isActive ? 1.0 : 0.0;

              return Positioned.fill(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  offset: targetOffset,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: targetOpacity,
                    child: IgnorePointer(
                      ignoring: !isActive,
                      child: SizedBox.expand(
                        child: Navigator(
                          key: navigatorKeys[index],
                          onGenerateRoute: (RouteSettings settings) {
                            return MaterialPageRoute(
                              builder: (context) => SizedBox.expand(
                                child: _initialPageForIndex(index),
                              ),
                              settings: settings,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _logoWidget(double size) {
    return AnimatedBuilder(
      animation: LogoManager.instance,
      builder: (context, _) {
        final Widget current = LogoManager.instance.logo;
        if (current is SizedBox) {
          final SizedBox sb = current;
          final double? w = sb.width;
          final double? h = sb.height;
          if ((w != null && w <= 1.0) || (h != null && h <= 1.0)) {
            return SizedBox(
              width: size,
              height: size,
              child: const FittedBox(fit: BoxFit.contain, child: FlutterLogo()),
            );
          }
        }
        return SizedBox(
          width: size,
          height: size,
          child: FittedBox(fit: BoxFit.contain, child: current),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cm = ColorManager.instance;

    final bool isSmallScreen = size.width < 800;
    final double baseScale = (size.width / 1280).clamp(0.6, 1.15);
    final double buttonScale = isSmallScreen
        ? (size.width / 420).clamp(0.85, 1.05)
        : baseScale;
    final double sidebarWidth = isSmallScreen
        ? size.width * 0.9
        : (size.width * 0.28).clamp(220, 420);

    if (isSmallScreen) {
      final double tabLabelFontSize = (12.0 * buttonScale).clamp(10.0, 18.0);
      final double tabUnselectedFontSize = (11.0 * buttonScale).clamp(
        9.0,
        16.0,
      );
      final double tabIconSize = (20.0 * buttonScale).clamp(16.0, 28.0);

      return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: cm.primary,
          drawer: _buildDrawer(buttonScale, menuItemsBlack: true),
          appBar: AppBar(
            backgroundColor: cm.primary,
            elevation: 4,
            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(
                    Icons.menu_rounded,
                    color: cm.text,
                    size: 26 * buttonScale,
                  ),
                  tooltip: 'Abrir menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: (80.0 * buttonScale).clamp(100.0, 320.0),
                  width: (80.0 * buttonScale).clamp(100.0, 320.0),
                  child: _logoWidget((80.0 * buttonScale).clamp(100.0, 320.0)),
                ),
                SizedBox(width: 8 * buttonScale),
           
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 10.0 * buttonScale),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _onTabSelected(2),
                      child: CircleAvatar(
                        radius: 16 * buttonScale,
                        backgroundColor: cm.background.withOpacity(0.12),
                        child: Icon(
                          Icons.person_rounded,
                          color: cm.text,
                          size: 18 * buttonScale,
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * buttonScale),
                    Tooltip(
                      message: 'Sair do aplicativo',
                      child: TextButton.icon(
                        onPressed: () => _showLogoutConfirmation(),
                        icon: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                          child: Icon(
                            Icons.logout_rounded,
                            color: cm.text,
                            size: 18 * buttonScale,
                          ),
                        ),
                        label: Text(
                          'Sair',
                          style: TextStyle(
                            color: cm.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14 * buttonScale,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: cm.background.withOpacity(0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              20 * buttonScale,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10 * buttonScale,
                            vertical: 8 * buttonScale,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SizedBox.expand(child: _buildContentArea()),
          bottomNavigationBar: Material(
            color: cm.primary,
            child: SafeArea(
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: cm.text,
                indicatorWeight: 3,
                labelColor: cm.text,
                unselectedLabelColor: cm.text.withOpacity(0.7),
                labelStyle: TextStyle(
                  fontSize: tabLabelFontSize,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: tabUnselectedFontSize,
                  fontWeight: FontWeight.w500,
                ),
                tabs: List.generate(
                  labels.length,
                  (index) => Tab(
                    icon: Icon(icons[index], size: tabIconSize),
                    text: labels[index],
                  ),
                ),
                onTap: (index) => _onTabSelected(index),
              ),
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: cm.primary,
        body: Row(
          children: [
            Container(
              key: _sidebarDesignKey,
              width: sidebarWidth,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  SafeArea(
                    top: true,
                    bottom: false,
                    left: true,
                    right: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.0 * buttonScale,
                        vertical: 4.0 * buttonScale,
                      ),
                      child: Builder(
                        builder: (context) {
                          final double horizontalPadding =
                              12.0 * buttonScale * 2;
                          final double logoutWidth = (56.0 * buttonScale).clamp(
                            40.0,
                            96.0,
                          );
                          final double availableForLogo =
                              (sidebarWidth - horizontalPadding - (logoutWidth * 2) - 16.0)
                                  .clamp(48.0, sidebarWidth);
                          final double logoSize = (availableForLogo * 1.08)
                              .clamp(120.0, sidebarWidth * 0.98);
                          final double topAreaHeight = (logoSize * 1.05).clamp(
                            64.0,
                            360.0,
                          );

                          return SizedBox(
                            height: topAreaHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 8.0 * buttonScale,
                                  bottom: 8.0 * buttonScale,
                                  child: LogoutButton.compact(
                                    key: _logoutButtonKeyDesktop,
                                    scale: buttonScale,
                                    tooltip: 'Sair',
                                    flipIcon: true,
                                    label: 'Sair',
                                    onLogout: () {
                                      Navigator.pop(context);
                                    },
                                    onUndo: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Ação desfeita'),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: availableForLogo,
                                      maxHeight: topAreaHeight,
                                    ),
                                    child: SizedBox(
                                      width: logoSize,
                                      height: logoSize,
                                      child: _logoWidget(logoSize),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: SizedBox(width: logoutWidth),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Aqui usamos o buildSidebar que já contém Scrollbar/SingleChildScrollView
                  Expanded(
                    child: _buildSidebar(
                      size.height - (160 * buttonScale),
                      sidebarWidth,
                      buttonScale,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContentArea()),
          ],
        ),
      ),
    );
  }
}

/// LogoutButton — componente reutilizável
class LogoutButton extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onUndo;
  final double scale;
  final String? tooltip;
  final bool compact;
  final bool flipIcon;
  final String label;

  const LogoutButton({
    Key? key,
    this.onLogout,
    this.onUndo,
    this.scale = 1.0,
    this.flipIcon = true,
    this.label = 'Sair',
  }) : compact = false,
       tooltip = null,
       super(key: key);

  const LogoutButton.compact({
    Key? key,
    this.onLogout,
    this.onUndo,
    this.scale = 1.0,
    this.tooltip,
    this.flipIcon = true,
    this.label = 'Sair',
  }) : compact = true,
       super(key: key);

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onLogout?.call();

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Sessão finalizada'),
          action: widget.onUndo != null
              ? SnackBarAction(
                  label: 'Desfazer',
                  onPressed: () => widget.onUndo?.call(),
                )
              : null,
          duration: const Duration(seconds: 4),
        ),
      );

      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale.clamp(0.6, 1.4);
    final cm = ColorManager.instance;
    const IconData indicativeIcon = Icons.logout_rounded;

    Widget buildIcon(double size) {
      final icon = Icon(indicativeIcon, color: cm.text, size: size);
      if (widget.flipIcon) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
          child: icon,
        );
      }
      return icon;
    }

    if (widget.compact) {
      final double size = 48.0 * s;
      return Tooltip(
        message: widget.tooltip ?? widget.label,
        child: Semantics(
          button: true,
          label: widget.label,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: _handleLogout,
              child: AnimatedScale(
                scale: _pressed ? 0.92 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _pressed
                        ? LinearGradient(colors: [cm.emergency, cm.alert])
                        : LinearGradient(
                            colors: [
                              cm.background.withOpacity(0.12),
                              cm.background.withOpacity(0.03),
                            ],
                          ),
                    boxShadow: _pressed
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 14 * s,
                              offset: Offset(0, 6 * s),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6 * s,
                              offset: Offset(0, 3 * s),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _handleLogout,
                      splashFactory: InkRipple.splashFactory,
                      child: Center(child: buildIcon(22 * s)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleLogout,
          borderRadius: BorderRadius.circular(40.0 * s),
          splashFactory: InkRipple.splashFactory,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cm.emergency, cm.alert]),
              borderRadius: BorderRadius.circular(40.0 * s),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 14 * s,
                  offset: Offset(0, 6 * s),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              vertical: 8.0 * s,
              horizontal: 12.0 * s,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildIcon(18 * s),
                SizedBox(width: 10 * s),
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cm.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 14 * s,
                    ),
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

/// Login View (exemplo)
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;
    return Center(
      key: const ValueKey("LoginView"),
      child: Text(
        'Tela de Login — indicativo',
        style: TextStyle(fontSize: 22, color: cm.card),
      ),
    );
  }
}

/// Sign In View (exemplo)
class SignInView extends StatelessWidget {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;
    return Center(
      key: const ValueKey("SignInView"),
      child: Text(
        'Tela de Cadastro — indicativo',
        style: TextStyle(fontSize: 22, color: cm.card),
      ),
    );
  }
}

/// _SideButton atualizado para aceitar altura variável (garante responsividade).
class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double fontScale;
  final double iconSize;
  final double height;

  const _SideButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.height,
    this.fontScale = 1.0,
    this.iconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;

    // Calcula tipografia em função da altura disponível para manter legibilidade
    final double effectiveHeight = height.clamp(48.0, 160.0);
    final double baseFont = (effectiveHeight / 90.0) * 18.0;
    final double fontSize = baseFont.clamp(12.0, 24.0) * fontScale;
    final double iconEffectiveSize = iconSize.clamp(16.0, effectiveHeight * 0.6);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: effectiveHeight,
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [cm.background, cm.background.withOpacity(0.96)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(50),
              bottomLeft: Radius.circular(50),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: active ? cm.explicitText : cm.text,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              letterSpacing: 1.2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconEffectiveSize,
                  color: active ? cm.explicitText : cm.text,
                ),
                SizedBox(width: 10 * fontScale),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
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

/// SidebarBackgroundPainter
class SidebarBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cm = ColorManager.instance;
    final paint1 = Paint()
      ..shader = LinearGradient(
        colors: [cm.primary, cm.primary],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    final paint2 = Paint()
      ..shader = LinearGradient(
        colors: [cm.background.withOpacity(0.25), Colors.transparent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path2 = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.1,
        size.width,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.7,
        0,
        size.height * 0.8,
      )
      ..close();
    canvas.drawPath(path2, paint2);

    final paint3 = Paint()
      ..shader = LinearGradient(
        colors: [cm.background.withOpacity(0.15), Colors.transparent],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path3 = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.9,
        size.width,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
