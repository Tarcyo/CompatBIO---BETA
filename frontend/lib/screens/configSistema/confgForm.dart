// FILE: lib/widgets/config_form.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/configSistema/configClass.dart';
import 'package:planos/screens/configSistema/config_service.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';

class ConfigForm extends StatefulWidget {
  final bool isEdit;
  final ConfigSistema? initial;
  final DateTime dataEstabelecimento;
  final VoidCallback? onSuccess;

  const ConfigForm({
    Key? key,
    this.isEdit = false,
    this.initial,
    required this.dataEstabelecimento,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends State<ConfigForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _precoCreditoController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  bool _sending = false;
  String? _serverError;

  final _service = ConfigService();

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _precoCreditoController.text = widget.initial!.precoDoCredito;
      _descricaoController.text = widget.initial!.descricao ?? '';
      // NOTE: preco_da_solicitacao_em_creditos and validade_em_dias are
      // no longer editable by the client (server forces them).
    }
  }

  @override
  void dispose() {
    _precoCreditoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (userProv.user == null) return null;
    return userProv.user!.token;
  }

  Future<void> _submit() async {
    setState(() {
      _serverError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final precoCreditoParsed = double.tryParse(_precoCreditoController.text.trim());
    if (precoCreditoParsed == null) {
      setState(() => _serverError = 'Preço do crédito inválido');
      return;
    }

    final token = await _getTokenFromProvider();
    if (token == null) {
      setState(() => _serverError = 'Usuário não autenticado. Faça login.');
      return;
    }

    // IMPORTANT: conforme nova regra de negócio, não enviamos os campos:
    // 'preco_da_solicitacao_em_creditos' e 'validade_em_dias' no payload.
    // O servidor os sobrescreve com 1 e 365 respectivamente.
    final payload = <String, dynamic>{
      'data_estabelecimento': _formatDate(widget.dataEstabelecimento),
      'preco_do_credito': precoCreditoParsed,
    };

    if (_descricaoController.text.trim().isNotEmpty) {
      payload['descricao'] = _descricaoController.text.trim();
    } else {
      // explicit null when editing to clear
      if (widget.isEdit) payload['descricao'] = null;
    }

    setState(() => _sending = true);
    try {
      final resp = await _service.createConfig(token, payload);
      if (resp.statusCode == 201) {
        widget.onSuccess?.call();
        // show small confirmation via snackbar
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEdit ? 'Configuração salva como nova versão com sucesso' : 'Configuração criada com sucesso')),
        );
        // small delay to let the animation show in parent
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        String msg;
        try {
          final body = json.decode(resp.body);
          msg = body['error'] ?? body.toString();
        } catch (_) {
          msg = resp.body.isNotEmpty ? resp.body : resp.statusCode.toString();
        }
        setState(() => _serverError = msg);
      }
    } catch (e) {
      setState(() => _serverError = 'Erro de conexão ao criar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatDate(DateTime dt) => dt.toIso8601String().split('T')[0];

  @override
  Widget build(BuildContext context) {
    final primary = ColorManager.instance.primary;
    final textColor = ColorManager.instance.explicitText;
    final mutedText = ColorManager.instance.explicitText.withOpacity(0.7);
    final fieldBg = ColorManager.instance.card.withOpacity(0.04);
    final iconBg = ColorManager.instance.card.withOpacity(0.06);
    final errorBg = ColorManager.instance.emergency.withOpacity(0.08);
    final errorColor = ColorManager.instance.emergency;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isEdit) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today_rounded, color: primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data de estabelecimento', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 6),
                      Text(_formatDate(widget.dataEstabelecimento), style: TextStyle(color: mutedText)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
          ],

          TextFormField(
            controller: _precoCreditoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Preço do crédito (ex: 0.0123)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: fieldBg,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Informe o preço do crédito';
              if (double.tryParse(v.trim()) == null) return 'Valor inválido';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Informational rows: campos que agora são controlados pelo servidor.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.request_page_rounded, color: primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preço da solicitação', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 6),
                      Text('Será registrado automaticamente como 1 crédito (não editável).', style: TextStyle(color: mutedText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_rounded, color: primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Validade dos pacotes', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 6),
                      Text('Será registrada automaticamente como 365 dias (não editável).', style: TextStyle(color: mutedText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _descricaoController,
            decoration: InputDecoration(
              labelText: 'Descrição (opcional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: fieldBg,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          if (_serverError != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: errorBg, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: errorColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_serverError!, style: TextStyle(color: errorColor))),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: ColorManager.instance.text,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _sending
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ColorManager.instance.text))
                      : Text(widget.isEdit ? 'Salvar alterações' : 'Criar configuração'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  foregroundColor: ColorManager.instance.explicitText,
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
