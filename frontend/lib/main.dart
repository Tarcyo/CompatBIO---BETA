import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:planos/screens/Login.dart';
import 'package:planos/screens/Registro.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: "env.txt");


   
  await applyEmpresaFromPrefs();
  runApp(RefreshWidget(child:  const MyApp(),));
}

// ----------------------- Refresh Widget (rebuild sem reiniciar) -----------------------
class RefreshWidget extends StatefulWidget {
  final Widget child;
  const RefreshWidget({required this.child, super.key});

  /// Use esta função para forçar um "refresh" do app sem reiniciar o processo.
  /// Ela reaplica prefs (cores/logo) e provoca rebuild do subtree.
  static Future<void> refreshApp(BuildContext context) async {
    final _RefreshWidgetState? state = context
        .findAncestorStateOfType<_RefreshWidgetState>();
    if (state != null) {
      await state._refresh();
    }
  }

  @override
  _RefreshWidgetState createState() => _RefreshWidgetState();
}

class _RefreshWidgetState extends State<RefreshWidget> {
  // counter usado apenas para valueKey e forçar rebuild profundo
  int _tick = 0;

  Future<void> _refresh() async {
    // Reaplica preferências (cores + logo)
    await applyEmpresaFromPrefs();

    // Atualiza o estado local para forçar rebuild do subtree com nova ValueKey
    setState(() => _tick++);
  }

  @override
  Widget build(BuildContext context) {
    // Ao mudar a key, widgets filhos que dependem de valores globais serão reconstruídos.
    return KeyedSubtree(key: ValueKey<int>(_tick), child: widget.child);
  }
}

// ----------------------- Função de Apply Empresa -----------------------
Future<void> applyEmpresaFromPrefs({
  double logoWidth = 120,
  double logoHeight = 40,
}) async {
  const String prefKeyCor = 'empresa_corTema';
  const String prefKeyLogoBase64 = 'empresa_logo_base64';

  final prefs = await SharedPreferences.getInstance();

  // ---------------- COR ----------------
  final savedHex = prefs.getString(prefKeyCor);
  if (savedHex != null && savedHex.trim().isNotEmpty) {
    try {
      final color = ColorManager.fromHex(savedHex.trim());
      ColorManager.instance.setColor(ColorRole.primary, color);
      ColorManager.instance.setColor(
        ColorRole.card,
        color.withValues(alpha: 0.8),
      );
      ColorManager.instance.setColor(
        ColorRole.highlightText,
        color.withValues(alpha: 0.7),
      );
      debugPrint(
        'applyEmpresaFromPrefs: cor aplicada do SharedPreferences ($savedHex)',
      );
    } catch (e) {
      debugPrint(
        'applyEmpresaFromPrefs: cor inválida "$savedHex", usando azul padrão.',
      );
    }
  } else {
    debugPrint('applyEmpresaFromPrefs: sem cor salva, usando azul padrão.');
  }

  // ---------------- LOGO ----------------
  final savedLogoBase64 = prefs.getString(prefKeyLogoBase64);
  if (savedLogoBase64 != null && savedLogoBase64.isNotEmpty) {
    try {
      final Uint8List bytes = base64Decode(savedLogoBase64);
      try {
        LogoManager.instance.setLogoFromMemory(
          bytes,
          width: logoWidth,
          height: logoHeight,
          fit: BoxFit.contain,
        );
        debugPrint('applyEmpresaFromPrefs: logo aplicada a partir de prefs.');
      } catch (e) {
        debugPrint(
          'applyEmpresaFromPrefs: falha ao aplicar logo dos bytes: $e',
        );
      }
    } catch (e) {
      debugPrint('applyEmpresaFromPrefs: erro ao decodificar base64 -> $e');
    }
  } else {
    debugPrint(
      'applyEmpresaFromPrefs: sem logo salva, usando SizedBox(width: 1).',
    );
  }
}

// ---------------- Funções auxiliares ----------------



// ----------------------- MyApp -----------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CompatBio',
        theme: ThemeData(fontFamily: 'Fredoka'),
        home: const SideBarLogin(),
      ),
    );
  }
}

// ----------------------- AppLogo -----------------------
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({required this.size, super.key});

  @override
  Widget build(BuildContext context) {
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
}

// ----------------------- SideBarLogin -----------------------
class SideBarLogin extends StatefulWidget {
  const SideBarLogin({super.key});

  @override
  State<SideBarLogin> createState() => _SideBarLoginState();
}

class _SideBarLoginState extends State<SideBarLogin> {
  int selectedIndex = 0;

  final List<Widget> pages = const [LoginScreen(), CreateAccountScreen()];

  final List<String> labels = ["Entrar", "Cadastrar"];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;

    const desktopBreakpoint = 700.0;
    const bottomNavBreakpoint = 480.0;

    final bool isTopBarMode =
        screenWidth < desktopBreakpoint && screenWidth >= bottomNavBreakpoint;
    final bool isBottomNavMode = screenWidth < bottomNavBreakpoint;

    double sidebarWidth = screenWidth * 0.24;
    sidebarWidth = sidebarWidth.clamp(120.0, 360.0);

    final double sideButtonWidth = isTopBarMode
        ? (screenWidth * 0.45).clamp(120.0, 220.0)
        : (sidebarWidth * 0.82);
    final double sideButtonHeight = isTopBarMode ? 56.0 : 86.0;
    final double iconSize = isTopBarMode ? 20.0 : 24.0;
    final double fontSizeActive = isTopBarMode ? 16.0 : 20.0;
    final double fontSizeInactive = isTopBarMode ? 14.0 : 18.0;

    final gradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [ColorManager.instance.primary, ColorManager.instance.card],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    final BoxDecoration tabIndicatorDecoration = BoxDecoration(
      color: ColorManager.instance.text,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );

