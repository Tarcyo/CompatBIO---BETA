// FILE: lib/widgets/plano_inline_form.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/listaDePlanos/plano_class.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class PlanoInlineForm extends StatefulWidget {
  final String baseUrl;
  final Plano? existing;
  final void Function(bool ok)? onSaved;
  final VoidCallback? onCancel;

  const PlanoInlineForm({
    Key? key,
    required this.baseUrl,
    this.existing,
    this.onSaved,
    this.onCancel,
  }) : super(key: key);

  @override
  State<PlanoInlineForm> createState() => _PlanoInlineFormState();
}

class _PlanoInlineFormState extends State<PlanoInlineForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeCtrl = TextEditingController();
  final TextEditingController _prioridadeCtrl = TextEditingController();
  final TextEditingController _quantidadeCtrl = TextEditingController();
  final TextEditingController _precoCtrl = TextEditingController();

  // NOVO: controller para o stripe price id (opcional)
  final TextEditingController _stripePriceCtrl = TextEditingController();

  // NOVO: controller para máximo de colaboradores (inteiro >= 0; 0 => ilimitado)
  final TextEditingController _maxColCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nomeCtrl.text = widget.existing!.nome;
      _prioridadeCtrl.text = widget.existing!.prioridadeDeTempo.toString();
      _quantidadeCtrl.text = widget.existing!.quantidadeCreditoMensal.toString();
      _precoCtrl.text = widget.existing!.precoMensal;
      // preenche maximo colaboradores se disponível no modelo Plano
      try {
        _maxColCtrl.text = widget.existing!.maximoColaboradores.toString();
      } catch (_) {
        _maxColCtrl.text = '0';
      }
      // NOTE: Plano class might not contain stripe price id property.
      // We intentionally do not try to access a possibly-nonexistent property here
      // to avoid compile errors. If your Plano class contains a field such as
      // stripePriceId or stripe_price_id, you can set it here.
    } else {
      _maxColCtrl.text = '0';
    }
  }

  @override
  void didUpdateWidget(covariant PlanoInlineForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.existing != oldWidget.existing) {
      if (widget.existing != null) {
        _nomeCtrl.text = widget.existing!.nome;
        _prioridadeCtrl.text = widget.existing!.prioridadeDeTempo.toString();
        _quantidadeCtrl.text = widget.existing!.quantidadeCreditoMensal.toString();
        _precoCtrl.text = widget.existing!.precoMensal;
        try {
          _maxColCtrl.text = widget.existing!.maximoColaboradores.toString();
        } catch (_) {
          _maxColCtrl.text = '0';
        }
        // same note as above about stripe id prefill
      } else {
        _nomeCtrl.clear();
        _prioridadeCtrl.clear();
        _quantidadeCtrl.clear();
        _precoCtrl.clear();
        _stripePriceCtrl.clear();
        _maxColCtrl.text = '0';
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _prioridadeCtrl.dispose();
    _quantidadeCtrl.dispose();
    _precoCtrl.dispose();
    _stripePriceCtrl.dispose();
    _maxColCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (userProv.user == null) return null;
    return userProv.user!.token;
  }

  int _parseNonNegativeInt(String? s, [int fallback = 0]) {
    if (s == null || s.trim().isEmpty) return fallback;
    final p = int.tryParse(s.trim());
    if (p == null || p < 0) return fallback;
    return p;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final token = await _getTokenFromProvider();
    if (token == null) {
      _showSnack('Usuário não autenticado');
      setState(() => _submitting = false);
      return;
    }

    final nome = _nomeCtrl.text.trim();
    final prioridade = int.tryParse(_prioridadeCtrl.text.trim()) ?? 0;
    final quantidade = int.tryParse(_quantidadeCtrl.text.trim()) ?? 0;
    final preco = _precoCtrl.text.trim();
    final stripePriceIdRaw = _stripePriceCtrl.text.trim();
    final stripePriceId = stripePriceIdRaw.isEmpty ? null : stripePriceIdRaw;
    final maxCol = _parseNonNegativeInt(_maxColCtrl.text.trim(), 0);

    try {
      if (widget.existing == null) {
        final Map<String, dynamic> payload = {
          'nome': nome,
          'prioridade_de_tempo': prioridade,
          'quantidade_credito_mensal': quantidade,
          'preco_mensal': preco,
          // incluir stripe_price_id (pode ser null)
          'stripe_price_id': stripePriceId,
          // novo campo: máximo de colaboradores
          'maximo_colaboradores': maxCol,
        };

        final resp = await http.post(
          Uri.parse('${widget.baseUrl}/planos'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(payload),
        );

        if (resp.statusCode == 201) {
          widget.onSaved?.call(true);
          _clearAfterSave();
          return;
        } else {
          _showSnack('Erro ao criar plano: ${resp.statusCode} ${resp.body}');
        }
      } else {
        final id = widget.existing!.id;
        final Map<String, dynamic> payload = {
          'nome': nome,
          'prioridade_de_tempo': prioridade,
          'quantidade_credito_mensal': quantidade,
          'preco_mensal': preco,
          // permitir atualização do stripe_price_id (pode enviar null para remover)
          'stripe_price_id': stripePriceId,
          // novo campo: máximo de colaboradores
          'maximo_colaboradores': maxCol,
        };

        final resp = await http.put(
          Uri.parse('${widget.baseUrl}/planos/$id'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(payload),
        );

        if (resp.statusCode == 200) {
          widget.onSaved?.call(true);
          return;
        } else {
          _showSnack('Erro ao atualizar plano: ${resp.statusCode} ${resp.body}');
        }
      }
    } catch (e) {
      _showSnack('Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _clearAfterSave() {
    _nomeCtrl.clear();
    _prioridadeCtrl.clear();
    _quantidadeCtrl.clear();
    _precoCtrl.clear();
    _stripePriceCtrl.clear();
    _maxColCtrl.text = '0';
    setState(() {});
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        // Use LayoutBuilder to adapt to available width.
        return LayoutBuilder(builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final isNarrow = maxWidth < 700; // threshold for mobile-like layout

          // Fields column (reusable)
          Widget fieldsColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome do plano',
                  filled: true,
                  fillColor: cm.card.withOpacity(0.12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _prioridadeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Prioridade (numérica)',
                      filled: true,
                      fillColor: cm.card.withOpacity(0.12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe prioridade';
                      if (int.tryParse(v.trim()) == null) return 'Número inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _quantidadeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Créditos/mês',
                      filled: true,
                      fillColor: cm.card.withOpacity(0.12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe créditos';
                      if (int.tryParse(v.trim()) == null) return 'Número inválido';
                      return null;
                    },
                  ),
                )
              ]),
              const SizedBox(height: 8),
              TextFormField(
                controller: _precoCtrl,
                decoration: InputDecoration(
                  labelText: 'Preço mensal (ex: 49.90)',
                  filled: true,
                  fillColor: cm.card.withOpacity(0.12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe preço';
                  final cleaned = v.replaceAll(',', '.');
                  final ok = double.tryParse(cleaned);
                  if (ok == null) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // NOVO: campo máximo de colaboradores (opcional, inteiro >= 0)
              TextFormField(
                controller: _maxColCtrl,
                decoration: InputDecoration(
                  labelText: 'Máx. de colaboradores (0 = Ilimitado)',
                  hintText: 'ex: 10',
                  filled: true,
                  fillColor: cm.card.withOpacity(0.12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // default 0 treated as ilimitado
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null || parsed < 0) return 'Número inválido';
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // NOVO: campo stripe price id (opcional)
              TextFormField(
                controller: _stripePriceCtrl,
                decoration: InputDecoration(
                  labelText: 'Stripe Price ID (opcional)',
                  hintText: 'ex: price_1Kxxx...',
                  helperText: 'Informe o Price ID do Stripe para integrar com Checkout/Subscription',
                  filled: true,
                  fillColor: cm.card.withOpacity(0.12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.text,
                validator: (v) {
                  // opcional: validar tamanho razoável
                  if (v != null && v.trim().isNotEmpty && v.trim().length < 6) {
                    return 'Price ID muito curto';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),
            ],
          );

          // Buttons area (adapt to width)
          Widget buttonsArea;
          if (isNarrow) {
            // On narrow screens, place buttons stacked full width below fields.
            buttonsArea = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cm.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: cm.text),
                        )
                      : Text(isEdit ? 'Salvar' : 'Criar', style: TextStyle(color: cm.text)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cm.primary,
                    side: BorderSide(color: cm.card.withOpacity(0.20)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          } else {
            // On wider screens, keep the compact vertical buttons column at the right.
            buttonsArea = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cm.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cm.text))
                      : Text(isEdit ? 'Salvar' : 'Criar', style: TextStyle(color: cm.text)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cm.primary,
                    side: BorderSide(color: cm.card.withOpacity(0.20)),
                  ),
                  child: const Text('Cancelar'),
                )
              ],
            );
          }

          // Build final layout: if narrow, stack fields then buttons; else use Row with fields expanded and buttons to the right.
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            fieldsColumn,
                            buttonsArea,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // left: fields
                            Expanded(child: fieldsColumn),
                            const SizedBox(width: 12),
                            // right: buttons (keep compact column)
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 220),
                              child: buttonsArea,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        });
      },
    );
  }
}
