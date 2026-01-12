class ResultadoItem {
  final int id;
  final String nomeQuimico;
  final String nomeBiologico;
  final String? resultadoFinal;
  final String? descricao;
  final DateTime? criadoEm;

  ResultadoItem({
    required this.id,
    required this.nomeQuimico,
    required this.nomeBiologico,
    this.resultadoFinal,
    this.descricao,
    this.criadoEm,
  });

  factory ResultadoItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final criado = json['criado_em'] ?? json['criadoEm'] ?? json['created_at'];
    if (criado is String) dt = DateTime.tryParse(criado);
    return ResultadoItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      nomeQuimico:
          json['nome_produto_quimico']?.toString() ??
          (json['produto_quimico']?['nome']?.toString() ?? ''),
      nomeBiologico:
          json['nome_produto_biologico']?.toString() ??
          (json['produto_biologico']?['nome']?.toString() ?? ''),
      resultadoFinal: json['resultado_final']?.toString(),
      descricao:
          json['descricao_resultado']?.toString() ?? json['resultado_final']?.toString(),
      criadoEm: dt,
    );
  }
}
