enum ProdutoCategoria { todos, biologico, quimico }

class ProdutoItem {
  final int? id;
  final String nome;
  final String tipo;
  final ProdutoCategoria categoria;
  final bool demo;

  ProdutoItem({
    this.id,
    required this.nome,
    required this.tipo,
    required this.categoria,
    this.demo = false,
  });

  /// Cria um ProdutoItem a partir do mapa retornado pelo backend.
  /// Aceita variações nos nomes das chaves e tipos (int/string/bool).
  factory ProdutoItem.fromMap(Map<String, dynamic> m) {
    int? parsedId;
    final rawId = m['id'];
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId is String) {
      parsedId = int.tryParse(rawId);
    }

    final nome = (m['nome'] ?? m['name'] ?? '')?.toString() ?? '';
    final tipo = (m['tipo'] ?? m['type'] ?? '')?.toString() ?? '';

    // aceita "genero", "genero_produto", "categoria" como fontes possíveis
    final rawGenero = (m['genero'] ?? m['genero_produto'] ?? m['categoria'] ?? '')?.toString() ?? '';
    final genero = rawGenero.toLowerCase().trim();

    ProdutoCategoria categoria;
    if (genero.contains('bio')) {
      categoria = ProdutoCategoria.biologico;
    } else if (genero.contains('quim')) {
      categoria = ProdutoCategoria.quimico;
    } else {
      // fallback: tentar inferir por tipo (opcional)
      final t = tipo.toLowerCase();
      if (t.contains('bio')) {
        categoria = ProdutoCategoria.biologico;
      } else if (t.contains('quim')) {
        categoria = ProdutoCategoria.quimico;
      } else {
        categoria = ProdutoCategoria.todos;
      }
    }

    // parse do campo demo (aceita bool, int, string)
    bool parseDemo(dynamic d) {
      if (d == null) return false;
      if (d is bool) return d;
      if (d is int) return d == 1;
      if (d is String) {
        final v = d.toLowerCase().trim();
        return v == '1' || v == 'true' || v == 'true' || v == 'sim' || v == 's' || v == 'yes' || v == 'y';
      }
      return false;
    }

    final demo = parseDemo(m['demo']);

    return ProdutoItem(
      id: parsedId,
      nome: nome,
      tipo: tipo,
      categoria: categoria,
      demo: demo,
    );
  }

  Map<String, dynamic> toMap() {
    String generoString;
    switch (categoria) {
      case ProdutoCategoria.biologico:
        generoString = 'biologico';
        break;
      case ProdutoCategoria.quimico:
        generoString = 'quimico';
        break;
      case ProdutoCategoria.todos:
   //   default:
        generoString = 'todos';
    }

    return {
      if (id != null) 'id': id,
      'nome': nome,
      'tipo': tipo,
      'genero': generoString,
      'demo': demo,
    };
  }

  ProdutoItem copyWith({
    int? id,
    String? nome,
    String? tipo,
    ProdutoCategoria? categoria,
    bool? demo,
  }) {
    return ProdutoItem(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
      categoria: categoria ?? this.categoria,
      demo: demo ?? this.demo,
    );
  }

  @override
  String toString() {
    return 'ProdutoItem(id: \$id, nome: \$nome, tipo: \$tipo, categoria: \$categoria, demo: \$demo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProdutoItem &&
        other.id == id &&
        other.nome == nome &&
        other.tipo == tipo &&
        other.categoria == categoria &&
        other.demo == demo;
  }

  @override
  int get hashCode => Object.hash(id, nome, tipo, categoria, demo);
}
