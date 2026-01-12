// FILE: lib/widgets/empresa_inline_form.dart
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/empresa/empresaClass.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class EmpresaInlineForm extends StatefulWidget {
  final String baseUrl;
  final Empresa? existing;
  final void Function(bool ok)? onSaved;
  final VoidCallback? onCancel;

  const EmpresaInlineForm({Key? key, required this.baseUrl, this.existing, this.onSaved, this.onCancel}) : super(key: key);

  @override
  State<EmpresaInlineForm> createState() => _EmpresaInlineFormState();
}

class _EmpresaInlineFormState extends State<EmpresaInlineForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeCtrl = TextEditingController();
  final TextEditingController _cnpjCtrl = TextEditingController();
  final TextEditingController _logoUrlCtrl = TextEditingController();

  final List<Map<String, String>> _colorOptions = [
    {'name': 'Teal', '#hex': '#00897B'},
    {'name': 'Azul', '#hex': '#1976D2'},
    {'name': 'Verde', '#hex': '#2E7D32'},
    {'name': 'Laranja', '#hex': '#F57C00'},
    {'name': 'Roxo', '#hex': '#6A1B9A'},
    {'name': 'Vermelho', '#hex': '#D32F2F'},
    {'name': 'Cinza', '#hex': '#757575'},
  ];
  String? _selectedColor;

  // Para mobile (File) e web (bytes)
  File? _pickedFile; // usado em mobile
  Uint8List? _pickedBytes; // usado em web para preview e upload
  String? _pickedFilename; // nome do arquivo selecionado (útil no web)
  bool _useUrl = false;
  bool _submitting = false;
  bool _removeLogo = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nomeCtrl.text = widget.existing!.nome;
      _cnpjCtrl.text = widget.existing!.cnpj;
      _selectedColor = widget.existing!.corTema;
      _logoUrlCtrl.text = widget.existing!.logo ?? '';
    }
  }

  @override
  void didUpdateWidget(covariant EmpresaInlineForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.existing != oldWidget.existing) {
      if (widget.existing != null) {
        _nomeCtrl.text = widget.existing!.nome;
        _cnpjCtrl.text = widget.existing!.cnpj;
        _selectedColor = widget.existing!.corTema;
        _logoUrlCtrl.text = widget.existing!.logo ?? '';
      } else {
        _nomeCtrl.clear();
        _cnpjCtrl.clear();
        _selectedColor = null;
        _logoUrlCtrl.clear();
        _pickedFile = null;
        _pickedBytes = null;
        _pickedFilename = null;
        _removeLogo = false;
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cnpjCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getTokenFromProvider() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (userProv.user == null) return null;
    return userProv.user!.token;
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x == null) return;

    if (kIsWeb) {
      // Web: ler bytes e guardar para preview/upload
      final bytes = await x.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedFilename = x.name;
        _pickedFile = null;
        _useUrl = false;
        _logoUrlCtrl.clear();
        _removeLogo = false;
      });
    } else {
      // Mobile: manter File path para upload por fromPath e preview via Image.file
      setState(() {
        _pickedFile = File(x.path);
        _pickedBytes = null;
        _pickedFilename = x.name;
        _useUrl = false;
        _logoUrlCtrl.clear();
        _removeLogo = false;
      });
    }
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
    final cnpj = _cnpjCtrl.text.trim().replaceAll(RegExp('[^0-9]'), '');
    final cor = _selectedColor;
    final logoUrl = _logoUrlCtrl.text.trim();

    try {
      if (widget.existing == null) {
        // criar
        if (_pickedFile != null || _pickedBytes != null) {
          final uri = Uri.parse('${widget.baseUrl}/empresas');
          final req = http.MultipartRequest('POST', uri);
          req.headers['Authorization'] = 'Bearer $token';
          req.fields['nome'] = nome;
          req.fields['cnpj'] = cnpj;
          req.fields['corTema'] = cor!;

          if (_pickedFile != null) {
            final file = await http.MultipartFile.fromPath('logo', _pickedFile!.path);
            req.files.add(file);
          } else if (_pickedBytes != null) {
            final filename = _pickedFilename ?? 'logo.png';
            final mfile = http.MultipartFile.fromBytes('logo', _pickedBytes!, filename: filename);
            req.files.add(await mfile);
          }

          final streamed = await req.send();
          final resp = await http.Response.fromStream(streamed);
          if (resp.statusCode == 201) {
            widget.onSaved?.call(true);
            _clearAfterSave();
            return;
          } else {
            _showSnack('Erro: ${resp.body.isNotEmpty ? resp.body : resp.statusCode}');
          }
        } else {
          final payload = {'nome': nome, 'cnpj': cnpj, 'corTema': cor!, if (logoUrl.isNotEmpty) 'logo': logoUrl};
          final resp = await http.post(Uri.parse('${widget.baseUrl}/empresas'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: json.encode(payload));
          if (resp.statusCode == 201) {
            widget.onSaved?.call(true);
            _clearAfterSave();
            return;
          } else {
            _showSnack('Erro: ${resp.body.isNotEmpty ? resp.body : resp.statusCode}');
          }
        }
      } else {
        // editar
        final id = widget.existing!.id;
        if (_pickedFile != null || _pickedBytes != null) {
          final uri = Uri.parse('${widget.baseUrl}/empresas/$id');
          final req = http.MultipartRequest('PATCH', uri);
          req.headers['Authorization'] = 'Bearer $token';
          req.fields['nome'] = nome;
          req.fields['cnpj'] = cnpj;
          req.fields['corTema'] = cor!;

          if (_pickedFile != null) {
            final file = await http.MultipartFile.fromPath('logo', _pickedFile!.path);
            req.files.add(file);
          } else if (_pickedBytes != null) {
            final filename = _pickedFilename ?? 'logo.png';
            final mfile = http.MultipartFile.fromBytes('logo', _pickedBytes!, filename: filename);
            req.files.add(await mfile);
          }

          final streamed = await req.send();
          final resp = await http.Response.fromStream(streamed);
          if (resp.statusCode == 200) {
            widget.onSaved?.call(true);
            return;
          } else {
            _showSnack('Erro: ${resp.body.isNotEmpty ? resp.body : resp.statusCode}');
          }
        } else {
          final Map<String, dynamic> payload = {'nome': nome, 'cnpj': cnpj, 'corTema': cor!};
          if (_useUrl) {
            payload['logo'] = logoUrl.isEmpty ? '' : logoUrl;
          } else if (_removeLogo) {
            payload['logo'] = '';
          }

          final resp = await http.patch(Uri.parse('${widget.baseUrl}/empresas/$id'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: json.encode(payload));
          if (resp.statusCode == 200) {
            widget.onSaved?.call(true);
            return;
          } else {
            _showSnack('Erro: ${resp.body.isNotEmpty ? resp.body : resp.statusCode}');
          }
        }
      }
    } catch (e) {
      _showSnack('Erro de conexão: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _clearAfterSave() {
    _nomeCtrl.clear();
    _cnpjCtrl.clear();
    _selectedColor = null;
    _logoUrlCtrl.clear();
    _pickedFile = null;
    _pickedBytes = null;
    _pickedFilename = null;
    _removeLogo = false;
    setState(() {});
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String? _validateCnpj(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o CNPJ (apenas dígitos)';
    final only = v.replaceAll(RegExp('[^0-9]'), '');
    if (only.length != 14) return 'CNPJ deve ter 14 dígitos';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return Column(
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final vw = constraints.maxWidth;
              final isNarrow = vw < 700;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Form(
                  key: _formKey,
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFieldsColumn(cm),
                            const SizedBox(height: 12),
                            _buildActionsColumn(cm),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildFieldsColumn(cm)),
                            const SizedBox(width: 12),
                            _buildActionsColumn(cm),
                          ],
                        ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildFieldsColumn(ColorManager cm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nomeCtrl,
          decoration: InputDecoration(
            labelText: 'Nome',
            filled: true,
            fillColor: cm.card.withOpacity(0.12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cnpjCtrl,
          decoration: InputDecoration(
            labelText: 'CNPJ (apenas dígitos)',
            filled: true,
            fillColor: cm.card.withOpacity(0.12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          keyboardType: TextInputType.number,
          validator: _validateCnpj,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedColor,
          decoration: InputDecoration(
            labelText: 'Cor tema',
            filled: true,
            fillColor: cm.card.withOpacity(0.12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          items: _colorOptions.map((c) {
            final hex = c['#hex']!;
            final name = c['name']!;
            final parsed = Color(int.parse('0xFF' + hex.replaceAll('#', '')));
            return DropdownMenuItem<String>(
              value: hex,
              child: Row(
                children: [
                  Container(width: 16, height: 16, decoration: BoxDecoration(color: parsed, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 8),
                  Text('$name ($hex)'),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedColor = v),
          validator: (v) {
            if ((_selectedColor ?? '').isEmpty) return 'Selecione uma cor';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Pré-visualização:', style: TextStyle(color: Colors.black54)),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _selectedColor != null ? Color(int.parse('0xFF' + _selectedColor!.replaceAll('#', ''))) : cm.card.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cm.card.withOpacity(0.12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_selectedColor ?? 'Nenhuma cor selecionada', style: TextStyle(color: cm.explicitText))),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.photo_library_rounded, color: cm.text),
              label: Text('Selecionar arquivo', style: TextStyle(color: cm.text)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cm.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _useUrl = !_useUrl),
            icon: Icon(Icons.link_rounded, color: cm.primary),
            label: Text(_useUrl ? 'Usando URL' : 'Usar URL', style: TextStyle(color: cm.primary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cm.card.withOpacity(0.20)),
            ),
          )
        ]),
        const SizedBox(height: 8),
        if (_pickedFile != null || _pickedBytes != null) ...[
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _pickedBytes != null
                  ? Image.memory(_pickedBytes!, width: 96, height: 96, fit: BoxFit.cover)
                  : Image.file(_pickedFile!, width: 96, height: 96, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Arquivo: ${_pickedFilename ?? (_pickedFile != null ? _pickedFile!.path.split('/').last : '')}', style: TextStyle(color: cm.explicitText))),
            IconButton(onPressed: () => setState(() {
              _pickedFile = null;
              _pickedBytes = null;
              _pickedFilename = null;
            }), icon: Icon(Icons.close_rounded, color: cm.explicitText)),
          ]),
          const SizedBox(height: 8),
        ],
        if (_useUrl) ...[
          TextFormField(
            controller: _logoUrlCtrl,
            decoration: InputDecoration(
              labelText: 'URL da logo (http...)',
              filled: true,
              fillColor: cm.card.withOpacity(0.12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            validator: (v) {
              if (!_useUrl) return null;
              if (v == null || v.trim().isEmpty) return 'Informe a URL ou desative URL';
              final ok = Uri.tryParse(v.trim());
              if (ok == null || !ok.hasScheme) return 'URL inválida';
              return null;
            },
          ),
          const SizedBox(height: 8),
        ],
        if (widget.existing != null)
          SwitchListTile(
            value: _removeLogo,
            onChanged: (v) => setState(() => _removeLogo = v),
            title: Text('Remover logo atual', style: TextStyle(color: cm.explicitText)),
            activeColor: cm.primary,
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildActionsColumn(ColorManager cm) {
    return Column(
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
              : Text(widget.existing == null ? 'Criar' : 'Salvar', style: TextStyle(color: cm.text)),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: widget.onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: cm.primary,
            side: BorderSide(color: cm.card.withOpacity(0.20)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          child: Text('Cancelar', style: TextStyle(color: cm.explicitText)),
        ),
      ],
    );
  }
}
