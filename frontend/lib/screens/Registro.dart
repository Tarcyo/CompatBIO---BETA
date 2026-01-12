import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:planos/styles/syles.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// import do banner de dica de scroll
import 'package:planos/utils/scroll_hint_banner.dart';

// Ajuste para seu servidor / emulador
final String apiBase = dotenv.env['BASE_URL']!;

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _cpfCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _stateCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _obscure = true;
  DateTime? _selectedDob;
  bool _isLoading = false;

  // empresas
  List<CompanyItem> _companies = [];
  bool _companiesLoading = false;
  int? _selectedCompanyId;

  // todas as siglas dos estados brasileiros (26 estados + DF)
  final List<String> _allStates = const [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  // --- ADIÇÃO: controlador de scroll e flag de banner ---
  late final ScrollController _scrollController;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();

    // inicializa scroll controller e adiciona listener que fecha o banner ao rolar
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollController);

    // checar overflow após primeiro frame para decidir mostrar/ocultar banner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateScrollable();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _cpfCtrl.dispose();
    _dobCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _phoneCtrl.dispose();

    // remove listener e dispose do scroll controller
    _scrollController.removeListener(_onScrollController);
    _scroll_controller_dispose_helper();
    super.dispose();
  }

  // helper to avoid accidentally renaming the controller dispose
  void _scroll_controller_dispose_helper() {
    try {
      _scrollController.dispose();
    } catch (_) {}
  }

  // Listener que desabilita o banner quando o usuário rolar alguns pixels
  void _onScrollController() {
    if (!_bannerDismissed && _scrollController.hasClients) {
      if (_scrollController.position.pixels > 5) {
        setState(() => _bannerDismissed = true);
      }
    }
  }

  // Avalia se existe overflow (conteúdo escondido). Re-tenta se controller ainda não tiver clients.
  void _evaluateScrollable() {
    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), _evaluateScrollable);
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      if (mounted) setState(() => _bannerDismissed = true);
    } else {
      // há overflow: mantemos o banner disponível (a não ser que já tenha sido dismissado)
    }
  }

  Future<void> _fetchCompanies() async {
    setState(() => _companiesLoading = true);
    try {
      final uri = Uri.parse('$apiBase/empresas');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body['empresas'] as List<dynamic>?) ?? [];
        final parsed = list.map((e) {
          return CompanyItem(id: e['id'] as int, nome: e['nome'] as String);
        }).toList();
        if (mounted) setState(() => _companies = parsed);
      } else {
        // não bloqueante — apenas mostra snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Falha ao carregar empresas: ${resp.statusCode}',
                style: TextStyle(color: ColorManager.instance.explicitText),
              ),
              backgroundColor: ColorManager.instance.card.withOpacity(0.12),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao buscar empresas: $e',
              style: TextStyle(color: ColorManager.instance.explicitText),
            ),
            backgroundColor: ColorManager.instance.card.withOpacity(0.12),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _companiesLoading = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: ColorManager.instance.primary,
          ),
          dialogBackgroundColor: ColorManager.instance.background,
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobCtrl.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _toIsoDateString(DateTime d) => d.toIso8601String().split('T').first;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nome = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final senha = _passCtrl.text;
    final cpf = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    final cidade = _cityCtrl.text.trim();
    final estado = _stateCtrl.text.trim();
    final telefone = _phoneCtrl.text.trim().isEmpty
        ? null
        : _phoneCtrl.text.trim();

    String? dataNascimento;
    if (_selectedDob != null) {
      dataNascimento = _toIsoDateString(_selectedDob!);
    }

    // Nota: não enviamos "tipo_usuario" no payload — o endpoint /cliente no servidor
    // deve forçar o tipo para "cliente" por segurança.
    final payload = {
      'nome': nome,
      'cpf': cpf,
      'email': email,
      'senha': senha,
      'data_nascimento': dataNascimento,
      'cidade': cidade.isEmpty ? null : cidade,
      'estado': estado.isEmpty ? null : estado,
      if (telefone != null) 'telefone': telefone,
      if (_selectedCompanyId != null) 'id_empresa': _selectedCompanyId,
    };

    try {
      // ALTERAÇÃO: rota agora é /cliente (em vez de /usuarios)
      final uri = Uri.parse('$apiBase/usuarios/cliente');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 201) {
        if (!mounted) return;
        // Mostrar popup de sucesso e limpar campos ao confirmar
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              'Sucesso',
              style: TextStyle(color: ColorManager.instance.explicitText),
            ),
            content: Text(
              'Usuário criado com sucesso! Faça login.',
              style: TextStyle(color: ColorManager.instance.explicitText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Fechar',
                  style: TextStyle(color: ColorManager.instance.primary),
                ),
              ),
            ],
          ),
        );

        if (!mounted) return;

        // Limpa todos os campos conforme solicitado
        setState(() {
          _nameCtrl.clear();
          _emailCtrl.clear();
          _passCtrl.clear();
          _cpfCtrl.clear();
          _dobCtrl.clear();
          _cityCtrl.clear();
          _stateCtrl.clear();
          _phoneCtrl.clear();
          _selectedCompanyId = null;
          _selectedDob = null;
          // manter _companies carregadas; manter flags
        });

        // Mantendo comportamento anterior de fechar tela (se houver rota anterior)
        Navigator.of(context).maybePop();
        return;
      }

      // extrair mensagem de erro legível
      String title = 'Erro ${resp.statusCode}';
      String message = resp.body;
      try {
        final parsed = jsonDecode(resp.body);
        if (parsed is Map && parsed['error'] != null) {
          message = parsed['error'].toString();
        } else if (parsed is Map && parsed['message'] != null) {
          message = parsed['message'].toString();
        } else {
          message = const JsonEncoder.withIndent('  ').convert(parsed);
        }
      } catch (_) {}

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              title,
              style: TextStyle(color: ColorManager.instance.explicitText),
            ),
            content: SingleChildScrollView(
              child: SelectableText(
                message,
                style: TextStyle(color: ColorManager.instance.explicitText),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Fechar',
                  style: TextStyle(color: ColorManager.instance.explicitText),
                ),
              ),
            ],
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) await _showErrorDialog('Erro', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showErrorDialog(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: ColorManager.instance.explicitText),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            message,
            style: TextStyle(color: ColorManager.instance.explicitText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Fechar',
              style: TextStyle(color: ColorManager.instance.explicitText),
            ),
          ),
        ],
      ),
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
            final isMobile = maxW < 600;
            final isTablet = maxW >= 600 && maxW < 1024;

            final cardWidth = isMobile
                ? max(320.0, maxW * 0.94)
                : isTablet
                    ? min(900.0, maxW * 0.75)
                    : min(1100.0, maxW * 0.65);

            final scale = (cardWidth / 380).clamp(0.82, 1.4);
            final cardPadding = 18.0 * scale;
            final topRadius = 20.0 * scale;

            // Estrutura com Stack para permitir posicionar o banner sobre a tela
            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    controller: _scrollController, // controlador adicionado
                    padding: EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: max(12.0, maxW * 0.03),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: max(320, cardWidth + 40),
                      ),
                      child: Card(
                        color: ColorManager.instance.card.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20 * scale),
                          side: BorderSide(
                            color: ColorManager.instance.card.withOpacity(0.6),
                            width: 1.2,
                          ),
                        ),
                        elevation: 0, // sombra removida
                        shadowColor:
                            Colors.transparent, // reforça remoção da sombra
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // HEADER integrado ao topo do Card (recortado pelos cantos superiores)
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(topRadius)),
                              child: _cardHeader(scale),
                            ),

                            // Conteúdo do card (form) com padding consistente
                            Padding(
                              padding: EdgeInsets.all(cardPadding),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildFormFields(scale, context),
                                  SizedBox(height: 12 * scale),
                                  _buildActions(scale, context),
                                  SizedBox(height: 8 * scale),
                                  _buildFooterText(scale),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Banner de dica de scroll — posicionado sobre toda a tela; exibido somente se houver overflow e ainda não dismissado
                if (!_bannerDismissed)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ScrollHintBanner(
                        onDismissed: () {
                          if (mounted) {
                            setState(() {
                              _bannerDismissed = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Header integrado no topo do Card — ocupa toda a largura superior do Card,
  /// com gradiente e ícone. Não "flutua": faz parte do Card.
  Widget _cardHeader(double scale) {
    final cm = ColorManager.instance;
    final primary = cm.primary;
    // cria tons ligeiramente mais escuros para gradiente
    final hsl = HSLColor.fromColor(primary);
    final mid = hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
    final end = hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor();

    final fg = primary.computeLuminance() > 0.56 ? Colors.black : Colors.white;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 14 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, mid, end],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Icon(Icons.person_add_rounded, color: fg, size: 22 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Criar conta',
                  style: TextStyle(
                    color: fg,
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(double scale, BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration(
              label: 'Nome',
              icon: Icons.badge_rounded,
              hint: 'Seu nome completo',
            ),
            // VALIDAÇÃO NOVA: permitir apenas letras (incluindo acentos) e espaços
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Informe seu nome';
              final name = v.trim();
              final validNameReg = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ\s]+$");
              if (!validNameReg.hasMatch(name)) {
                return 'Nome inválido — não use números ou símbolos';
              }
              // opcional: conferir tamanho mínimo
              if (name.split(RegExp(r'\s+')).length < 1) {
                return 'Informe um nome válido';
              }
              return null;
            },
          ),
          SizedBox(height: 12 * scale),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              label: 'Email',
              icon: Icons.email_rounded,
              hint: 'exemplo@dominio.com',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Informe seu email';
              final emailRegex = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w{2,}");
              if (!emailRegex.hasMatch(v.trim())) return 'Email inválido';
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
              hint: 'Mínimo 6 caracteres',
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a senha';
              if (v.length < 6) return 'Senha muito curta';
              return null;
            },
          ),
          SizedBox(height: 12 * scale),
          LayoutBuilder(
            builder: (context, inner) {
              final isNarrow = inner.maxWidth < 420;
              if (isNarrow) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _cpfCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CpfInputFormatter(),
                      ],
                      decoration: _inputDecoration(
                        label: 'CPF',
                        icon: Icons.credit_card_rounded,
                        hint: '000.000.000-00',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o CPF';
                        if (v.replaceAll(RegExp(r'\D'), '').length != 11)
                          return 'CPF inválido';
                        return null;
                      },
                    ),
                    SizedBox(height: 12 * scale),
                    TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      onTap: _pickDob,
                      decoration: _inputDecoration(
                        label: 'Data de nascimento',
                        icon: Icons.cake_rounded,
                        hint: 'dd/mm/aaaa',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a data'
                          : null,
                    ),
                    SizedBox(height: 12 * scale),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: _inputDecoration(
                        label: 'Cidade',
                        icon: Icons.location_city_rounded,
                        hint: 'Cidade',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a cidade'
                          : null,
                    ),
                    SizedBox(height: 12 * scale),
                    DropdownButtonFormField<String?>(
                      value: _stateCtrl.text.isEmpty ? null : _stateCtrl.text,
                      decoration: _inputDecoration(
                        label: 'Estado',
                        icon: Icons.map_rounded,
                        hint: 'Estado (ex.: SP)',
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            '— Selecionar —',
                            style: TextStyle(
                              color: ColorManager.instance.explicitText,
                            ),
                          ),
                        ),
                        ..._allStates.map((s) {
                          return DropdownMenuItem<String?>(
                            value: s,
                            child: Text(
                              s,
                              style: TextStyle(
                                color: ColorManager.instance.explicitText,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (v) => setState(() => _stateCtrl.text = v ?? ''),
                      validator: (v) =>
                          (v == null || (v.trim().isEmpty)) ? 'Informe o estado' : null,
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cpfCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CpfInputFormatter(),
                            ],
                            decoration: _inputDecoration(
                              label: 'CPF',
                              icon: Icons.credit_card_rounded,
                              hint: '000.000.000-00',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Informe o CPF';
                              if (v.replaceAll(RegExp(r'\D'), '').length != 11)
                                return 'CPF inválido';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: TextFormField(
                            controller: _dobCtrl,
                            readOnly: true,
                            onTap: _pickDob,
                            decoration: _inputDecoration(
                              label: 'Data de nascimento',
                              icon: Icons.cake_rounded,
                              hint: 'dd/mm/aaaa',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe a data'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12 * scale),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration: _inputDecoration(
                              label: 'Cidade',
                              icon: Icons.location_city_rounded,
                              hint: 'Cidade',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Informe a cidade' : null,
                          ),
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _stateCtrl.text.isEmpty ? null : _stateCtrl.text,
                            decoration: _inputDecoration(
                              label: 'Estado',
                              icon: Icons.map_rounded,
                              hint: 'Estado (ex.: SP)',
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  '— Selecionar —',
                                  style: TextStyle(
                                    color: ColorManager.instance.explicitText,
                                  ),
                                ),
                              ),
                              ..._allStates.map((s) {
                                return DropdownMenuItem<String?>(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      color: ColorManager.instance.explicitText,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (v) => setState(() => _stateCtrl.text = v ?? ''),
                            validator: (v) =>
                                (v == null || (v.trim().isEmpty)) ? 'Informe o estado' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          SizedBox(height: 12 * scale),

          // Telefone
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              PhoneInputFormatter(),
            ],
            decoration: _inputDecoration(
              label: 'Telefone (opcional)',
              icon: Icons.phone_rounded,
              hint: '(00) 90000-0000',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null; // opcional
              final digits = v.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10) return 'Telefone inválido';
              return null;
            },
          ),

          SizedBox(height: 12 * scale),

          // Dropdown de empresas
          _companiesLoading
              ? SizedBox(
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorManager.instance.primary,
                    ),
                  ),
                )
              : DropdownButtonFormField<int>(
                  value: _selectedCompanyId,
                  decoration: _inputDecoration(
                    label: 'Empresa (opcional)',
                    icon: Icons.business_rounded,
                  ),
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text(
                        '— Sem vínculo —',
                        style: TextStyle(
                          color: ColorManager.instance.explicitText,
                        ),
                      ),
                    ),
                    ..._companies.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(
                          c.nome,
                          style: TextStyle(
                            color: ColorManager.instance.explicitText,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (v) => setState(() => _selectedCompanyId = v),
                  validator: (v) {
                    // opcional — não força seleção
                    return null;
                  },
                ),

          SizedBox(height: 12 * scale),
        ],
      ),
    );
  }

  Widget _buildActions(double scale, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14 * scale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
            backgroundColor: ColorManager.instance.primary,
            foregroundColor: ColorManager.instance.text,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 18 * scale,
                  width: 18 * scale,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ColorManager.instance.text,
                  ),
                )
              : Text(
                  'Criar conta',
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.instance.text,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFooterText(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 6 * scale),
      ],
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

class CompanyItem {
  final int id;
  final String nome;
  CompanyItem({required this.id, required this.nome});
}

// Formatter simples para CPF: 000.000.000-00
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digitsOnly.length && i < 11; i++) {
      buffer.write(digitsOnly[i]);
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('-');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata telefone brazuca: (00) 90000-0000 ou (00) 0000-0000
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    int len = digits.length;
    if (len == 0)
      return TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );

    // DDD
    if (len >= 1) {
      buffer.write('(');
      for (int i = 0; i < min(2, len); i++) buffer.write(digits[i]);
      if (len >= 3) buffer.write(') ');
    }
    if (len <= 2) {
      // apenas DDD parcial
    } else if (len <= 6) {
      // (XX) XXXX
      for (int i = 2; i < len; i++) buffer.write(digits[i]);
    } else if (len <= 10) {
      // (XX) XXXX-XXXX
      for (int i = 2; i < min(6, len); i++) buffer.write(digits[i]);
      if (len > 6) {
        buffer.write('-');
        for (int i = 6; i < len; i++) buffer.write(digits[i]);
      }
    } else {
      // (XX) 9XXXX-XXXX (11 dígitos)
      for (int i = 2; i < 7; i++) {
        if (i < len) buffer.write(digits[i]);
      }
      buffer.write('-');
      for (int i = 7; i < len && i < 11; i++) buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
