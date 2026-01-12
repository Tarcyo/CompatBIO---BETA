// lib/screens/resultadosAdmin/result_row.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/resultadosAdmin/result_utils.dart';
import 'package:planos/screens/resultadosAdmin/resultadoItem.dart';
import 'package:planos/styles/syles.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ResultRow extends StatelessWidget {
  final ResultadoItem r;
  final bool isMobile;
  final void Function(String text, String label) copyCallback;
  final void Function()? onDeleted; // callback para pai
  final void Function(ResultadoItem updated)? onUpdated; // callback para pai

  const ResultRow({
    super.key,
    required this.r,
    required this.isMobile,
    required this.copyCallback,
    this.onDeleted,
    this.onUpdated,
  });

  static final baseUrl = '${dotenv.env['BASE_URL']}/resultados';

  Future<String?> _getToken(BuildContext context) async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    return userProv.user?.token;
  }

  Future<void> _deleteResultado(BuildContext context) async {
    final token = await _getToken(context);
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Deseja realmente excluir o resultado "${r.nomeQuimico} - ${r.nomeBiologico}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final resp = await http.delete(
        Uri.parse('$baseUrl/${r.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resultado excluído com sucesso')),
        );
        if (onDeleted != null) onDeleted!();
      } else {
        final decoded = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
        final message = decoded is Map && decoded['error'] != null
            ? decoded['error']
            : 'Erro ao excluir (status ${resp.statusCode})';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  Future<void> _editResultado(BuildContext context) async {
    final token = await _getToken(context);
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }

    final descricaoController = TextEditingController(text: r.descricao);

    const options = ['Compatível', 'Incompatível', 'Parcial'];
    String? selectedResultado =
        (r.resultadoFinal != null && options.contains(r.resultadoFinal))
            ? r.resultadoFinal
            : null;

    final updated = await showDialog<ResultadoItem?>(
      context: context,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder: (ctxSt, setState) {
            return AlertDialog(
              title: const Text('Editar resultado'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedResultado,
                        items: options
                            .map(
                              (o) => DropdownMenuItem<String>(
                                value: o,
                                child: Text(o),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Resultado final',
                        ),
                        onChanged: (val) =>
                            setState(() => selectedResultado = val),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descricaoController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(
                      ResultadoItem(
                        id: r.id,
                        nomeQuimico: r.nomeQuimico,
                        nomeBiologico: r.nomeBiologico,
                        resultadoFinal: selectedResultado,
                        descricao: descricaoController.text.isEmpty
                            ? null
                            : descricaoController.text,
                        criadoEm: r.criadoEm,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == null) return;

    final Map<String, dynamic> body = {};
    if ((updated.resultadoFinal ?? '') != (r.resultadoFinal ?? '')) {
      body['resultado_final'] = updated.resultadoFinal;
    }
    if ((updated.descricao ?? '') != (r.descricao ?? '')) {
      body['descricao_resultado'] = updated.descricao;
    }

    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma alteração detectada')),
      );
      return;
    }

    try {
      final resp = await http.put(
        Uri.parse('$baseUrl/${r.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ResultadoItem novoItem = updated;
        if (resp.body.isNotEmpty) {
          final decoded = jsonDecode(resp.body);
          try {
            novoItem = ResultadoItem.fromJson(decoded);
          } catch (_) {
            // usa updated se parse falhar
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resultado atualizado com sucesso')),
        );
        if (onUpdated != null) onUpdated!(novoItem);
      } else if (resp.statusCode == 409) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Violação de par único.')));
      } else {
        final decoded = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
        final message = decoded is Map && decoded['error'] != null
            ? decoded['error']
            : 'Erro ao atualizar (status ${resp.statusCode})';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = badgeColorForResultado(r.resultadoFinal);
    final badgeIcon = iconForResultado(r.resultadoFinal);

    return AnimatedBuilder(
      animation: ColorManager.instance,
      builder: (context, _) {
        final cm = ColorManager.instance;

        if (isMobile) {
          return Card(
            color: Colors.white,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cm.card.withOpacity(0.6)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.nomeQuimico,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cm.explicitText,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: cm.card.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cm.card.withOpacity(0.6),
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Editar',
                                      onPressed: () => _editResultado(context),
                                      icon: Icon(
                                        Icons.edit_rounded,
                                        color: cm.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: cm.card.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cm.card.withOpacity(0.6),
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Deletar',
                                      onPressed: () => _deleteResultado(context),
                                      icon: Icon(
                                        Icons.delete_rounded,
                                        color: cm.emergency,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.nomeBiologico,
                            style: TextStyle(color: cm.explicitText),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.descricao ?? '-',
                            style: TextStyle(color: cm.explicitText),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                constraints: const BoxConstraints(minWidth: 96),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(badgeIcon, size: 14, color: cm.text),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        labelForResultado(r.resultadoFinal),
                                        style: TextStyle(
                                          color: cm.text,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: cm.explicitText.withOpacity(0.65),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                r.criadoEm != null ? formatDate(r.criadoEm!) : '-',
                                style: TextStyle(
                                  color: cm.explicitText.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cm.card.withOpacity(0.6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 72,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          r.nomeQuimico,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cm.explicitText,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          r.nomeBiologico,
                          style: TextStyle(color: cm.explicitText),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          r.descricao ?? '-',
                          style: TextStyle(color: cm.explicitText),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 96),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(badgeIcon, size: 14, color: cm.text),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  labelForResultado(r.resultadoFinal),
                                  style: TextStyle(
                                    color: cm.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: cm.explicitText.withOpacity(0.65),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              r.criadoEm != null ? formatDate(r.criadoEm!) : '-',
                              style: TextStyle(
                                color: cm.explicitText.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: cm.card.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cm.card.withOpacity(0.6)),
                        ),
                        child: IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _editResultado(context),
                          icon: Icon(Icons.edit_rounded, color: cm.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: cm.card.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cm.card.withOpacity(0.6)),
                        ),
                        child: IconButton(
                          tooltip: 'Deletar',
                          onPressed: () => _deleteResultado(context),
                          icon: Icon(Icons.delete_rounded, color: cm.emergency),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
