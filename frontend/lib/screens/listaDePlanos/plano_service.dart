// FILE: lib/services/plano_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:planos/screens/listaDePlanos/plano_class.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlanoService {
  // safer retrieval of BASE_URL (avoid crash if env var missing)
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  void _ensureBaseUrl() {
    if (baseUrl.isEmpty) {
      throw StateError('BASE_URL não configurado. Defina a variável de ambiente BASE_URL.');
    }
  }

  Map<String, String> _buildHeaders(String? token) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  /// Busca todos os planos.
  /// Se token for fornecido, inclui Authorization header.
  Future<List<Plano>> fetchPlanos(String? token) async {
    _ensureBaseUrl();
    final headers = _buildHeaders(token);

    final resp = await http.get(Uri.parse('$baseUrl/planos'), headers: headers);

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body) as List<dynamic>;
      return body.map((e) => Plano.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw Exception(resp.body.isNotEmpty ? resp.body : 'Erro ${resp.statusCode}');
  }

  /// Cria um novo plano. payload deve conter os campos esperados pelo backend,
  /// por exemplo:
  /// {
  ///  'nome': 'Pro',
  ///  'prioridade_de_tempo': 1,
  ///  'quantidade_credito_mensal': 10,
  ///  'preco_mensal': '49.90',
  ///  'stripe_price_id': 'price_xxx',        // opcional
  ///  'maximo_colaboradores': 10            // opcional (0 = ilimitado)
  /// }
  Future<http.Response> createPlano(String token, Map<String, dynamic> payload) async {
    _ensureBaseUrl();
    final headers = _buildHeaders(token);
    final resp = await http.post(Uri.parse('$baseUrl/planos'), headers: headers, body: json.encode(payload));
    return resp;
  }

  /// Atualiza um plano existente (PUT /planos/:id)
  /// Payload segue o mesmo formato de createPlano; envie somente os campos a alterar.
  Future<http.Response> updatePlano(String token, int id, Map<String, dynamic> payload) async {
    _ensureBaseUrl();
    final headers = _buildHeaders(token);
    final resp = await http.put(Uri.parse('$baseUrl/planos/$id'), headers: headers, body: json.encode(payload));
    return resp;
  }

  /// Deleta um plano (DELETE /planos/:id)
  Future<http.Response> deletePlano(String token, int id) async {
    _ensureBaseUrl();
    final headers = _buildHeaders(token);
    final resp = await http.delete(Uri.parse('$baseUrl/planos/$id'), headers: headers);
    return resp;
  }
}
