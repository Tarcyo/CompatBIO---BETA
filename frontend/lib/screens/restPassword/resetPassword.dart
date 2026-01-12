// lib/screens/reset_password_flow.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:planos/styles/syles.dart'; // seu ColorManager e estilos
import 'package:flutter_dotenv/flutter_dotenv.dart';

Map<String, double> _responsiveParams(double width) {
  if (width >= 1000) {
    return {'scale': 1.6, 'pad': 40.0, 'cardW': 900.0};
  } else if (width >= 600) {
    return {'scale': 1.25, 'pad': 28.0, 'cardW': 700.0};
  } else {
    return {'scale': 1.0, 'pad': 16.0, 'cardW': width * 0.95};
  }
}

final String _baseUrl = '${dotenv.env['BASE_URL']}/resetPassword';







// ---------------- ResetPasswordEmailScreen ----------------
class ResetPasswordEmailScreen extends StatefulWidget {
  const ResetPasswordEmailScreen({super.key});

  @override
  State<ResetPasswordEmailScreen> createState() =>
      _ResetPasswordEmailScreenState();
}

class _ResetPasswordEmailScreenState extends State<ResetPasswordEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onEnviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = _emailCtrl.text.trim().toLowerCase();
    try {
      final resp = await http.post(
        Uri.parse("$_baseUrl/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      ).timeout(const Duration(seconds: 10));

      String message = "Se o e-mail existir, um código foi enviado.";
      if (resp.statusCode >= 400) {
        // tenta extrair mensagem do backend, senão usa genérica
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && body["error"] != null) {
            message = body["error"].toString();
          }
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      // navega para tela de código mesmo que o backend responda 400 para não vazar existência
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, animation, __) =>
              EnterCodeScreen(email: email),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de rede. Tente novamente.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final params = _responsiveParams(constraints.maxWidth);
        final scale = params['scale']!;
        final pad = params['pad']!;
        final cardMaxW = params['cardW']!;

        return Scaffold(
          backgroundColor: ColorManager.instance.background,
          body: Stack(
            children: [
              Positioned(
                top: pad / 2,
                left: pad / 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_rounded,
                      size: 18.0 * scale, color: ColorManager.instance.text),
                  label: Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 13.0 * scale,
                      fontWeight: FontWeight.w800,
                      color: ColorManager.instance.text,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.0 * scale,
                      vertical: 8.0 * scale,
                    ),
                    backgroundColor: ColorManager.instance.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0 * scale),
                    ),
                  ),
                ),
              ),

              // conteúdo central
              Center(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: pad, vertical: 20.0 * scale),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxW),
                    child: Card(
                      color: ColorManager.instance.card.withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20 * scale),
                        side: BorderSide(
                          color: ColorManager.instance.card.withOpacity(0.6),
                          width: 1.2 * scale,
                        ),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(18.0 * scale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_reset_rounded,
                                    color: ColorManager.instance.primary,
                                    size: 30.0 * scale),
                                SizedBox(width: 10.0 * scale),
                                Expanded(
                                  child: Text(
                                    'Refatoração de senha',
                                    style: TextStyle(
                                      fontSize: 20.0 * scale,
                                      fontWeight: FontWeight.w900,
                                      color: ColorManager.instance.explicitText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14.0 * scale),
                            Divider(height: 18.0 * scale),
                            SizedBox(height: 12.0 * scale),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: sharedInputDecoration(
                                      label: 'Email',
                                      icon: Icons.email_rounded,
                                      hint: 'seu@exemplo.com',
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Informe seu email';
                                      }
                                      final re =
                                          RegExp(r"^[\w\.-]+@[\w\.-]+\.\w{2,}");
                                      if (!re.hasMatch(v.trim())) {
                                        return 'Email inválido';
                                      }
                                      return null;
                                    },
                                    style: TextStyle(
                                      fontSize: 14.0 * scale,
                                      color: ColorManager.instance.explicitText,
                                    ),
                                  ),
                                  SizedBox(height: 18.0 * scale),
                                  SizedBox(
                                    height: 48.0 * scale,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _onEnviar,
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.0 * scale),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(36.0 * scale),
                                        ),
                                        backgroundColor:
                                            ColorManager.instance.primary,
                                        foregroundColor:
                                            ColorManager.instance.text,
                                        textStyle: TextStyle(
                                          fontSize: 16.0 * scale,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      child: _loading
                                          ? SizedBox(
                                              height: 18.0 * scale,
                                              width: 18.0 * scale,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                                color: ColorManager.instance.text,
                                              ),
                                            )
                                          : const Text('Enviar'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------- EnterCodeScreen (temporizador) ----------------
class EnterCodeScreen extends StatefulWidget {
  final String email;
  const EnterCodeScreen({required this.email, super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final TextEditingController _codeCtrl = TextEditingController();
  Timer? _timer;
  int _remaining = 60;
  bool _sending = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        setState(() {});
      } else {
        setState(() => _remaining--);
      }
    });
  }

  String _formatTime() {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _onEnviarCodigo() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código recebido.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final resp = await http.post(
        Uri.parse("$_baseUrl/verify-reset-code"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email, "code": code}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final token = body['token'] as String?;
        if (token == null) {
          throw Exception("Token não retornado");
        }
        if (!mounted) return;
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, animation, __) =>
                NewPasswordScreen(token: token),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      } else {
        String msg = "Código inválido ou expirado.";
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && body["error"] != null) msg = body["error"].toString();
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de rede. Tente novamente.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _onReenviar() async {
    if (_remaining > 0) return;
    setState(() => _resending = true);
    try {
      final resp = await http.post(
        Uri.parse("$_baseUrl/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      ).timeout(const Duration(seconds: 10));

      String message = "Se o e-mail existir, um código foi reenviado.";
      if (resp.statusCode >= 400) {
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && body["error"] != null) {
            message = body["error"].toString();
          }
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de rede. Tente novamente.')));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final params = _responsiveParams(constraints.maxWidth);
        final scale = params['scale']!;
        final pad = params['pad']!;
        final cardMaxW = params['cardW']!;

        return Scaffold(
          backgroundColor: ColorManager.instance.background,
          body: Stack(
            children: [
              Positioned(
                top: pad / 2,
                left: pad / 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_rounded,
                      size: 18.0 * scale, color: ColorManager.instance.text),
                  label: Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 13.0 * scale,
                      fontWeight: FontWeight.w800,
                      color: ColorManager.instance.text,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.0 * scale,
                      vertical: 8.0 * scale,
                    ),
                    backgroundColor: ColorManager.instance.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0 * scale),
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: pad, vertical: 20.0 * scale),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxW),
                    child: Card(
                      color: ColorManager.instance.card.withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20 * scale),
                        side: BorderSide(
                          color: ColorManager.instance.card.withOpacity(0.6),
                          width: 1.2 * scale,
                        ),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(18.0 * scale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.email_rounded,
                                    color: ColorManager.instance.primary,
                                    size: 30.0 * scale),
                                SizedBox(width: 10.0 * scale),
                                Expanded(
                                  child: Text(
                                    'Insira o código enviado',
                                    style: TextStyle(
                                      fontSize: 20.0 * scale,
                                      fontWeight: FontWeight.w900,
                                      color: ColorManager.instance.explicitText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.0 * scale),
                            Text(
                              'Um código foi enviado para: ${widget.email}',
                              style: TextStyle(
                                fontSize: 13.0 * scale,
                                color: ColorManager.instance.explicitText,
                              ),
                            ),
                            SizedBox(height: 12.0 * scale),
                            Row(
                              children: [
                                Text(
                                  'Tempo restante: ',
                                  style: TextStyle(
                                    fontSize: 13.0 * scale,
                                    color: ColorManager.instance.explicitText,
                                  ),
                                ),
                                Text(
                                  _formatTime(),
                                  style: TextStyle(
                                    fontSize: 14.0 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: _remaining > 0
                                        ? ColorManager.instance.primary
                                        : ColorManager.instance.emergency,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.0 * scale),
                            TextField(
                              controller: _codeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: sharedInputDecoration(
                                label: 'Código',
                                icon: Icons.confirmation_num_rounded,
                                hint: '000000',
                              ),
                              style: TextStyle(fontSize: 14.0 * scale),
                            ),
                            SizedBox(height: 16.0 * scale),
                            SizedBox(
                              height: 44.0 * scale,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _sending ? null : _onEnviarCodigo,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 12.0 * scale),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(36.0 * scale),
                                  ),
                                  backgroundColor: ColorManager.instance.primary,
                                  foregroundColor: ColorManager.instance.text,
                                  textStyle: TextStyle(
                                    fontSize: 15.0 * scale,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                child: _sending
                                    ? SizedBox(
                                        height: 16.0 * scale,
                                        width: 16.0 * scale,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          color: ColorManager.instance.text,
                                        ),
                                      )
                                    : const Text('Enviar'),
                              ),
                            ),
                            SizedBox(height: 8.0 * scale),
                            TextButton(
                              onPressed:
                                  (_remaining > 0 || _resending) ? null : _onReenviar,
                              child: _resending
                                  ? SizedBox(
                                      height: 16.0 * scale,
                                      width: 16.0 * scale,
                                      child: CircularProgressIndicator(strokeWidth: 2.0),
                                    )
                                  : Text(
                                      _remaining > 0
                                          ? 'Reenviar código (aguarde)'
                                          : 'Reenviar código',
                                      style: TextStyle(
                                        fontSize: 13.0 * scale,
                                        fontWeight: FontWeight.w700,
                                        color: _remaining > 0
                                            ? ColorManager.instance.card.withOpacity(0.6)
                                            : ColorManager.instance.primary,
                                      ),
                                    ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------- NewPasswordScreen ----------------
class NewPasswordScreen extends StatefulWidget {
  final String token;
  const NewPasswordScreen({required this.token, super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _onConfirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final newPassword = _newCtrl.text;
    try {
      final resp = await http.post(
        Uri.parse("$_baseUrl/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": widget.token, "newPassword": newPassword}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha atualizada com sucesso.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        String msg = "Falha ao atualizar senha.";
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && body["error"] != null) msg = body["error"].toString();
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de rede. Tente novamente.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final params = _responsiveParams(constraints.maxWidth);
        final scale = params['scale']!;
        final pad = params['pad']!;
        final cardMaxW = params['cardW']!;

        return Scaffold(
          backgroundColor: ColorManager.instance.background,
          body: Stack(
            children: [
              Positioned(
                top: pad / 2,
                left: pad / 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_rounded,
                      size: 18.0 * scale, color: ColorManager.instance.text),
                  label: Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 13.0 * scale,
                      fontWeight: FontWeight.w800,
                      color: ColorManager.instance.text,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.0 * scale,
                      vertical: 8.0 * scale,
                    ),
                    backgroundColor: ColorManager.instance.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0 * scale),
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: pad, vertical: 20.0 * scale),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxW),
                    child: Card(
                      color: ColorManager.instance.card.withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20 * scale),
                        side: BorderSide(
                          color: ColorManager.instance.card.withOpacity(0.6),
                          width: 1.2 * scale,
                        ),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(18.0 * scale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.key_rounded,
                                    color: ColorManager.instance.primary,
                                    size: 30.0 * scale),
                                SizedBox(width: 10.0 * scale),
                                Expanded(
                                  child: Text(
                                    'Nova senha',
                                    style: TextStyle(
                                      fontSize: 20.0 * scale,
                                      fontWeight: FontWeight.w900,
                                      color: ColorManager.instance.explicitText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.0 * scale),
                            Divider(height: 16.0 * scale),
                            SizedBox(height: 12.0 * scale),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _newCtrl,
                                    obscureText: _obscure,
                                    decoration: sharedInputDecoration(
                                      label: 'Nova senha',
                                      icon: Icons.lock_rounded,
                                      hint: 'Sua nova senha',
                                      suffix: IconButton(
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Informe a nova senha';
                                      }
                                      if (v.length < 8) {
                                        return 'Senha muito curta (mínimo 8 caracteres)';
                                      }
                                      return null;
                                    },
                                    style: TextStyle(
                                      fontSize: 14.0 * scale,
                                      color: ColorManager.instance.explicitText,
                                    ),
                                  ),
                                  SizedBox(height: 18.0 * scale),
                                  SizedBox(
                                    height: 44.0 * scale,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _onConfirmar,
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.0 * scale),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(36.0 * scale),
                                        ),
                                        backgroundColor:
                                            ColorManager.instance.primary,
                                        foregroundColor:
                                            ColorManager.instance.text,
                                        textStyle: TextStyle(
                                          fontSize: 15.0 * scale,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      child: _loading
                                          ? SizedBox(
                                              height: 16.0 * scale,
                                              width: 16.0 * scale,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                                color: ColorManager.instance.text,
                                              ),
                                            )
                                          : const Text('Confirmar'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// --------------- Shared input decoration ----------------
InputDecoration sharedInputDecoration({
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
