import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:planos/provider/userProvider.dart';
import 'package:planos/screens/histoy/models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HistoryService {
  final UserProvider userProvider;

  HistoryService(this.userProvider);

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) return dt;
      final numVal = int.tryParse(raw);
      if (numVal != null) return DateTime.fromMillisecondsSinceEpoch(numVal);
    }
    return DateTime.now();
  }

  String _stripDiacritics(String s) {
    var out = s;
    const from = 'áàãâäÁÀÃÂÄéèêëÉÈÊËíìîïÍÌÎÏóòõôöÓÒÕÔÖúùûüÚÙÛÜçÇñÑ';
    const to   = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcCnN';
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  String _norm(String? s) {
    if (s == null) return '';
    final t = s.toString().trim().toLowerCase();
    return _stripDiacritics(t);
  }

  HistoryStatus _statusFromStrings({String? resultadoFinal, String? serverStatus}) {
    final rf = _norm(resultadoFinal);
    final ss = _norm(serverStatus);

    // Checar incompatível primeiro (evita casar "compat" dentro de "incompat")
    if (rf.isNotEmpty) {
      if (rf.contains('incompat') || rf.contains('incompativ') || rf.contains('incompatible') || (rf.contains('nao') && rf.contains('compat'))) {
        return HistoryStatus.incompatible;
      }
      if (rf.contains('parc') || rf.contains('partial')) {
        return HistoryStatus.partial;
      }
      if (rf.contains('compat') || rf.contains('compatible')) {
        return HistoryStatus.compatible;
      }
    }

    // Fallback para status do servidor
    if (ss.isNotEmpty) {
      if (ss.contains('incompat') || ss.contains('incomp')) return HistoryStatus.incompatible;
      if (ss.contains('parc') || ss.contains('parcial') || ss.contains('partial')) return HistoryStatus.partial;
      if (ss.contains('em_andamento') || ss.contains('andamento') || ss.contains('em analise')) return HistoryStatus.inProgress;
      if (ss.contains('finaliz') || ss.contains('conclu')) return HistoryStatus.compatible;
    }

    // Default
    return HistoryStatus.inProgress;
  }

  Future<List<HistoryItem>> fetchHistory() async {
    if (!userProvider.isLoggedIn) return [];

    final token = userProvider.user?.token ?? '';
    if (token.isEmpty) return [];

    final url = Uri.parse('${dotenv.env['BASE_URL']}/solicitacoes');
    final resp = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (resp.statusCode != 200) {
      throw Exception('Falha ao carregar histórico: ${resp.statusCode} ${resp.body}');
    }

    final rawList = json.decode(resp.body);
    if (rawList is! List) return [];

    final List<HistoryItem> items = [];

    for (final raw in rawList) {
      if (raw == null || raw is! Map) continue;
      final Map<String, dynamic> jsonItem = Map<String, dynamic>.from(raw);

      final dateRaw = jsonItem['data_resultado'] ?? jsonItem['data_solicitacao'] ?? jsonItem['criado_em'];
      final date = _parseDate(dateRaw);

      // produto_quimico
      String chemicalStr = '';
      final pq = jsonItem['produto_quimico'];
      if (pq is Map) {
        chemicalStr = (pq['nome'] ?? pq['nome_produto_quimico'] ?? jsonItem['nome_produto_quimico'] ?? '').toString();
      } else {
        chemicalStr = (jsonItem['nome_produto_quimico'] ?? jsonItem['nome_quimico'] ?? '').toString();
      }

      // produto_biologico
      String biologicalStr = '';
      final pb = jsonItem['produto_biologico'];
      if (pb is Map) {
        biologicalStr = (pb['nome'] ?? pb['nome_produto_biologico'] ?? jsonItem['nome_produto_biologico'] ?? '').toString();
      } else {
        biologicalStr = (jsonItem['nome_produto_biologico'] ?? jsonItem['nome_biologico'] ?? '').toString();
      }

      // resultado_final
      String? resultadoFinal;
      if (jsonItem.containsKey('resultado_final') && jsonItem['resultado_final'] != null) {
        resultadoFinal = jsonItem['resultado_final'].toString().trim();
      } else if (jsonItem.containsKey('_catalog_resultado_final') && jsonItem['_catalog_resultado_final'] != null) {
        resultadoFinal = jsonItem['_catalog_resultado_final'].toString().trim();
      }

      // descricao_resultado
      String? descricao;
      if (jsonItem.containsKey('descricao_resultado') && jsonItem['descricao_resultado'] != null) {
        descricao = jsonItem['descricao_resultado'].toString().trim();
      } else if (jsonItem.containsKey('_catalog_descricao_resultado') && jsonItem['_catalog_descricao_resultado'] != null) {
        descricao = jsonItem['_catalog_descricao_resultado'].toString().trim();
      } else if (jsonItem.containsKey('descricao') && jsonItem['descricao'] != null) {
        descricao = jsonItem['descricao'].toString().trim();
      } else if (jsonItem.containsKey('description') && jsonItem['description'] != null) {
        descricao = jsonItem['description'].toString().trim();
      }

      if (resultadoFinal != null && resultadoFinal.isEmpty) resultadoFinal = null;
      if (descricao != null && descricao.isEmpty) descricao = null;

      final serverStatus = (jsonItem['status'] ?? jsonItem['estado'] ?? '').toString();

      final status = _statusFromStrings(resultadoFinal: resultadoFinal, serverStatus: serverStatus);

      items.add(HistoryItem(
        date: date,
        chemical: chemicalStr,
        biological: biologicalStr,
        status: status,
        resultFinal: resultadoFinal,
        description: descricao,
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }
}
