import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// ---------- LogoManager ----------
/// Gerencia a logo da aplicação (singleton + ChangeNotifier).
class LogoManager extends ChangeNotifier {
  // Singleton
  static final LogoManager instance = LogoManager._internal();

  // valor padrão: usa o asset 'assets/icon.png' sem width/height fixos
  // e com BoxFit.contain para não cortar a imagem.
  static final Widget _defaultLogo = Image.asset(
    'assets/icon.png',
    fit: BoxFit.contain,
  );

  // estado privado
  Widget _logo;

  LogoManager._internal() : _logo = _defaultLogo;

  Widget get logo => _logo;

  /// Substitui a logo por um widget qualquer e notifica ouvintes.
  void setLogo(Widget newLogo) {
    _logo = newLogo;
    notifyListeners();
  }

  /// Conveniência: define a logo a partir de um asset.
  void setLogoFromAsset(String assetName, {double? width, double? height, BoxFit? fit}) {
    final image = Image.asset(
      assetName,
      width: width,
      height: height,
      fit: fit ?? BoxFit.contain,
    );
    setLogo(image);
  }

  /// Conveniência: define a logo a partir de uma URL.
  void setLogoFromNetwork(String url, {double? width, double? height, BoxFit? fit}) {
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit ?? BoxFit.contain,
    );
    setLogo(image);
  }

  /// Conveniência: define a logo a partir de bytes em memória (Uint8List).
  void setLogoFromMemory(Uint8List bytes, {double? width, double? height, BoxFit? fit}) {
    try {
      final image = Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
      );
      setLogo(image);
    } catch (e) {
      debugPrint('LogoManager.setLogoFromMemory: falha ao criar Image.memory -> $e');
    }
  }

  /// Restaura o valor padrão.
  void resetDefault() {
    _logo = _defaultLogo;
    notifyListeners();
  }
}

/// Getter top-level para acessar a logo atual rapidamente.
Widget get logo => LogoManager.instance.logo;

/// ---------- ColorRole e ColorManager ----------

enum ColorRole {
  primary,
  card,
  text,
  highlightText,
  alert,
  emergency,
  ok,
  background,
  explicitText,
}

class ColorManager extends ChangeNotifier {
  // Singleton
  static final ColorManager instance = ColorManager._internal();

  // valores padrão
  static const Color _defaultPrimary = Colors.green;
  static const Color _defaultCard = Colors.green;
  static const Color _defaultText = Colors.white;
  static const Color _defaultHighlightText = Colors.purple;
  static const Color _defaultAlert = Colors.amber;
  static const Color _defaultEmergency = Colors.red;
  static const Color _defaultOk = Colors.greenAccent;
  static const Color _defaultBackground = Colors.white;
  static const Color _defaultExplicitText = Colors.black;

  // estados mutáveis
  Color primary;
  Color card;
  Color text;
  Color highlightText;
  Color alert;
  Color emergency;
  Color ok;
  Color background;
  Color explicitText;

  ColorManager._internal()
      : primary = _defaultPrimary,
        card = _defaultCard,
        text = _defaultText,
        highlightText = _defaultHighlightText,
        alert = _defaultAlert,
        emergency = _defaultEmergency,
        ok = _defaultOk,
        background = _defaultBackground,
        explicitText = _defaultExplicitText;

  void setColor(ColorRole role, Color color) {
    switch (role) {
      case ColorRole.primary:
        primary = color;
        break;
      case ColorRole.card:
        card = color;
        break;
      case ColorRole.text:
        text = color;
        break;
      case ColorRole.highlightText:
        highlightText = color;
        break;
      case ColorRole.alert:
        alert = color;
        break;
      case ColorRole.emergency:
        emergency = color;
        break;
      case ColorRole.ok:
        ok = color;
        break;
      case ColorRole.background:
        background = color;
        break;
      case ColorRole.explicitText:
        explicitText = color;
        break;
    }
    notifyListeners();
  }

  void updateAll({
    Color? primary,
    Color? card,
    Color? text,
    Color? highlightText,
    Color? alert,
    Color? emergency,
    Color? ok,
    Color? background,
    Color? explicitText,
  }) {
    if (primary != null) this.primary = primary;
    if (card != null) this.card = card;
    if (text != null) this.text = text;
    if (highlightText != null) this.highlightText = highlightText;
    if (alert != null) this.alert = alert;
    if (emergency != null) this.emergency = emergency;
    if (ok != null) this.ok = ok;
    if (background != null) this.background = background;
    if (explicitText != null) this.explicitText = explicitText;
    notifyListeners();
  }

  void resetDefaults() {
    primary = _defaultPrimary;
    card = _defaultCard;
    text = _defaultText;
    highlightText = _defaultHighlightText;
    alert = _defaultAlert;
    emergency = _defaultEmergency;
    ok = _defaultOk;
    background = _defaultBackground;
    explicitText = _defaultExplicitText;
    notifyListeners();
  }

