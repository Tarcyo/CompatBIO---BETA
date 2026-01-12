import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/history_admin/soicitacao.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Modal de detalhe e vincular (modularizado).
class DetalleModal extends StatefulWidget {
  final Solicitacao s;
  final Future<bool> Function(String resultado, String descricao) onVinculado;
  const DetalleModal({required this.s, required this.onVinculado, Key? key})
      : super(key: key);

  @override
  State<DetalleModal> createState() => _DetalleModalState();
}

class _DetalleModalState extends State<DetalleModal> {
  late TextEditingController _resultadoController;
  late TextEditingController _descricaoController;
  String? _selectedResultado;
  bool _sending = false;

  bool _checkingCatalog = true;
  String? _catalogResultadoFinal;
  String? _catalogDescricao;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    _resultadoController = TextEditingController(
      text: widget.s.resultadoFinal ?? '',
    );

    String desc = '';
    try {
      final raw = widget.s.rawData;
      if (raw.containsKey('descricao_resultado') &&
          raw['descricao_resultado'] != null) {
        desc = raw['descricao_resultado'].toString();
      } else if (raw.containsKey('descricao') && raw['descricao'] != null) {
        desc = raw['descricao'].toString();
      } else if (raw.containsKey('resultado_final') &&
          raw['resultado_final'] != null &&
          (widget.s.resultadoFinal == null ||
              widget.s.resultadoFinal!.isEmpty)) {
        desc = raw['resultado_final'].toString();
      }
    } catch (_) {
      desc = '';
    }
    _descricaoController = TextEditingController(text: desc);

    // Map any initial text to one of the dropdown values or null.
    _selectedResultado = _mapToDropdownValue(_resultadoController.text);

