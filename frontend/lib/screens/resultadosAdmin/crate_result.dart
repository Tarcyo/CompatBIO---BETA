// lib/screens/resultadosAdmin/crate_result.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:planos/screens/resultadosAdmin/product_simple.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../provider/userProvider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreateResultadoSheet extends StatefulWidget {
  final List<ProdutoSimple> biologicos;
  final List<ProdutoSimple> quimicos;
  const CreateResultadoSheet({
    super.key,
    required this.biologicos,
    required this.quimicos,
  });

  @override
  State<CreateResultadoSheet> createState() => _CreateResultadoSheetState();
}

class _CreateResultadoSheetState extends State<CreateResultadoSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedQuimico;
  String? _selectedBiologico;
  String _resultadoFinal = 'Compatível';
  final _descricaoCtrl = TextEditingController();

  bool _sending = false;
  String? _serverError;
  bool _showSuccess = false;

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.user?.token;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _serverError = null;
      _showSuccess = false;
    });

    final token = await _getTokenFromProvider();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _serverError = 'Usuário não autenticado.');
      return;
    }

    final body = {
      'nome_produto_quimico': _selectedQuimico,
      'nome_produto_biologico': _selectedBiologico,
      'resultado_final': _resultadoFinal,
      'descricao_resultado': _descricaoCtrl.text.trim().isEmpty
          ? null
          : _descricaoCtrl.text.trim(),
    };

    if (!mounted) return;
    setState(() => _sending = true);

    try {
      final resp = await http.post(
        Uri.parse('${dotenv.env['BASE_URL']}/resultados'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token}',
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        setState(() => _showSuccess = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      } else if (resp.statusCode == 400) {
        if (!mounted) return;
        setState(() => _serverError = 'Dados inválidos: ${(resp.body)}');
      } else if (resp.statusCode == 409) {
        if (!mounted) return;
        setState(
          () => _serverError = 'Resultado já existe para esse par de produtos.',
        );
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        if (!mounted) return;
        setState(
          () => _serverError = 'Acesso negado: você precisa ser Administrador.',
        );
      } else {
        if (!mounted) return;
        setState(() => _serverError = 'Erro ${resp.statusCode}: ${resp.body}');
      }
    } catch (e, st) {
      debugPrint('Erro ao criar resultado: $e\n$st');
      if (!mounted) return;
      setState(() => _serverError = 'Erro de rede: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(16));
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.36,
          maxChildSize: 0.92,
          builder: (context, scroll) {
            return Container(
              decoration: BoxDecoration(
                color: cm.background,
                borderRadius: radius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: ListView(
                controller: scroll,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cm.card.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Novo resultado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cm.explicitText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedQuimico,
                          decoration: InputDecoration(
                            labelText: 'Produto químico',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: cm.card.withOpacity(0.12),
                            labelStyle: TextStyle(color: cm.explicitText),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Selecione um químico'),
                            ),
                            ...widget.quimicos.map(
                              (p) => DropdownMenuItem(
                                value: p.nome,
                                child: Text(
                                  p.nome,
                                  style: TextStyle(color: cm.explicitText),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedQuimico = v),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Selecione um produto químico'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedBiologico,
                          decoration: InputDecoration(
                            labelText: 'Produto biológico',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: cm.card.withOpacity(0.12),
                            labelStyle: TextStyle(color: cm.explicitText),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Selecione um biológico'),
                            ),
                            ...widget.biologicos.map(
                              (p) => DropdownMenuItem(
                                value: p.nome,
                                child: Text(
                                  p.nome,
                                  style: TextStyle(color: cm.explicitText),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedBiologico = v),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Selecione um produto biológico'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _resultadoFinal,
                          decoration: InputDecoration(
                            labelText: 'Resultado final',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: cm.card.withOpacity(0.12),
                            labelStyle: TextStyle(color: cm.explicitText),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Compatível',
                              child: Text('Compatível'),
                            ),
                            DropdownMenuItem(
                              value: 'Incompatível',
                              child: Text('Incompatível'),
                            ),
                            DropdownMenuItem(
                              value: 'Parcial',
                              child: Text('Parcial'),
                            ),
                          ],
                          onChanged: (v) => setState(
                            () => _resultadoFinal = v ?? 'Compatível',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descricaoCtrl,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Descrição (opcional)',
                            hintText: 'Observações, procedimento, notas...',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: cm.card.withOpacity(0.12),
                            hintStyle: TextStyle(
                              color: cm.text.withOpacity(0.8),
                            ),
                            labelStyle: TextStyle(color: cm.explicitText),
                          ),
                          style: TextStyle(color: cm.explicitText),
                        ),
                        const SizedBox(height: 12),
                        if (_serverError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: cm.emergency,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _serverError!,
                                    style: TextStyle(color: cm.emergency),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _sending
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: cm.primary),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(color: cm.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _sending ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: cm.primary,
                                  foregroundColor: cm.text,
                                ),
                                child: _sending
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cm.text,
                                        ),
                                      )
                                    : _showSuccess
                                        ? Icon(Icons.check_rounded, color: cm.ok)
                                        : Text(
                                            'Criar resultado',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: cm.text,
                                            ),
                                          ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
