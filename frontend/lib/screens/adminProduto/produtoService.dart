// FILE: lib/screens/adminProduto/produtoService.dart
// (modificado a partir do seu arquivo produtos_service.dart — mesma classe, mesmo comportamento)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:planos/screens/adminProduto/produtoItem.dart';

class ProdutosService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  Future<List<ProdutoItem>> fetchProdutos(String token) async {
    // tentativa 1: buscar endpoints administrativos que retornam listas com id/nome/tipo
    final bioUrl = Uri.parse('$baseUrl/produtos/biologicos');
    final quimUrl = Uri.parse('$baseUrl/produtos/quimicos');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final List<ProdutoItem> list = [];

    try {
      final responses = await Future.wait([
        http.get(bioUrl, headers: headers),
        http.get(quimUrl, headers: headers),
      ]);

      final respBio = responses[0];
      final respQuim = responses[1];

      if (respBio.statusCode == 200) {
        final parsed = json.decode(respBio.body);
        if (parsed is List) {
          for (final item in parsed) {
            if (item is Map<String, dynamic>) {
              list.add(ProdutoItem.fromMap(item));
            } else if (item is Map) {
              list.add(ProdutoItem.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        }
      } else if (respBio.statusCode == 401 || respBio.statusCode == 403) {
        // permission issues - bubble up by throwing
        throw Exception('Sem permissão para listar biológicos (${respBio.statusCode})');
      }

      if (respQuim.statusCode == 200) {
        final parsed = json.decode(respQuim.body);
        if (parsed is List) {
          for (final item in parsed) {
            if (item is Map<String, dynamic>) {
              list.add(ProdutoItem.fromMap(item));
            } else if (item is Map) {
              list.add(ProdutoItem.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        }
      } else if (respQuim.statusCode == 401 || respQuim.statusCode == 403) {
        throw Exception('Sem permissão para listar químicos (${respQuim.statusCode})');
      }

      // Se ao menos um dos endpoints respondeu 200, retornamos a lista construída
      if (list.isNotEmpty) {
        // ordenar por categoria, tipo, nome
        list.sort((a, b) {
          final c = a.categoria.index.compareTo(b.categoria.index);
          if (c != 0) return c;
          final t = a.tipo.compareTo(b.tipo);
          if (t != 0) return t;
          return a.nome.compareTo(b.nome);
        });
        return list;
      }

      // Caso ambos endpoints não retornaram 200 (por exemplo não-existentes),
      // fallback para rota antiga: GET /produtos que retorna mapas agrupados por tipo -> nomes
    } catch (e) {
      // não falhar imediatamente — tentaremos o fallback abaixo
    }

    // --- fallback: rota /produtos (agrupada por tipo -> lista de nomes) ---
    final urlFallback = Uri.parse('$baseUrl/produtos');
    final resp = await http.get(urlFallback, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Erro ${resp.statusCode}');
    }

    final Map<String, dynamic> parsed = json.decode(resp.body);
    if (parsed['produtos_biologicos'] is Map) {
      (parsed['produtos_biologicos'] as Map).forEach((tipo, nomes) {
        if (nomes is List) {
          for (var n in nomes) {
            list.add(ProdutoItem(
              id: null,
              nome: n?.toString() ?? '',
              tipo: tipo?.toString() ?? '',
              categoria: ProdutoCategoria.biologico,
            ));
          }
        }
      });
    }

    if (parsed['produtos_quimicos'] is Map) {
      (parsed['produtos_quimicos'] as Map).forEach((tipo, nomes) {
        if (nomes is List) {
          for (var n in nomes) {
            list.add(ProdutoItem(
              id: null,
              nome: n?.toString() ?? '',
              tipo: tipo?.toString() ?? '',
              categoria: ProdutoCategoria.quimico,
            ));
          }
        }
      });
    }

    list.sort((a, b) {
      final c = a.categoria.index.compareTo(b.categoria.index);
      if (c != 0) return c;
      final t = a.tipo.compareTo(b.tipo);
      if (t != 0) return t;
      return a.nome.compareTo(b.nome);
    });

    return list;
  }

  /// agora com o campo `demo` (boolean) enviado ao backend
  Future<http.Response> createProduto({
    required String token,
    required String nome,
    required String tipo,
    required ProdutoCategoria categoria,
    required bool demo, // novo parâmetro
  }) async {
    final route = categoria == ProdutoCategoria.biologico
        ? '/produtos/biologicos'
        : '/produtos/quimicos';
    final url = Uri.parse('$baseUrl$route');

    final Map<String, dynamic> bodyMap = {
      'nome': nome,
      'tipo': tipo,
      'demo': demo,
    };

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(bodyMap),
    );

    return resp;
  }
}
