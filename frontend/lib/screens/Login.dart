import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/restPassword/resetPassword.dart';
import 'package:planos/screens/sidebarAdmin.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:planos/screens/sideBarInternp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Ajuste seguro para BASE_URL (não lança se não definido)
final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

/// Helper de logging para evitar truncamento e padronizar saída
const int _kWrapWidth = 1600;
void appLog(String tag, Object? message, [StackTrace? st]) {
  final msg = message == null ? '<null>' : message.toString();
  debugPrint('[$tag] $msg', wrapWidth: _kWrapWidth);
  if (st != null) {
    debugPrint('[$tag] STACKTRACE: $st', wrapWidth: _kWrapWidth);
  }
}

/// Busca a empresa vinculada ao usuário pelo token e aplica cor/ logo.
/// [baseUrl] é a URL base da sua API (ex: http://localhost:3000).
Future<void> fetchEmpresaAndApply({
  required String token,
  double logoWidth = 120,
  double logoHeight = 40,
}) async {
  final uri = Uri.parse('$baseUrl/empresas/me');
  const String prefKeyCor = 'empresa_corTema';
  const String prefKeyLogoBase64 = 'empresa_logo_base64';

  try {
    appLog('fetchEmpresaAndApply', 'GET $uri with token (bearer)');

    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    appLog('fetchEmpresaAndApply', 'status ${resp.statusCode}\nheaders: ${resp.headers}\nbody: ${resp.body}');

    if (resp.statusCode != 200) {
      appLog('fetchEmpresaAndApply', 'Resposta não-200: ${resp.statusCode}');
      return;
    }

    final Map<String, dynamic> jsonBody = json.decode(resp.body);
    final empresa = jsonBody['empresa'] as Map<String, dynamic>?;

    if (empresa == null) {
      appLog('fetchEmpresaAndApply', 'Sem campo "empresa" no retorno');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final String? corTema = (empresa['corTema'] as String?)?.trim();
    if (corTema != null && corTema.isNotEmpty) {
      try {
        final color = ColorManager.fromHex(corTema);
        ColorManager.instance.setColor(ColorRole.primary, color);
        ColorManager.instance.setColor(
          ColorRole.card,
          color.withValues(alpha: 0.8),
        );
        ColorManager.instance.setColor(
          ColorRole.highlightText,
          color.withValues(alpha: 0.7),
        );
        await prefs.setString(prefKeyCor, corTema);
        appLog('fetchEmpresaAndApply', 'cor aplicada e salva $corTema');
      } catch (e, st) {
        appLog('fetchEmpresaAndApply', 'falha ao converter corTema="$corTema": $e', st);
      }
    } else {
      appLog('fetchEmpresaAndApply', 'sem corTema no payload');
    }

    final dynamic logoField = empresa['logo'];
    if (logoField != null &&
        logoField is String &&
        logoField.trim().isNotEmpty) {
      String logoUrl = logoField.trim();

      if (logoUrl.startsWith('/')) {
        logoUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1) + logoUrl
            : baseUrl + logoUrl;
      } else if (!logoUrl.startsWith('http://') &&
          !logoUrl.startsWith('https://')) {
        logoUrl = baseUrl.endsWith('/')
            ? baseUrl + logoUrl
            : '$baseUrl/$logoUrl';
      }

      LogoManager.instance.setLogoFromNetwork(
        logoUrl,
        width: logoWidth,
        height: logoHeight,
        fit: BoxFit.contain,
      );
      appLog('fetchEmpresaAndApply', 'logo aplicada -> $logoUrl');

      try {
        final logoResp = await http.get(Uri.parse(logoUrl));
        appLog('fetchEmpresaAndApply', 'logo download status=${logoResp.statusCode}');
        if (logoResp.statusCode == 200) {
          final Uint8List logoBytes = logoResp.bodyBytes;
          final String logoBase64 = base64Encode(logoBytes);
          await prefs.setString(prefKeyLogoBase64, logoBase64);
          appLog('fetchEmpresaAndApply', 'logo baixada e salva em prefs (base64).');
        } else {
          appLog('fetchEmpresaAndApply', 'falha ao baixar logo para salvar (status=${logoResp.statusCode}).');
        }
      } catch (e, st) {
        appLog('fetchEmpresaAndApply', 'erro ao baixar logo -> $e', st);
      }
    } else {
      await prefs.remove(prefKeyLogoBase64);
      LogoManager.instance.resetDefault();
      appLog('fetchEmpresaAndApply', 'sem logo, reset para default e removido pref de logo');
    }
  } catch (err, st) {
    appLog('fetchEmpresaAndApply', 'erro -> $err', st);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _remember = false;
  final SideBarController sideBarController = SideBarController();

  String? _errorMessage; // mostra erro na tela

  // secure storage para credenciais
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _kEmail = 'secure_email';
  static const String _kPassword = 'secure_password';
  static const String _kRemember = 'secure_remember';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final rememberVal = await _secureStorage.read(key: _kRemember);
      final remember = rememberVal == 'true';
      if (!mounted) return;
      if (!remember) {
        setState(() {
          _remember = false;
        });
        return;
      }

      final savedEmail = await _secureStorage.read(key: _kEmail);
      final savedPass = await _secureStorage.read(key: _kPassword);

      setState(() {
        _remember = true;
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _emailCtrl.text = savedEmail;
        }
        if (savedPass != null && savedPass.isNotEmpty) {
          _passCtrl.text = savedPass;
        }
      });
      appLog('loadSavedCredentials', 'carregadas credenciais (remember=true)');
    } catch (e, st) {
      appLog('loadSavedCredentials', 'Erro ao carregar credenciais salvas: $e', st);
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _kEmail, value: email);
      await _secureStorage.write(key: _kPassword, value: password);
      await _secureStorage.write(key: _kRemember, value: 'true');
      appLog('saveCredentials', 'salvo email e senha no secure storage (lembrar=true)');
    } catch (e, st) {
      appLog('saveCredentials', 'Erro ao salvar credenciais seguras: $e', st);
    }
  }

  Future<void> _deleteSavedCredentials() async {
    try {
      await _secureStorage.delete(key: _kEmail);
      await _secureStorage.delete(key: _kPassword);
      await _secureStorage.delete(key: _kRemember);
      appLog('deleteSavedCredentials', 'credenciais removidas do secure storage');
    } catch (e, st) {
      appLog('deleteSavedCredentials', 'Erro ao remover credenciais seguras: $e', st);
    }
  }

  /// SUBMIT com logging completo de request/response e erros
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final uriStr = '$baseUrl/usuarios/login';
    final uri = Uri.parse(uriStr);
    final requestBody = {
      'email': _emailCtrl.text.trim(),
      'senha': _passCtrl.text.trim(),
    };
    final headers = {'Content-Type': 'application/json'};

    try {
      // Log completo do request
      appLog('REQUEST', 'POST $uriStr');
      appLog('REQUEST', 'Headers: ${jsonEncode(headers)}');
      appLog('REQUEST', 'Body: ${const JsonEncoder.withIndent('  ').convert(requestBody)}');

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      // Log completo do response
      appLog('RESPONSE', 'statusCode: ${response.statusCode}');
      appLog('RESPONSE', 'headers: ${response.headers}');
      appLog('RESPONSE', 'body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final userMap = data['user'] as Map<String, dynamic>?;

        final empresaMap = userMap != null && userMap['empresa'] != null
            ? (userMap['empresa'] as Map<String, dynamic>?)
            : null;

        final empresaNome = empresaMap != null && empresaMap['nome'] != null
            ? empresaMap['nome'].toString()
            : null;

        final userProvider = Provider.of<UserProvider>(context, listen: false);

        userProvider.setUser(
          User(
            id: userMap?['id'],
            nome: userMap?['nome'],
            email: userMap?['email'],
            tipoUsuario: userMap?['tipo_usuario'],
            empresa: empresaNome,
            token: data['token'],
          ),
        );

        if (_remember) {
          await _saveCredentials(_emailCtrl.text.trim(), _passCtrl.text);
        } else {
          await _deleteSavedCredentials();
        }

        try {
          final tokenStr = data['token']?.toString() ?? '';
          if (tokenStr.isNotEmpty) {
            await fetchEmpresaAndApply(token: tokenStr);
          }
        } catch (e, st) {
          appLog('fetchEmpresaAndApply', 'Erro ao aplicar empresa: $e', st);
        }

        final tipo = (userMap?['tipo_usuario'] ?? '').toString();

        if (tipo == 'Cliente') {
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 350),
              pageBuilder: (_, animation, __) =>
                  SideBarInterno(controller: sideBarController),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        } else {
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 350),
              pageBuilder: (_, animation, __) => const SideBarInternoAdmin(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } else {
        // tenta extrair erro do body (se for json) e loga com indentação
        try {
          final error = jsonDecode(response.body);
          final pretty = const JsonEncoder.withIndent('  ').convert(error);
          appLog('ERROR_BODY', pretty);
          setState(() {
            _errorMessage = error['error']?.toString() ?? 'Erro no login';
          });
        } catch (e) {
          appLog('ERROR_BODY', 'Body não-JSON: ${response.body}');
          setState(() {
            _errorMessage = 'Erro no login (status ${response.statusCode})';
          });
        }
      }
    } catch (e, st) {
      // Log completo da exceção+stacktrace
      appLog('EXCEPTION', 'Falha na conexão ou erro durante request: $e', st);
      setState(() {
        _errorMessage = 'Falha na conexão: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ResetPasswordEmailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.instance.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final cardWidth = max(
              320.0,
              min(1100.0, maxW * (maxW < 600 ? 0.95 : 0.6)),
            );
            final scale = (cardWidth / 380).clamp(0.82, 1.4);
            final horizontalPadding = max(12.0, (maxW * 0.03));

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: max(320, cardWidth + 40),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Card com HEADER integrado no topo (já não "flutua")
                      Card(
                        color: ColorManager.instance.card.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide(
                            color: ColorManager.instance.card.withOpacity(0.6),
                            width: 1.2,
                          ),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header: parte superior do card — recorta cantos superiores
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                              child: _cardHeader(scale),
                            ),

                            // Conteúdo do card (form) com padding consistente
                            Padding(
                              padding: EdgeInsets.all(16 * scale),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: cardWidth),
                                child: _buildFormPanel(scale, context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 18 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [SizedBox(width: 6)],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormPanel(double scale, BuildContext context) {
    // NOTE: _cardHeader foi movido para o topo do Card (build). Aqui mantemos somente
    // o corpo do formulário/inputs e botões — NÃO alterei nenhuma lógica.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pequeno espaçamento/linha separadora logo abaixo do header
    

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  label: 'Email',
                  icon: Icons.email_rounded,
                  hint: 'seu@exemplo.com',
                ),
                style: TextStyle(
                  fontSize: 14 * scale,
                  color: ColorManager.instance.explicitText,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe seu email';
                  final re = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w{2,}");
                  if (!re.hasMatch(v.trim())) return 'Email inválido';
                  return null;
                },
              ),
              SizedBox(height: 12 * scale),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: _inputDecoration(
                  label: 'Senha',
                  icon: Icons.lock_rounded,
                  hint: 'Sua senha',
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14 * scale,
                  color: ColorManager.instance.explicitText,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe a senha';
                  if (v.length < 6) return 'Senha muito curta';
                  return null;
                },
              ),
              SizedBox(height: 12 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22 * scale,
                        height: 22 * scale,
                        child: Checkbox(
                          value: _remember,
                          onChanged: (v) =>
                              setState(() => _remember = v ?? false),
                        ),
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        'Lembrar-me',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13 * scale,
                          color: ColorManager.instance.explicitText,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      'Esqueceu sua senha?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13 * scale,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: ColorManager.instance.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size(0, 0),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18 * scale),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  backgroundColor: ColorManager.instance.primary,
                  foregroundColor: ColorManager.instance.text,
                ),
                child: _loading
                    ? SizedBox(
                        height: 18 * scale,
                        width: 18 * scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ColorManager.instance.text,
                        ),
                      )
                    : Text(
                        'Entrar',
                        style: TextStyle(
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: ColorManager.instance.emergency,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Header estilizado para o card central
  Widget _cardHeader(double scale) {
    final cm = ColorManager.instance;
    final primary = cm.primary;
    // contrasta o texto do header com a cor primária
    final fg = primary.computeLuminance() > 0.56 ? Colors.black : Colors.white;
    final mid = HSLColor.fromColor(primary).withLightness((HSLColor.fromColor(primary).lightness - 0.06).clamp(0.0, 1.0)).toColor();
    final end = HSLColor.fromColor(primary).withLightness((HSLColor.fromColor(primary).lightness - 0.16).clamp(0.0, 1.0)).toColor();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, mid, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 14 * scale),
      child: Row(
        children: [
          // logo / emblema pequeno (usa LogoManager se disponível)
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.login_rounded, color: fg, size: 22 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrar',
                  style: TextStyle(
                    color: fg,
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              
              ],
            ),
          ),
          // Ajuda (mantive comportamento vazio conforme original)
       
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffix,
}) {
  return InputDecoration(
    prefixIcon: Icon(icon, color: ColorManager.instance.primary),
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  );
}