    _checkCatalogForThisPair();
  }

  @override
  void dispose() {
    _resultadoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  // normalize string: lower, remove accents common to pt-BR
  String _normalize(String? s) {
    if (s == null) return '';
    var str = s.toLowerCase();
    str = str.replaceAll(RegExp('[áàãâä]'), 'a');
    str = str.replaceAll(RegExp('[éèêẽ]'), 'e');
    str = str.replaceAll(RegExp('[íìî]'), 'i');
    str = str.replaceAll(RegExp('[óòôõ]'), 'o');
    str = str.replaceAll(RegExp('[úùû]'), 'u');
    str = str.replaceAll('ç', 'c');
    // remove other non-alphanumeric to make matching tolerant
    str = str.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return str;
  }

  /// Retorna um dos valores exatos do dropdown ou null.
  /// Valores do dropdown (mantidos): 'compativel', 'incompativel', 'parcial'
  String? _mapToDropdownValue(String? raw) {
    final n = _normalize(raw);
    if (n.isEmpty) return null;

    // detecta parcialmente para cobrir variações como "compatível", "compativel", "compat", "compativel"
    if (n.contains('incomp') || n.contains('incompat')) {
      return 'incompativel';
    }
    if (n.contains('comp') || n.contains('compat')) {
      return 'compativel';
    }
    if (n.contains('parc')) {
      return 'parcial';
    }
    return null;
  }

  /// NEW: versão mais robusta — aceita backend que retorne nomes no topo
  /// (nome_produto_quimico / nome_produto_biologico) **ou**
  /// objetos aninhados produto_quimico.nome / produto_biologico.nome.
  Future<void> _checkCatalogForThisPair() async {
    setState(() {
      _checkingCatalog = true;
      _catalogResultadoFinal = null;
      _catalogDescricao = null;
      _catalogError = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.user?.token;
      if (token == null || token.isEmpty) {
        setState(() {
          _catalogError = 'Token ausente — autentique-se.';
          _checkingCatalog = false;
        });
        return;
      }

      final resp = await http.get(
        Uri.parse('${dotenv.env['BASE_URL']}/resultados'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final List parsed = json.decode(resp.body) as List;
        final nomeQuim = widget.s.nomeProdutoQuimico;
        final nomeBio = widget.s.nomeProdutoBiologico;

        // procura por correspondência suportando duas formas:
        // 1) top-level: m['nome_produto_quimico'] / m['nome_produto_biologico']
        // 2) nested:  m['produto_quimico']?['nome'] / m['produto_biologico']?['nome']
        final match = parsed.cast<Map<String, dynamic>>().firstWhere(
          (m) {
            String qTop = (m['nome_produto_quimico']?.toString() ?? '');
            String bTop = (m['nome_produto_biologico']?.toString() ?? '');
            String qNested = (m['produto_quimico'] is Map
                ? (m['produto_quimico']['nome']?.toString() ?? '')
                : '');
            String bNested = (m['produto_biologico'] is Map
                ? (m['produto_biologico']['nome']?.toString() ?? '')
                : '');

            // compara preferindo top-level (compat com front antigo), mas aceita nested
            final quimMatch = qTop == nomeQuim || qNested == nomeQuim;
            final bioMatch = bTop == nomeBio || bNested == nomeBio;
            return quimMatch && bioMatch;
          },
          orElse: () => <String, dynamic>{},
        );

        if (match.isNotEmpty) {
          final resultadoFinal = (match['resultado_final']?.toString() ?? '').trim();
          final descricao = (match['descricao_resultado']?.toString() ?? '').trim();

          setState(() {
            _catalogResultadoFinal = resultadoFinal.isNotEmpty ? resultadoFinal : null;
            _catalogDescricao = descricao.isNotEmpty ? descricao : null;
            _checkingCatalog = false;
          });
        } else {
          setState(() {
            _checkingCatalog = false;
            _catalogResultadoFinal = null;
            _catalogDescricao = null;
          });
        }
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        setState(() {
          _catalogError = 'Sem permissão para consultar catálogo de resultados.';
          _checkingCatalog = false;
        });
      } else {
        setState(() {
          _catalogError = 'Falha ao consultar catálogo (${resp.statusCode}).';
          _checkingCatalog = false;
        });
      }
    } catch (e, st) {
      debugPrint('Erro ao consultar catálogo de resultados: $e\n$st');
      setState(() {
        _catalogError = 'Erro de rede ao consultar catálogo.';
        _checkingCatalog = false;
      });
    }
  }

  void _carregarParaCampos() {
    final toSetResultado = _catalogResultadoFinal ?? (_catalogDescricao ?? '');
    setState(() {
      _resultadoController.text = toSetResultado;
      _descricaoController.text = _catalogDescricao ?? '';
      // map to dropdown canonical value if possible and trigger rebuild
      _selectedResultado = _mapToDropdownValue(toSetResultado);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cm = ColorManager.instance;
    // Mesmo tom suave do LabMinimalScreen:
    final softCardColor = cm.card.withOpacity(0.12);
    final borderSide = BorderSide(color: cm.card.withOpacity(0.6), width: 1.2);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.56,
      minChildSize: 0.32,
      maxChildSize: 0.92,
      builder: (context, scroll) {
        // Card suave cobrindo todo o modal, semelhante ao estilo do LabMinimalScreen
        return Card(
          color: softCardColor,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            side: borderSide,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: LayoutBuilder(builder: (context, constraints) {
              // ajusta espaçamentos e fontes levemente conforme largura disponível
              final isNarrow = constraints.maxWidth < 420;
              final titleStyle = TextStyle(
                fontSize: isNarrow ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: cm.explicitText,
              );
              final labelStyle = TextStyle(
                fontWeight: FontWeight.w600,
                color: cm.explicitText,
              );

              return ListView(
                controller: scroll,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cm.background.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Solicitação #${widget.s.id} • Prioridade ${widget.s.prioridade}',
                    style: titleStyle,
                  ),
                  const SizedBox(height: 12),
                  if (_checkingCatalog)
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cm.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Verificando catálogo de resultados...',
                            style: TextStyle(
                              color: cm.explicitText.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_catalogError != null)
                    Row(
                      children: [
                        Icon(Icons.error_rounded, color: cm.emergency),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _catalogError!,
                            style: TextStyle(color: cm.emergency),
                          ),
                        ),
                      ],
                    )
                  else if (_catalogResultadoFinal != null ||
                      _catalogDescricao != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cm.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cm.card.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resultado disponível no catálogo:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cm.explicitText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _catalogResultadoFinal ?? _catalogDescricao ?? '-',
                                  style: TextStyle(
                                    fontSize: isNarrow ? 14 : 15,
                                    color: _catalogResultadoFinal != null
                                        ? cm.ok
                                        : cm.explicitText.withOpacity(0.87),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _carregarParaCampos,
                                icon: Icon(
                                  Icons.cloud_download_rounded,
                                  color: cm.text,
                                  size: isNarrow ? 16 : 18,
                                ),
                                label: Text(
                                  'Carregar resultado',
                                  style: TextStyle(color: cm.text),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cm.primary,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isNarrow ? 8 : 12,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_catalogDescricao != null &&
                              (_catalogDescricao!.isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _catalogDescricao!,
                                style: TextStyle(
                                  color: cm.explicitText.withOpacity(0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cm.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cm.card.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Nenhum resultado no catálogo para esta combinação (químico + biológico).',
                        style: TextStyle(color: cm.explicitText),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Produto Químico',
                    style: labelStyle.copyWith(
                      color: cm.explicitText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.s.nomeProdutoQuimico,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cm.explicitText),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Produto Biológico',
                    style: labelStyle.copyWith(
                      color: cm.explicitText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.s.nomeProdutoBiologico,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cm.explicitText),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Resultado final',
                    style: labelStyle.copyWith(color: cm.explicitText),
                  ),
                  const SizedBox(height: 8),
                  // >>> DROPDOWN em vez de campo de texto
                  DropdownButtonFormField<String>(
                    value: _selectedResultado,
                    items: const [
                      DropdownMenuItem(
                        value: 'compativel',
                        child: Text('Compatível'),
                      ),
                      DropdownMenuItem(
                        value: 'incompativel',
                        child: Text('Incompatível'),
                      ),
                      DropdownMenuItem(value: 'parcial', child: Text('Parcial')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedResultado = v;
                        // keep text field synced with dropdown canonical value
                        _resultadoController.text = v ?? '';
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Selecione o resultado',
                      filled: true,
                      fillColor: cm.background.withOpacity(0.98),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Descrição do resultado (opcional)',
                    style: labelStyle.copyWith(color: cm.explicitText),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descricaoController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Observações, metodologia, notas...',
                      filled: true,
                      fillColor: cm.background.withOpacity(0.98),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: cm.explicitText),
                  ),
                  const SizedBox(height: 14),
                  // Buttons: em telas estreitas, quebram em coluna para não apertar
                  Builder(builder: (context) {
                    final narrow = MediaQuery.of(context).size.width < 420;
                    return narrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text(
                                  'Fechar',
                                  style: TextStyle(color: cm.explicitText),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _sending
                                    ? null
                                    : () async {
                                        final texto = (_selectedResultado ??
                                                _resultadoController.text)
                                            .trim();
                                        final descricao =
                                            _descricaoController.text.trim();
                                        if (texto.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Informe o resultado antes de vincular.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        setState(() => _sending = true);
                                        final ok = await widget.onVinculado(
                                          texto,
                                          descricao,
                                        );
                                        setState(() => _sending = false);
                                        if (ok) {
                                          Navigator.of(context).pop(true);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Falha ao vincular resultado.'),
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: cm.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _sending
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cm.text,
                                        ),
                                      )
                                    : Text(
                                        'Vincular resultado!',
                                        style: TextStyle(color: cm.text),
                                      ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text(
                                  'Fechar',
                                  style: TextStyle(color: cm.explicitText),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _sending
                                    ? null
                                    : () async {
                                        final texto = (_selectedResultado ??
                                                _resultadoController.text)
                                            .trim();
                                        final descricao =
                                            _descricaoController.text.trim();
                                        if (texto.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Informe o resultado antes de vincular.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        setState(() => _sending = true);
                                        final ok = await widget.onVinculado(
                                          texto,
                                          descricao,
                                        );
                                        setState(() => _sending = false);
                                        if (ok) {
                                          Navigator.of(context).pop(true);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Falha ao vincular resultado.'),
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: cm.primary,
                                ),
                                child: _sending
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cm.text,
                                        ),
                                      )
                                    : Text(
                                        'Vincular resultado!',
                                        style: TextStyle(color: cm.text),
                                      ),
                              ),
                            ],
                          );
                  }),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}
