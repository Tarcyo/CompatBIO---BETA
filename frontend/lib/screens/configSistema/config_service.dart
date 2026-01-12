// FILE: lib/services/config_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:planos/screens/configSistema/configClass.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  final String baseUrl=dotenv.env['BASE_URL']!;

  ConfigService();
  /// Busca a configuração mais recente. Retorna null em 404.
  Future<ConfigSistema?> fetchLatest(String? token) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.get(Uri.parse('$baseUrl/config/latest'), headers: headers);

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body);
      return ConfigSistema.fromJson(body);
    }

    if (resp.statusCode == 404) return null;

    throw Exception('Erro ${resp.statusCode}: ${resp.body}');
  }

  /// Cria uma nova configuração (POST). Retorna o Response para permitir
  /// tratamento de status pelo chamador.
  Future<http.Response> createConfig(String token, Map<String, dynamic> payload) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/config'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );

    return resp;
  }
}