    // ---- MODO BOTTOM ----
    if (isBottomNavMode) {
      return DefaultTabController(
        length: pages.length,
        child: Scaffold(
          backgroundColor: const Color(0xFF2B2F2F),
          body: Column(
            children: [
              TopHeader(
                title: 'Olá! Bem-vindo(a)',
                subtitle: 'Faça login ou crie sua conta',
                leadingLogoSize: 50,
              ),
              Expanded(child: TabBarView(children: pages)),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: gradientDecoration,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: TabBar(
                    tabs: const [
                      Tab(icon: Icon(Icons.login_rounded), text: 'Entrar'),
                      Tab(
                        icon: Icon(Icons.person_add_rounded),
                        text: 'Cadastrar',
                      ),
                    ],
                    indicator: tabIndicatorDecoration,
                    indicatorPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: ColorManager.instance.primary,
                    unselectedLabelColor: ColorManager.instance.text
                        .withOpacity(0.9),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ---- MODO TOP BAR ----
    if (isTopBarMode) {
      return Scaffold(
        backgroundColor: const Color(0xFF2B2F2F),
        body: Column(
          children: [
            TopHeader(
              title: 'Seja bem-vindo(a)',
              subtitle: 'Acesse sua conta ou registre-se',
              leadingLogoSize: 56,
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.2, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                          ),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: pages[selectedIndex],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                decoration: gradientDecoration,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 72,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(labels.length, (index) {
                    return _SideButton(
                      icon: index == 0
                          ? Icons.login_rounded
                          : Icons.person_add_rounded,
                      label: labels[index],
                      active: selectedIndex == index,
                      onTap: () => setState(() => selectedIndex = index),
                      width: sideButtonWidth,
                      height: sideButtonHeight,
                      iconSize: iconSize,
                      fontSizeActive: fontSizeActive,
                      fontSizeInactive: fontSizeInactive,
                      isVertical: false,
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ---- MODO DESKTOP ----
    return Scaffold(
      backgroundColor: const Color(0xFF2B2F2F),
      body: Row(
        children: [
          SizedBox(
            width: sidebarWidth,
            child: CustomPaint(
              painter: SidebarBackgroundPainter(),
              child: Container(
                height: size.height,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SafeArea(
                      top: true,
                      bottom: false,
                      child: Builder(
                        builder: (context) {
                          final double logoSize = (sidebarWidth * 0.6).clamp(
                            80.0,
                            sidebarWidth * 0.98,
                          );
                          final double topAreaHeight = (logoSize * 1.05).clamp(
                            64.0,
                            240.0,
                          );

                          return SizedBox(
                            height: topAreaHeight,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: sidebarWidth * 0.9,
                                  maxHeight: topAreaHeight,
                                ),
                                child: SizedBox(
                                  width: logoSize,
                                  height: logoSize,
                                  child: AppLogo(size: logoSize),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(labels.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: _SideButton(
                                icon: index == 0
                                    ? Icons.login_rounded
                                    : Icons.person_add_rounded,
                                label: labels[index],
                                active: selectedIndex == index,
                                onTap: () =>
                                    setState(() => selectedIndex = index),
                                width: sideButtonWidth,
                                height: sideButtonHeight,
                                iconSize: iconSize,
                                fontSizeActive: fontSizeActive,
                                fontSizeInactive: fontSizeInactive,
                                isVertical: true,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: size.height,
              color: Colors.white,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0.2, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                        ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: pages[selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------- TopHeader -----------------------
class TopHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double? leadingLogoSize;

  const TopHeader({
    this.title = 'Bem-vindo',
    this.subtitle = 'Acesse sua conta',
    this.leadingLogoSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double logoSize = leadingLogoSize ?? 50;

    return SafeArea(
      bottom: false,
      child: Container(
        color: const Color(0xFF2B2F2F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: logoSize,
              height: logoSize,
              child: AppLogo(size: logoSize),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ColorManager.instance.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ColorManager.instance.text.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () async {
                // Exemplo: botão que dispara o refresh sem reiniciar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Atualizando preferências...')),
                );
                await RefreshWidget.refreshApp(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Atualização concluída.')),
                );
              },
              icon: const Icon(Icons.refresh_rounded),
              color: ColorManager.instance.text.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------- _SideButton -----------------------
class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double iconSize;
  final double fontSizeActive;
  final double fontSizeInactive;
  final bool isVertical;

  const _SideButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.width = 200,
    this.height = 90,
    this.iconSize = 24,
    this.fontSizeActive = 20,
    this.fontSizeInactive = 18,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    ColorManager.instance.text,
                    ColorManager.instance.text.withOpacity(0.96),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: isVertical
              ? const BorderRadius.only(
                  topLeft: Radius.circular(50),
                  bottomLeft: Radius.circular(50),
                )
              : BorderRadius.circular(24),
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
            color: active
                ? const Color(0xFF4B5B5B)
                : ColorManager.instance.text,
            fontWeight: FontWeight.bold,
            fontSize: active ? fontSizeActive : fontSizeInactive,
            letterSpacing: 1.2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: active
                    ? const Color(0xFF4B5B5B)
                    : ColorManager.instance.text,
              ),
              const SizedBox(width: 10),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------- SidebarBackgroundPainter -----------------------
class SidebarBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = LinearGradient(
        colors: [ColorManager.instance.primary, ColorManager.instance.card],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    final paint2 = Paint()
      ..shader = LinearGradient(
        colors: [
          ColorManager.instance.text.withOpacity(0.25),
          Colors.transparent,
        ],
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
        colors: [
          ColorManager.instance.text.withOpacity(0.15),
          Colors.transparent,
        ],
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
