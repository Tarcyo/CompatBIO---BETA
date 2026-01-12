// FILE: lib/widgets/create_produto_form.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/adminProduto/produtoItem.dart';
import 'package:planos/screens/adminProduto/produtoService.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';

class CreateProdutoForm extends StatefulWidget {
  final ProdutoCategoria initialCategoria;
  final VoidCallback? onCreated;

  const CreateProdutoForm({
    Key? key,
    this.initialCategoria = ProdutoCategoria.biologico,
    this.onCreated,
  }) : super(key: key);

  @override
  State<CreateProdutoForm> createState() => _CreateProdutoFormState();
}

class _CreateProdutoFormState extends State<CreateProdutoForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  late ProdutoCategoria _categoria;
  bool _sending = false;
  String? _serverError;
  bool _showOk = false;

  late final AnimationController _okController;
  late final Animation<double> _okScale;

  final _service = ProdutosService();

  // novo estado para demo (true = Sim, false = Não)
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    _categoria = widget.initialCategoria;
    _okController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _okScale = CurvedAnimation(parent: _okController, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _tipoCtrl.dispose();
    _okController.dispose();
    super.dispose();
  }

  String? _validateNome(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Informe nome';
    if (s.length < 2) return 'Muito curto';
    final invalid = RegExp(r'[<>\\/\\\\\\{\\}]');
    if (invalid.hasMatch(s)) return 'Caract. inválido';
    return null;
  }

  String? _validateTipo(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Informe tipo';
    if (s.length < 2) return 'Muito curto';
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _serverError = null;
      _showOk = false;
    });
    if (!_formKey.currentState!.validate()) return;

    final nome = _nomeCtrl.text.trim();
    final tipo = _tipoCtrl.text.trim();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.token;
    if (token == null || token.isEmpty) {
      setState(() => _serverError = 'Usuário não autenticado.');
      return;
    }

    setState(() => _sending = true);

    try {
      final resp = await _service.createProduto(
        token: token,
        nome: nome,
        tipo: tipo,
        categoria: _categoria,
        demo: _demo, // envia demo
      );

      if (resp.statusCode == 201) {
        setState(() => _showOk = true);
        _okController.forward(from: 0.0);
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onCreated?.call();
        if (mounted) Navigator.of(context).pop(true);
        return;
      } else {
        // tenta extrair mensagem do body para exibir
        String? message;
        try {
          final body = resp.body;
          if (body.isNotEmpty) {
            final parsed = json.decode(body);
            if (parsed is Map && parsed['error'] != null) message = parsed['error'].toString();
            else if (parsed is Map && parsed['message'] != null) message = parsed['message'].toString();
          }
        } catch (_) {
          // ignore parsing errors
        }

        if (resp.statusCode == 409) {
          setState(() => _serverError = message ?? 'Já existe.');
        } else if (resp.statusCode == 400) {
          setState(() => _serverError = message ?? 'Requisição inválida.');
        } else if (resp.statusCode == 401 || resp.statusCode == 403) {
          setState(() => _serverError = message ?? 'Sem permissão.');
        } else {
          setState(() => _serverError = message ?? 'Erro ${resp.statusCode}');
        }
      }
    } catch (e) {
      setState(() => _serverError = 'Erro de rede.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _chipCategoria(ProdutoCategoria cat, IconData icon, String label) {
    final selected = _categoria == cat;
    return GestureDetector(
      onTap: () => setState(() => _categoria = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? ColorManager.instance.primary
              : ColorManager.instance.card.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? ColorManager.instance.text : ColorManager.instance.primary.withOpacity(0.95),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? ColorManager.instance.text : ColorManager.instance.explicitText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgField = ColorManager.instance.card.withOpacity(0.04);
    final okBg = ColorManager.instance.ok.withOpacity(0.12);
    final errBg = ColorManager.instance.emergency.withOpacity(0.08);
    final primary = ColorManager.instance.primary;
    final textPrimary = ColorManager.instance.explicitText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Novo produto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
              ),
            ),
            ScaleTransition(
              scale: _okScale,
              child: AnimatedOpacity(
                opacity: _showOk ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  decoration: BoxDecoration(
                    color: okBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_rounded, color: ColorManager.instance.ok),
                      const SizedBox(width: 8),
                      Text('Criado', style: TextStyle(color: ColorManager.instance.ok)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _chipCategoria(ProdutoCategoria.biologico, Icons.eco_rounded, 'Biológico'),
            const SizedBox(width: 8),
            _chipCategoria(ProdutoCategoria.quimico, Icons.science_rounded, 'Químico'),
          ],
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeCtrl,
                validator: _validateNome,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  filled: true,
                  fillColor: bgField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tipoCtrl,
                validator: _validateTipo,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  filled: true,
                  fillColor: bgField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),

              // NOVO: dropdown para campo `demo` (Sim / Não)
              DropdownButtonFormField<bool>(
                value: _demo,
                decoration: InputDecoration(
                  labelText: 'Demo',
                  filled: true,
                  fillColor: bgField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                items: const [
                  DropdownMenuItem<bool>(value: false, child: Text('Não')),
                  DropdownMenuItem<bool>(value: true, child: Text('Sim')),
                ],
                onChanged: _sending ? null : (v) {
                  if (v == null) return;
                  setState(() => _demo = v);
                },
              ),

              const SizedBox(height: 10),
              if (_serverError != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: errBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: ColorManager.instance.emergency),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_serverError!, style: TextStyle(color: ColorManager.instance.emergency)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ColorManager.instance.text),
                            )
                          : const Text('Criar', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
        // OK floating indicator (top-right in dialog/sheet parent)
        // kept as no-op here; the original parent placed a positioned indicator.
      ],
    );
  }
}