  static Color fromHex(String hexString) {
    final hex = hexString.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    } else {
      throw FormatException('Formato hex inválido. Use RRGGBB ou AARRGGBB');
    }
  }

  Map<String, Color> toMap() {
    return {
      'primary': primary,
      'card': card,
      'text': text,
      'highlightText': highlightText,
      'alert': alert,
      'emergency': emergency,
      'ok': ok,
      'background': background,
      'explicitText': explicitText,
    };
  }

  ThemeData toThemeData() {
    final colorScheme = ColorScheme.light(
      primary: primary,
      secondary: card,
      onPrimary: text,
      surface: card,
      background: background,
      onBackground: text,
    );

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: primary,
      cardColor: card,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(backgroundColor: primary, foregroundColor: text),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        titleLarge: TextStyle(color: highlightText),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: alert,
        contentTextStyle: TextStyle(color: text),
      ),
    );
  }
}

/// ---------- LogoWidget (bem maior, seguro) ----------
/// Widget que exibe a logo sem cortá-la, agora preparado para maiores dimensões.
///
/// Parâmetros:
///  - maxFraction: fração do espaço disponível que a logo pode usar (0.0..1.0)
///  - maxDimension: limite em pixels para largura/altura (usado para permitir logos muito grandes)
///
/// NOTE: aqui usamos default maxFraction bem alto e um maxDimension grande (1200 px)
/// para atender ao pedido "aumente mais! mais mais!" mantendo proteção contra corte.
class LogoWidget extends StatelessWidget {
  /// Porcentagem do espaço disponível que a logo pode ocupar (0.0..1.0).
  final double maxFraction;

  /// Máximo tamanho em pixels (width/height) que a logo pode ocupar.
  final double? maxDimension;

  /// Padding opcional ao redor da logo.
  final EdgeInsetsGeometry padding;

  const LogoWidget({
    Key? key,
    this.maxFraction = 0.99,
    this.maxDimension = 1200.0,
    this.padding = const EdgeInsets.all(8.0),
  })  : assert(maxFraction > 0 && maxFraction <= 1.0),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LogoManager.instance,
      builder: (context, _) {
        final Widget currentLogo = LogoManager.instance.logo;

        return Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Detecta disponibilidade de espaço
              final availableWidth = constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;
              final availableHeight = constraints.hasBoundedHeight ? constraints.maxHeight : double.infinity;

              final maxWidth = (availableWidth.isFinite) ? availableWidth * maxFraction : double.infinity;
              final maxHeight = (availableHeight.isFinite) ? availableHeight * maxFraction : double.infinity;

              // Calcula boxSize como o menor lado para preservar aspect ratio e evitar corte.
              double boxSize = math.min(maxWidth, maxHeight);

              // Aplica o limite explícito (grande) para permitir logos enormes quando houver espaço.
              if (maxDimension != null) {
                boxSize = math.min(boxSize, maxDimension!);
              }

              // Se ainda for infinito (ex.: layout sem bounds), definimos fallback generoso.
              if (!boxSize.isFinite) {
                boxSize = maxDimension ?? 1200.0;
              }

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: boxSize,
                    maxHeight: boxSize,
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: currentLogo,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// ---------- Exemplo de uso (main) ----------
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    ColorManager.instance.addListener(_onColorChange);
  }

  @override
  void dispose() {
    ColorManager.instance.removeListener(_onColorChange);
    super.dispose();
  }

  void _onColorChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo Logo Manager - Super Grande',
      theme: ColorManager.instance.toThemeData(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Logo MUITO maior sem corte'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Aqui pedimos que a logo ocupe até 99% do espaço disponível,
            // com máximo absoluto de 1200 pixels — bem grande.
            Expanded(
              flex: 3,
              child: Container(
                color: ColorManager.instance.background,
                child: const LogoWidget(maxFraction: 0.99, maxDimension: 1200.0, padding: EdgeInsets.symmetric(vertical: 12.0)),
              ),
            ),

            // Painel de controles para demonstrar trocas de logo e cores:
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        const Text('Controles de demonstração'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Exemplo: trocar para outra asset (assegure-se que existe)
                            LogoManager.instance.setLogoFromAsset('assets/logo.png');
                          },
                          child: const Text('Usar assets/logo.png'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Restaura a logo padrão
                            LogoManager.instance.resetDefault();
                          },
                          child: const Text('Restaurar logo padrão'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Exemplo simples de troca de cor primária
                            ColorManager.instance.setColor(ColorRole.primary, Colors.deepPurple);
                            ColorManager.instance.setColor(ColorRole.background, Colors.grey.shade100);
                          },
                          child: const Text('Trocar paleta (demo)'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Dica: se quiser ainda maior, aumente maxDimension (ex.: 1600.0)\n' +
                              'ou ajuste maxFraction (ex.: 1.0) — o widget ainda respeita o\n' +
                              'espaço disponível e usa BoxFit.contain para evitar cortes.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
