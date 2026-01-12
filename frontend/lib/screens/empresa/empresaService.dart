// FILE: lib/services/empresa_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:planos/screens/empresa/empresaClass.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmpresaService {
final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  Future<List<Empresa>> fetchEmpresas(String? token) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.get(Uri.parse('$baseUrl/empresas'), headers: headers);
    if (resp.statusCode == 200) {
      final body = json.decode(resp.body);
      final list = (body['empresas'] as List<dynamic>?) ?? [];
      return list.map((e) => Empresa.fromJson(e)).toList();
    }

    throw Exception(resp.body.isNotEmpty ? resp.body : 'Erro ${resp.statusCode}');
  }
}
