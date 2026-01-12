class Plano {
  final int id;
  final String nome;
  final int prioridadeDeTempo;
  final int quantidadeCreditoMensal;
  final String precoMensal;
  final DateTime? createdAt;
  final int maximoColaboradores; // 0 -> ilimitado

  Plano({
    required this.id,
    required this.nome,
    required this.prioridadeDeTempo,
    required this.quantidadeCreditoMensal,
    required this.precoMensal,
    this.createdAt,
    this.maximoColaboradores = 0,
  });

  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  factory Plano.fromJson(Map<String, dynamic> j) {
    final id = _parseInt(j['id']);
    final nome = (j['nome'] ?? j['name'] ?? '').toString();
    final prioridade = _parseInt(j['prioridade_de_tempo'] ?? j['prioridadeDeTempo'] ?? j['prioridade'] ?? 0);
    final quantidade = _parseInt(j['quantidade_credito_mensal'] ?? j['quantidadeCreditoMensal'] ?? j['quantidade'] ?? 0);
    final preco = (j['preco_mensal'] ?? j['precoMensal'] ?? j['preco'] ?? '0.00').toString();
    final createdRaw = j['created_at'] ?? j['createdAt'] ?? j['created'];
    DateTime? createdAt;
    if (createdRaw != null) {
      try {
        createdAt = DateTime.tryParse(createdRaw.toString());
      } catch (_) {
        createdAt = null;
      }
    }

    final maxCol = _parseInt(j['maximo_colaboradores'] ?? j['maximoColaboradores'] ?? j['max_colaboradores'] ?? 0);

    return Plano(
      id: id,
      nome: nome,
      prioridadeDeTempo: prioridade,
      quantidadeCreditoMensal: quantidade,
      precoMensal: preco,
      createdAt: createdAt,
      maximoColaboradores: maxCol,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'prioridade_de_tempo': prioridadeDeTempo,
      'quantidade_credito_mensal': quantidadeCreditoMensal,
      'preco_mensal': precoMensal,
      'created_at': createdAt?.toIso8601String(),
      'maximo_colaboradores': maximoColaboradores,
    };
  }
}
