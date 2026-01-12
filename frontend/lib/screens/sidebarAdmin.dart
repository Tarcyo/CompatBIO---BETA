import 'package:flutter/material.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/screens/dashboard/dashboard.dart';
import 'package:planos/screens/empresa/empresa.dart';
import 'package:planos/screens/history_admin/history%20admin.dart';
import 'package:planos/screens/adminProduto/adminProduto.dart';
import 'package:planos/screens/configSistema/config_sistema.dart';
import 'package:planos/screens/listaDePlanos/listaDePlanos.dart';
import 'package:planos/screens/resultadosAdmin/resultado_screen.dart';

class SideBarInternoAdmin extends StatefulWidget {
  const SideBarInternoAdmin({super.key});

  @override
  State<SideBarInternoAdmin> createState() => _SideBarInternoAdminState();
}

class _SideBarInternoAdminState extends State<SideBarInternoAdmin>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;

  final List<String> labels = [
    "Solicitações",
    "Resultados",
    "Produtos",
    "Configuração",
    "Dashboard",
    "Empresas",
    "Planos",
  ];

  // ícones indicativos e _rounded
  final List<IconData> icons = [
    Icons.list_alt_rounded, // Solicitações
    Icons.check_circle_rounded, // Resultados
    Icons.inventory_2_rounded, // Produtos
    Icons.settings_rounded, // Configuração
    Icons.dashboard_rounded,
    Icons.corporate_fare_rounded,
    Icons.list_rounded,
  ];

  // Controla por aba se queremos manter estado (true) ou recarregar sempre (false)
  final List<bool> keepTabState = [
    false,
    false,
    false,
    false,
    false,
    false,
    false,
  ];

  // navigatorKeys precisa ser mutável para que possamos trocar a key e forçar rebuild
  late List<GlobalKey<NavigatorState>> navigatorKeys;
  late final TabController _tabController;

  // ScrollController para o sidebar rolável (evita erro do Scrollbar)
  late final ScrollController _sidebarScrollController;

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

    _sidebarScrollController = ScrollController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  Widget _initialPageForIndex(int index) {
    switch (index) {
      case 0:
        return const SolicitacoesTodasScreen();
      case 2:
        return const ProdutosScreen();
      case 1:
        return const ResultadosScreen();
      case 3:
        return const ConfigScreen();
      case 4:
        return const DashboardsPage();
      case 5:
        return const EmpresaScreen();
      case 6:
        return const PlanosScreen();
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

  /// helper: diálogo de confirmação de logout usado pela AppBar
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
      // exemplo de ação: fechar a rota atual (substitua pela ação real de logout)
      if (Navigator.canPop(context)) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sessão finalizada'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              // opcional: lógica de desfazer
            },
          ),
        ),
      );
    }
  }

  /// CENTRALIZA o comportamento de seleção de aba.
  /// - mantém selectedIndex e _tabController
  /// - dispara recarregamento da aba se necessário
  void _onTabSelected(int index) {
    if (selectedIndex == index) {
      // comportamento opcional: se clicar na aba ativa, volta ao root da pilha da aba
      final nav = navigatorKeys[index].currentState;
      if (nav != null) {
        nav.popUntil((r) => r.isFirst);
      }
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

  /// Força recarregamento da aba:
  /// - se Navigator não estiver montado, troca a GlobalKey e rebuilda
  /// - se estiver montado, limpa a stack e empurra a rota inicial
  void _reloadTab(int index) {
    final navState = navigatorKeys[index].currentState;

    if (navState == null) {
      // Navigator ainda não está no widget tree: trocamos a key para forçar rebuild
      navigatorKeys[index] = GlobalKey<NavigatorState>();
      setState(() {}); // força rebuild para aplicar a nova key
      return;
    }

    // Se o Navigator já está montado: limpar a stack e empurrar a rota inicial.
    // Assim initState/ construções serão reexecutadas.
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
    final cm = ColorManager.instance;
    return CustomPaint(
      painter: SidebarBackgroundPainter(),
      child: Container(
        height: height,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SafeArea(
              top: true,
              bottom: false,
              left: true,
              right: false,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 12.0, top: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone "Administrador" no topo do sidebar (bola branca com sombra)
                      SizedBox(
                        height: 48 * buttonScale,
                        width: 48 * buttonScale,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 4 * buttonScale,
                                offset: Offset(0, 2 * buttonScale),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(6 * buttonScale),
                            child: Center(
                              child: Icon(
                                Icons.admin_panel_settings_rounded,
                                size: (28 * buttonScale).clamp(18.0, 36.0),
                                color: cm.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LogoutButton.compact(
                        scale: buttonScale,
                        tooltip: 'Sair',
                        flipIcon: true,
                        label: 'Sair',
                        onLogout: () {
                          Navigator.pop(context);
                        },
                        onUndo: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ação desfeita')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Expanded com Scrollbar + SingleChildScrollView controlados
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: LayoutBuilder(builder: (context, constraints) {
                  final double availableHeight = constraints.maxHeight;
                  // Reserve espaço para footer (espaço inferior)
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
                    controller: _sidebarScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _sidebarScrollController,
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
                                onTap: () {
                                  _onTabSelected(index);
                                },
                                fontScale: buttonScale,
                                iconSize: 24 * buttonScale,
                                // repassamos height para que o botão se ajuste corretamente
                                height: itemHeight,
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

  // Alteração: parâmetro opcional menuItemsBlack para pintar apenas os itens do drawer em preto.
  Drawer _buildDrawer(double buttonScale, {bool menuItemsBlack = false}) {
    final cm = ColorManager.instance;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    SizedBox(
                      height: 36 * buttonScale,
                      width: 36 * buttonScale,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 4 * buttonScale,
                              offset: Offset(0, 2 * buttonScale),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4 * buttonScale),
                          child: Center(
                            child: Icon(
                              Icons.admin_panel_settings_rounded,
                              size: (22 * buttonScale).clamp(14.0, 28.0),
                              color: cm.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * buttonScale),
                    Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 24 * buttonScale,
                        fontWeight: FontWeight.bold,
                        color: cm.explicitText,
                      ),
                    ),
                  ],
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
                      style: TextStyle(fontSize: 16 * buttonScale, color: textColor),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cm = ColorManager.instance;

    final bool isSmallScreen = size.width < 800; // breakpoint

    final double baseScale = (size.width / 1280).clamp(0.6, 1.15);
    final double buttonScale = isSmallScreen
        ? (size.width / 420).clamp(0.85, 1.05)
        : baseScale;

    final double sidebarWidth = isSmallScreen
        ? size.width * 0.9
        : (size.width * 0.28).clamp(220, 420);

    // Modo mobile/tablet: Drawer + AppBar redesenhado (mais intuitivo)
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

          // === AppBar redesenhado para ficar mais claro e intuitivo ===
          appBar: AppBar(
            backgroundColor: cm.primary,
            elevation: 4,
            // botão de abrir drawer (hamburger) — mais esperado no mobile
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
            // título com ícone de administrador + nome
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28 * buttonScale,
                  width: 28 * buttonScale,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white, // "bola branca"
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 4 * buttonScale,
                          offset: Offset(0, 2 * buttonScale),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(4 * buttonScale),
                      child: Center(
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          size: (20 * buttonScale).clamp(12.0, 28.0),
                          color: cm.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8 * buttonScale),
                Text(
                  'Admin', // ajuste para o nome do seu app
                  style: TextStyle(
                    fontSize: 18 * buttonScale,
                    fontWeight: FontWeight.w600,
                    color: cm.text,
                  ),
                ),
              ],
            ),
            // ações: avatar (perfil) + botão discreto de logout (pílula)
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 10.0 * buttonScale),
                child: Row(
                  children: [
                    // atalho para perfil — toca muda para a aba "Meu Perfil"
                    GestureDetector(
                      onTap: () {
                        _onTabSelected(2);
                      },
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
                    // botão "Sair" discreto e legível (texto + ícone espelhado)
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
                tabs: List.generate(labels.length, (index) {
                  return Tab(
                    icon: Icon(icons[index], size: tabIconSize),
                    text: labels[index],
                  );
                }),
                onTap: (index) {
                  _onTabSelected(index);
                },
              ),
            ),
          ),
        ),
      );
    }

    // Modo desktop: sidebar fixa (mantive igual)
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: cm.primary,
        body: Row(
          children: [
            Container(
              width: sidebarWidth,
              child: _buildSidebar(size.height, sidebarWidth, buttonScale),
            ),
            Expanded(child: _buildContentArea()),
          ],
        ),
      ),
    );
  }
}

/// LogoutButton — componente reutilizável (mantive igual à versão anterior)
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
  })  : compact = false,
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
  })  : compact = true,
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
                        ? LinearGradient(
                            colors: [
                              cm.emergency,
                              cm.alert,
                            ],
                          )
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
              gradient: LinearGradient(
                colors: [cm.emergency, cm.alert],
              ),
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
                if (widget.onUndo != null)
                  Padding(
                    padding: EdgeInsets.only(left: 8.0 * s),
                    child: TextButton(
                      onPressed: () => widget.onUndo?.call(),
                      style: TextButton.styleFrom(
                        foregroundColor: cm.text,
                      ),
                      child: Text(
                        'Desfazer',
                        style: TextStyle(fontSize: 12 * s),
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
  final double? height;

  const _SideButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.fontScale = 1.0,
    this.iconSize = 24.0,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;
    final double effectiveHeight = (height ?? (90 * fontScale)).clamp(48.0, 160.0);

    return GestureDetector(
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
            fontSize: active ? (20 * fontScale).clamp(12.0, 24.0) : (18 * fontScale).clamp(12.0, 22.0),
            letterSpacing: 1.4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize.clamp(16.0, effectiveHeight * 0.6),
                color: active ? cm.explicitText : cm.text,
              ),
              SizedBox(width: 10 * fontScale),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
            ],
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
