// file: user_profile_page_api.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/Login.dart';
import 'package:planos/screens/sideBarInternp.dart';
import 'package:planos/styles/syles.dart';
import 'package:planos/utils/scroll_hint_banner.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:planos/screens/planos/plans_page_campact.dart';
import 'package:planos/screens/userProfile/fieldDecoration.dart';
import 'package:planos/screens/userProfile/pair_collums.dart';
import 'package:planos/screens/userProfile/plan_credit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Header reutilizável incluído na parte superior do Card da tela de perfil.
/// Visual idêntico ao que usamos nas outras telas: gradiente, ícone circular,
/// texto e um espaço para trailing.
class UserProfileCardHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final Color primary;
  final double borderRadius;
  final Widget? trailing;
  final double verticalPadding;
  final double horizontalPadding;
  final double scale;

  const UserProfileCardHeader({
    Key? key,
    required this.title,
    required this.leadingIcon,
    required this.primary,
    this.trailing,
    this.borderRadius = 18,
    this.verticalPadding = 14,
    this.horizontalPadding = 16,
    this.scale = 1.0,
  }) : super(key: key);

  Color _darken(Color color, [double amount = 0.12]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final primaryMid = _darken(primary, 0.08);
    final primaryEnd = _darken(primary, 0.20);
    final shadowColor = _darken(primary, 0.45).withOpacity(0.22);

    final iconSize = 16.0 * scale + 8.0;
    final titleFont = 18.0 * scale + 4.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.55, 1.0],
          colors: [primary, primaryMid, primaryEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(leadingIcon, color: Colors.white, size: iconSize),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: titleFont,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class UserProfilePage extends StatefulWidget {
  final SideBarController? controller;

  const UserProfilePage({super.key, required this.controller});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _nameCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  String _stateValue = 'GO';
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _plano;
  final List<String> _states = [
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
  // --- Contas vinculadas ---
  bool _loadingContas = false;
  List<Map<String, dynamic>> _contas = [];
  int? _donoId; // **ID do dono da assinatura**
  final _addUserEmailCtrl = TextEditingController();
  bool _managing = false;

  // --- Empresas (novo dropdown) ---
  bool _loadingEmpresas = false;
  List<Map<String, dynamic>> _empresas = [];
  int? _selectedCompanyId; // id_empresa selecionada, ou null = sem empresa

  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  // flag local para controlar exibição do ScrollHintBanner
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmpresas();
      _loadUserProfile();
      _loadContasVinculadas();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _docCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _dobCtrl.dispose();
    _addUserEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmpresas() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final user = userProv.user;
    setState(() => _loadingEmpresas = true);
    try {
      final uri = Uri.parse('$baseUrl/empresas');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (user != null) 'Authorization': 'Bearer ${user.token}',
        },
      );
      if (resp.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(resp.body);
        final List<dynamic>? list = body['empresas'] as List<dynamic>?;
        setState(() {
          _empresas =
              list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
                  [];
        });
      } else {
        setState(() => _empresas = []);
      }
    } catch (e) {
      setState(() => _empresas = []);
    } finally {
      setState(() => _loadingEmpresas = false);
    }
  }

  Future<void> _loadUserProfile() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final user = userProv.user;
    if (user == null) return;
    setState(() => _loading = true);
    final uri = Uri.parse('$baseUrl/usuarios/me');
    final resp = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${user.token}',
      },
    );
    setState(() => _loading = false);
    if (resp.statusCode != 200) return;
    final Map<String, dynamic> body = json.decode(resp.body);
    final Map<String, dynamic>? userJson =
        body['user'] as Map<String, dynamic>?;
    if (userJson == null) return;
    _nameCtrl.text = userJson['nome'] ?? '';
    _selectedCompanyId = (userJson['id_empresa'] is int)
        ? userJson['id_empresa'] as int
        : null;
    _docCtrl.text = userJson['cpf'] ?? '';
    _emailCtrl.text = userJson['email'] ?? '';
    _phoneCtrl.text = userJson['telefone'] ?? '';
    _cityCtrl.text = userJson['cidade'] ?? '';
    _stateValue = (userJson['estado'] as String?) ?? _stateValue;

    final rawDob = userJson['data_nascimento'];
    if (rawDob != null) {
      DateTime? parsed;
      try {
        parsed = DateTime.parse(rawDob.toString());
      } catch (_) {
        parsed = null;
      }
      if (parsed != null) {
        _dobCtrl.text =
            '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      } else {
        _dobCtrl.text = rawDob.toString();
      }
    } else {
      _dobCtrl.text = '';
    }

    setState(() {
      _plano = userJson['plano'] as Map<String, dynamic>?;
    });

    userProv.setUser(
      User(
        id: user.id,
        nome: _nameCtrl.text,
        email: _emailCtrl.text,
        tipoUsuario: user.tipoUsuario,
        token: user.token,
      ),
    );
  }

  Future<void> _loadContasVinculadas() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final user = userProv.user;
    if (user == null) return;
    setState(() => _loadingContas = true);
    final uri = Uri.parse('$baseUrl/assinaturas/me/contas');
    try {
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
      );
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final List<dynamic>? contasJson = body['contas'] as List<dynamic>?;
        final dono = body['donoId'] as int?;
        setState(() {
          _contas =
              contasJson
                      ?.map((e) => Map<String, dynamic>.from(e as Map))
                      .toList() ??
                  [];
          _donoId = dono;
        });
      }
    } finally {
      setState(() => _loadingContas = false);
    }
  }

  bool _isValidEmail(String? email) {
    if (email == null) return false;
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(trimmed);
  }

  Future<void> _addContaByEmail() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final user = userProv.user;
    if (user == null) return;
    final raw = _addUserEmailCtrl.text.trim();
    if (!_isValidEmail(raw)) return;
    setState(() => _managing = true);
    final uri = Uri.parse('$baseUrl/assinaturas/me/contas');
    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: json.encode({'email': raw}),
      );
      if (resp.statusCode == 200) {
        _addUserEmailCtrl.clear();
        await _loadContasVinculadas();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário vinculado com sucesso')),
        );
      } else {
        String msg = 'Erro ao vincular usuário';
        try {
          final body = json.decode(resp.body);
          if (body is Map && body['error'] != null) msg = body['error'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erro de rede')));
    } finally {
      setState(() => _managing = false);
    }
  }

  Future<void> _removeConta(int targetId) async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final user = userProv.user;
    if (user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar remoção'),
        content: Text(
          'Deseja realmente remover a conta ID $targetId da sua assinatura?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _managing = true);
    final uri = Uri.parse('$baseUrl/assinaturas/me/contas/$targetId');
    try {
      final resp = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
      );
      if (resp.statusCode == 200) {
        await _loadContasVinculadas();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta removida da assinatura')),
        );
      } else {
        String msg = 'Erro ao remover conta';
        try {
          final body = json.decode(resp.body);
          if (body is Map && body['error'] != null) msg = body['error'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erro de rede')));
    } finally {
      setState(() => _managing = false);
    }
  }

  Future<void> _showUserDetails(Map<String, dynamic> conta) async {
    final id = conta['id'] ?? '-';
    final nome = conta['nome'] ?? '-';
    final email = conta['email'] ?? '-';
    final tipo = conta['tipo_usuario'] ?? '-';
    final credits = conta['saldo_em_creditos'] ?? 0;
    final created = conta['created_at']?.toString() ?? '-';
    final isDono = (_donoId != null && id == _donoId);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$nome (ID $id)${isDono ? " • DONO" : ""}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: $email'),
            const SizedBox(height: 6),
            Text('Tipo: $tipo'),
            const SizedBox(height: 6),
            Text('Créditos: $credits'),
            const SizedBox(height: 6),
            Text('Criado em: $created'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    if (_dobCtrl.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_dobCtrl.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final user = userProv.user;
    if (user == null) return;
    setState(() => _saving = true);

    final body = {
      'nome': _nameCtrl.text.trim(),
      'id_empresa': _selectedCompanyId,
      'cpf': _docCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'telefone': _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      'cidade': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      'estado': _stateValue,
      'data_nascimento': _dobCtrl.text.trim().isEmpty
          ? null
          : _dobCtrl.text.trim(),
    };

    final uri = Uri.parse('$baseUrl/usuarios/me');
    final resp = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${user.token}',
      },
      body: json.encode(body),
    );

    setState(() => _saving = false);
    if (resp.statusCode == 200) {
      final Map<String, dynamic> respBody = json.decode(resp.body);
      final Map<String, dynamic>? updatedUser =
          respBody['user'] as Map<String, dynamic>?;
      if (updatedUser != null) {
        userProv.setUser(
          User(
            id: user.id,
            nome: updatedUser['nome'] ?? _nameCtrl.text,
            email: updatedUser['email'] ?? _emailCtrl.text,
            tipoUsuario: user.tipoUsuario,
            token: user.token,
          ),
        );
      }
      await fetchEmpresaAndApply(
        token: Provider.of<UserProvider>(context, listen: false).user!.token,
      );

      // FORÇA o reload visual do sidebar sem tocar na seleção/navegação
      widget.controller?.reload(); // <<< CHAMADA CORRETA (instância)

      await _loadUserProfile();
    }
  }

  void _goToPlans() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlansPageCompact()),
    ).then((value) {
      if (value == 1) {
        widget.controller?.reload(); // <<< CHAMADA CORRETA (instância)
      }
    });

    ;
    await _loadUserProfile();
    await _loadContasVinculadas();
  }

  // ---------------------- NOVAS FUNÇÕES PARA TRANSFERÊNCIA ----------------------

  Future<void> _showTransferDialogFor(Map<String, dynamic> conta) async {
    final targetId = conta['id'] as int?;
    if (targetId == null) return;

    final userProv = Provider.of<UserProvider>(context, listen: false);
    final user = userProv.user;
    if (user == null) return;

    // Buscar saldo do dono para exibir (se presente na lista)
    final donoAccount = _contas.firstWhere(
      (c) => c['id'] == _donoId,
      orElse: () => <String, dynamic>{},
    );
    final donoSaldo = donoAccount.isNotEmpty ? (donoAccount['saldo_em_creditos'] ?? 0) : null;

    String amountText = '';
    String? errorText;
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateDialog) {
          Future<void> submit() async {
            final q = int.tryParse(amountText.trim());
            if (q == null || q <= 0) {
              setStateDialog(() {
                errorText = 'Informe uma quantidade inteira maior que zero';
              });
              return;
            }

            setStateDialog(() {
              loading = true;
              errorText = null;
            });

            final uri = Uri.parse('$baseUrl/assinaturas/me/contas/transferir');
            try {
              final resp = await http.post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${user.token}',
                },
                body: json.encode({'targetUserId': targetId, 'quantidade': q}),
              );

              if (resp.statusCode == 200) {
                // Sucesso
                Navigator.of(ctx2).pop(); // fecha o dialog
                await _loadContasVinculadas();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Transferência de $q créditos realizada com sucesso')),
                );
              } else {
                String msg = 'Erro ao transferir créditos';
                try {
                  final body = json.decode(resp.body);
                  if (body is Map && body['error'] != null) msg = body['error'].toString();
                } catch (_) {}
                setStateDialog(() {
                  errorText = msg;
                });
              }
            } catch (e) {
              setStateDialog(() {
                errorText = 'Erro de rede';
              });
            } finally {
              setStateDialog(() {
                loading = false;
              });
            }
          }

          return AlertDialog(
            title: Text('Transferir créditos para ${conta['nome'] ?? 'usuário'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (donoSaldo != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Seus créditos disponíveis: $donoSaldo'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantidade',
                    hintText: 'Ex.: 10',
                    errorText: errorText,
                  ),
                  onChanged: (v) => setStateDialog(() => amountText = v),
                ),
                const SizedBox(height: 8),
                if (errorText != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.of(ctx2).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Transferir'),
              ),
            ],
          );
        });
      },
    );
  }

  // ---------------------- FIM: TRANSFERÊNCIA ----------------------

  Widget _buildContasCard(double innerW, ColorManager cm) {
    return Card(
      // card mais suave: usar card com baixa opacidade e sem sombra para visual leve
      color: cm.card.withOpacity(0.12),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group_rounded, color: cm.primary),
                const SizedBox(width: 8),
                Text(
                  'Contas vinculadas',
                  style: TextStyle(
                    fontSize: innerW > 1100 ? 20 : 16,
                    fontWeight: FontWeight.w900,
                    color: cm.explicitText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Recarregar',
                  onPressed: _loadingContas ? null : _loadContasVinculadas,
                  icon: _loadingContas
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh_rounded, color: cm.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _addUserEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'E-mail do usuário para vincular',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_managing || _loadingContas)
                      ? null
                      : _addContaByEmail,
                  child: _managing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Vincular'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _loadingContas
                ? const Center(child: CircularProgressIndicator())
                : _contas.isEmpty
                    ? Text(
                        'Nenhuma conta vinculada.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: cm.explicitText,
                        ),
                      )
                    : Column(
                        children: _contas.map((c) {
                          final id = c['id'] ?? 0;
                          final nome = c['nome'] ?? '-';
                          final email = c['email'] ?? '-';
                          final tipo = c['tipo_usuario'] ?? '';
                          final credits = c['saldo_em_creditos'] ?? 0;
                          final isDono = (_donoId != null && id == _donoId);

                          // Current logged user ID (to check if they are the dono)
                          final currentUserId = Provider.of<UserProvider>(context, listen: false).user?.id;

                          final canTransfer = (_donoId != null && currentUserId != null && currentUserId == _donoId && !isDono);

                          return Card(
                            color: cm.card.withOpacity(0.12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$nome${isDono ? " • DONO" : ""} (ID $id)',
                                      style: TextStyle(color: cm.explicitText),
                                    ),
                                  ),
                                  if (isDono)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cm.alert,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Dono',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: cm.text,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '$email • ${tipo.toString()} • créditos: $credits',
                                style: TextStyle(color: cm.explicitText),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Ver perfil',
                                    onPressed: () => _showUserDetails(c),
                                    icon: Icon(
                                      Icons.open_in_new_rounded,
                                      color: cm.primary,
                                    ),
                                  ),
                                  if (canTransfer)
                                    IconButton(
                                      tooltip: 'Transferir créditos',
                                      onPressed: () => _showTransferDialogFor(c),
                                      icon: Icon(
                                        Icons.send_rounded,
                                        color: cm.ok,
                                      ),
                                    ),
                                  if (!isDono)
                                    IconButton(
                                      tooltip: 'Remover da assinatura',
                                      onPressed: (_managing)
                                          ? null
                                          : () => _removeConta(id as int),
                                      icon: Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: cm.emergency,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reconstrói quando ColorManager notificar, permitindo troca de tema dinâmica
    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        return Scaffold(
          backgroundColor: cm.background,
          body: SafeArea(
            child: Stack(
              children: [
                // Conteúdo original (mantido exatamente) envolto em NotificationListener
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Se o usuário iniciar rolagem, descartamos o banner localmente
                    if (!_bannerDismissed &&
                        (notification is ScrollStartNotification ||
                            notification.metrics.pixels > 0)) {
                      setState(() {
                        _bannerDismissed = true;
                      });
                    }
                    return false;
                  },
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, viewport) {
                            final vw = viewport.maxWidth;
                            final vh = viewport.maxHeight;
                            final horizontalGap = vw > 1200 ? 48.0 : 24.0;
                            final verticalGap = vh > 900 ? 48.0 : 24.0;
                            final cardWidth = (vw - horizontalGap).clamp(320.0, vw);
                            final minCardHeight = vh > 600
                                ? (vh - verticalGap).clamp(360.0, vh)
                                : 0.0;

                            final double desktopScale = vw >= 1400 ? 1.18 : (vw >= 1000 ? 1.08 : 1.0);
                            final double uiScale = desktopScale * 1.12;

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: vh),
                                child: Center(
                                  child: SizedBox(
                                    width: cardWidth,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: minCardHeight,
                                      ),
                                      child: Card(
                                        // card principal mais suave (sem sombra e com opacidade baixa)
                                        color: cm.card.withOpacity(0.12),
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        surfaceTintColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          side: BorderSide(
                                            color: cm.card.withOpacity(0.6),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // <-- AQUI: Header integrado no topo do Card
                                            UserProfileCardHeader(
                                              title: 'Meus Dados',
                                              leadingIcon: Icons.person_rounded,
                                              primary: cm.primary,
                                              borderRadius: 30,
                                              verticalPadding: 14 * uiScale,
                                              horizontalPadding: 18 * uiScale,
                                              scale: uiScale,
                                              trailing: Padding(
                                                padding: EdgeInsets.only(right: 8.0 * uiScale),
                                                child: SizedBox(
                                                  width: 0, // Sem trailing extra, mantém simetria
                                                ),
                                              ),
                                            ),

                                            // Conteúdo existente (exatamente como antes, apenas removi o Row de título anterior)
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: vw > 1200 ? 36.0 : 22.0,
                                                vertical: vh > 900 ? 28.0 : 20.0,
                                              ),
                                              child: Form(
                                                key: _formKey,
                                                child: LayoutBuilder(
                                                  builder: (context, inner) {
                                                    final innerW = inner.maxWidth;
                                                    final sectionSpacing = innerW > 1100
                                                        ? 22.0
                                                        : 14.0;
                                                    return Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        // OBS: A linha de título original (Icon + "Meus Dados") foi substituída pelo header acima.
                                                        SizedBox(height: sectionSpacing),
                                                        // Plano + Créditos
                                                        PairColumns(
                                                          left: PlanCard(
                                                            onTap: _goToPlans,
                                                            activePlan:
                                                                _plano?['nome'] ??
                                                                    'Sem plano',
                                                          ),
                                                          right: CreditsCard(
                                                            onTap: _goToPlans,
                                                            creditsAvailable:
                                                                _plano != null
                                                                    ? (_plano!['quantidade_credito_mensal'] ?? 0)
                                                                    : 0,
                                                            creditsIncludedPerMonth:
                                                                _plano != null
                                                                    ? (_plano!['quantidade_credito_mensal'] ?? 0)
                                                                    : 0,
                                                          ),
                                                        ),
                                                        SizedBox(height: sectionSpacing),
                                                        // Nome / Empresa (agora dropdown)
                                                        PairColumns(
                                                          left: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 0,
                                                                  bottom: 12,
                                                                ),
                                                            child: TextFormField(
                                                              controller: _nameCtrl,
                                                              decoration: fieldDecoration(
                                                                hint: 'Nome completo',
                                                                icon: Icons.badge_rounded,
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: cm.explicitText,
                                                              ),
                                                              validator: (v) =>
                                                                  (v == null ||
                                                                      v.trim().isEmpty)
                                                                      ? 'Informe o nome'
                                                                      : null,
                                                            ),
                                                          ),
                                                          right: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 0,
                                                                  bottom: 12,
                                                                ),
                                                            child: _loadingEmpresas
                                                                ? Padding(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical: 6.0,
                                                                        ),
                                                                    child: SizedBox(
                                                                      height: 56,
                                                                      child: Center(
                                                                        child:
                                                                            CircularProgressIndicator(),
                                                                      ),
                                                                    ),
                                                                  )
                                                                : DropdownButtonFormField<
                                                                    int?
                                                                  >(
                                                                      value:
                                                                          _selectedCompanyId,
                                                                      items: [
                                                                        const DropdownMenuItem<
                                                                          int?
                                                                        >(
                                                                          value: null,
                                                                          child: Text(
                                                                            'Sem empresa',
                                                                          ),
                                                                        ),
                                                                        ..._empresas.map((
                                                                          e,
                                                                        ) {
                                                                          final id =
                                                                              e['id']
                                                                                  as int?;
                                                                          final nome =
                                                                              e['nome']
                                                                                  as String? ??
                                                                                  '';
                                                                          return DropdownMenuItem<
                                                                            int?
                                                                          >(
                                                                            value: id,
                                                                            child: Text(
                                                                              nome,
                                                                            ),
                                                                          );
                                                                        }).toList(),
                                                                      ],
                                                                      onChanged: (v) =>
                                                                          setState(
                                                                            () =>
                                                                                _selectedCompanyId =
                                                                                    v,
                                                                          ),
                                                                      decoration:
                                                                          fieldDecoration(
                                                                            hint: 'Empresa',
                                                                            icon: Icons
                                                                                .business_rounded,
                                                                          ),
                                                                      isExpanded: true,
                                                                    ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: innerW > 1100 ? 18 : 6,
                                                        ),
                                                        // CPF / Email
                                                        PairColumns(
                                                          left: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 0,
                                                                  bottom: 12,
                                                                ),
                                                            child: TextFormField(
                                                              controller: _docCtrl,
                                                              decoration: fieldDecoration(
                                                                hint: 'CNPJ/CPF',
                                                                icon: Icons
                                                                    .description_rounded,
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: cm.explicitText,
                                                              ),
                                                            ),
                                                          ),
                                                          right: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 0,
                                                                  bottom: 12,
                                                                ),
                                                            child: TextFormField(
                                                              controller: _emailCtrl,
                                                              decoration: fieldDecoration(
                                                                hint: 'E-mail',
                                                                icon: Icons.email_rounded,
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: cm.explicitText,
                                                              ),
                                                              keyboardType: TextInputType
                                                                  .emailAddress,
                                                              validator: (v) {
                                                                if (v == null ||
                                                                    v.trim().isEmpty)
                                                                  return 'Informe o e-mail';
                                                                final valid = RegExp(
                                                                  r'^[^@]+@[^@]+\.[^@]+',
                                                                ).hasMatch(v);
                                                                return valid
                                                                    ? null
                                                                    : 'E-mail inválido';
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: innerW > 1100 ? 18 : 6,
                                                        ),
                                                        // Telefone / Documento
                                                        PairColumns(
                                                          left: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 0,
                                                                  bottom: 12,
                                                                ),
                                                            child: TextFormField(
                                                              controller: _phoneCtrl,
                                                              decoration: fieldDecoration(
                                                                hint: 'Telefone',
                                                                icon: Icons.phone_rounded,
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: cm.explicitText,
                                                              ),
                                                              keyboardType:
                                                                  TextInputType.phone,
                                                            ),
                                                          ),
                                                          right: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 0,
                                                                  bottom: 12,
                                                                ),
                                                            child: TextFormField(
                                                              controller: _dobCtrl,
                                                              readOnly: true,
                                                              onTap: _pickDate,
                                                              decoration: fieldDecoration(
                                                                hint:
                                                                    'Data de nascimento (YYYY-MM-DD)',
                                                                icon: Icons.cake_rounded,
                                                              ),
                                                              style: TextStyle(
                                                                color: cm.explicitText,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: innerW > 1100 ? 18 : 6,
                                                        ),
                                                        // Cidade | Estado
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              flex: 2,
                                                              child: TextFormField(
                                                                controller: _cityCtrl,
                                                                decoration: fieldDecoration(
                                                                  hint: 'Cidade',
                                                                  icon: Icons
                                                                      .location_city_rounded,
                                                                ),
                                                                validator: (v) =>
                                                                    (v == null ||
                                                                        v.trim().isEmpty)
                                                                        ? 'Informe a cidade'
                                                                        : null,
                                                                style: TextStyle(
                                                                  color: cm.explicitText,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              flex: 1,
                                                              child:
                                                                  DropdownButtonFormField<
                                                                      String
                                                                  >(
                                                                    value: _stateValue,
                                                                    items: _states
                                                                        .map(
                                                                          (s) =>
                                                                              DropdownMenuItem(
                                                                                value: s,
                                                                                child:
                                                                                    Text(
                                                                                      s,
                                                                                    ),
                                                                              ),
                                                                        )
                                                                        .toList(),
                                                                    onChanged: (v) =>
                                                                        setState(
                                                                          () => _stateValue =
                                                                              v ??
                                                                              _stateValue,
                                                                        ),
                                                                    decoration:
                                                                        fieldDecoration(
                                                                          hint: 'UF',
                                                                          icon: Icons
                                                                              .map_rounded,
                                                                        ),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: sectionSpacing),
                                                        _buildContasCard(innerW, cm),
                                                        SizedBox(height: sectionSpacing),
                                                        Row(
                                                          children: [
                                                            const Spacer(),
                                                            ElevatedButton.icon(
                                                              onPressed: _saving
                                                                  ? null
                                                                  : _save,
                                                              icon: _saving
                                                                  ? const SizedBox(
                                                                      width: 16,
                                                                      height: 16,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                            strokeWidth:
                                                                                2,
                                                                          ),
                                                                    )
                                                                  : Icon(
                                                                      Icons.save_rounded,
                                                                      color: cm.text,
                                                                    ),
                                                              label: Text(
                                                                _saving
                                                                    ? 'Salvando...'
                                                                    : 'Salvar alterações',
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight.w800,
                                                                  color: cm.text,
                                                                ),
                                                              ),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: cm.ok,
                                                                padding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          innerW > 1100
                                                                              ? 22
                                                                              : 18,
                                                                      vertical:
                                                                          innerW > 1100
                                                                              ? 16
                                                                              : 14,
                                                                    ),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        14,
                                                                      ),
                                                                ),
                                                                textStyle: TextStyle(
                                                                  fontSize: innerW > 1100
                                                                      ? 17
                                                                      : 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Scroll hint banner posicionado na parte inferior, exibido apenas se não foi descartado
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
            ),
          ),
        );
      },
    );
  }
}
