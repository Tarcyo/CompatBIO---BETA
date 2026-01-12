// lib/screens/resultadosAdmin/product_simple.dart
import 'dart:convert';

class ProdutoSimple {
  final String nome;
  final String tipo;
  const ProdutoSimple({required this.nome, required this.tipo});

  ProdutoSimple copyWith({String? nome, String? tipo}) {
    return ProdutoSimple(
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'tipo': tipo,
      };

  factory ProdutoSimple.fromMap(Map<String, dynamic> map) {
    return ProdutoSimple(
      nome: map['nome']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory ProdutoSimple.fromJson(String source) =>
      ProdutoSimple.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => nome;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoSimple &&
          runtimeType == other.runtimeType &&
          nome == other.nome &&
          tipo == other.tipo;

  @override
  int get hashCode => nome.hashCode ^ tipo.hashCode;
}
