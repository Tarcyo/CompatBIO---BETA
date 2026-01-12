// lib/models/solicitacao.dart

/// Modelos (mantidos)
class Solicitacao {
  final int id;
  final String nomeProdutoBiologico;
  final String nomeProdutoQuimico;
  final int prioridade;
  final String? status;
  final String? resultadoFinal;
  final DateTime? dataSolicitacao;
  final Usuario? usuario;
  final Map<String, dynamic> rawData;
  final Map<String, dynamic>? usuarioRaw;

  Solicitacao({
    required this.id,
    required this.nomeProdutoBiologico,
    required this.nomeProdutoQuimico,
    required this.prioridade,
    this.status,
    this.resultadoFinal,
    this.dataSolicitacao,
    this.usuario,
    required this.rawData,
    this.usuarioRaw,
  });

  Solicitacao copyWith({
    int? id,
    String? nomeProdutoBiologico,
    String? nomeProdutoQuimico,
    int? prioridade,
    String? status,
    String? resultadoFinal,
    DateTime? dataSolicitacao,
    Usuario? usuario,
    Map<String, dynamic>? rawData,
    Map<String, dynamic>? usuarioRaw,
  }) {
    return Solicitacao(
      id: id ?? this.id,
      nomeProdutoBiologico: nomeProdutoBiologico ?? this.nomeProdutoBiologico,
      nomeProdutoQuimico: nomeProdutoQuimico ?? this.nomeProdutoQuimico,
      prioridade: prioridade ?? this.prioridade,
      status: status ?? this.status,
      resultadoFinal: resultadoFinal ?? this.resultadoFinal,
      dataSolicitacao: dataSolicitacao ?? this.dataSolicitacao,
      usuario: usuario ?? this.usuario,
      rawData: rawData ?? Map<String, dynamic>.from(this.rawData),
      usuarioRaw: usuarioRaw ?? this.usuarioRaw,
    );
  }

  factory Solicitacao.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['data_solicitacao'];
    if (rawDate is String)
      parsedDate = DateTime.tryParse(rawDate);
    else if (rawDate is int) parsedDate =
        DateTime.fromMillisecondsSinceEpoch(rawDate);

    Usuario? usuario;
    Map<String, dynamic>? usuarioRaw;
    if (json['usuario'] is Map<String, dynamic>) {
      usuarioRaw = Map<String, dynamic>.from(json['usuario']);
      usuario = Usuario.fromJson(usuarioRaw);
    } else if (json['usuario'] != null) {
      usuarioRaw = {'raw': json['usuario']};
    }

    return Solicitacao(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      nomeProdutoBiologico:
          json['nome_produto_biologico'] ?? (json['produto_biologico']?['nome'] ?? ''),
      nomeProdutoQuimico:
          json['nome_produto_quimico'] ?? (json['produto_quimico']?['nome'] ?? ''),
      prioridade: json['prioridade'] is int
          ? json['prioridade']
          : int.tryParse('${json['prioridade']}') ?? 0,
      status: json['status']?.toString(),
      resultadoFinal:
          json['resultado_final']?.toString() ?? json['descricao_resultado']?.toString(),
      dataSolicitacao: parsedDate,
      usuario: usuario,
      rawData: Map<String, dynamic>.from(json),
      usuarioRaw: usuarioRaw,
    );
  }
}

class Usuario {
  final int? id;
  final String? nome;
  final String? email;
  final String? empresa;

  Usuario({this.id, this.nome, this.email, this.empresa});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      nome: json['nome']?.toString(),
      email: json['email']?.toString(),
      empresa: json['empresa']?.toString(),
    );
  }
}
