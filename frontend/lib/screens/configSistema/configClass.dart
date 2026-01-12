// FILE: lib/models/config_sistema.dart

class ConfigSistema {
  final int id;
  final DateTime dataEstabelecimento;
  final String precoDoCredito;
  final int precoDaSolicitacaoEmCreditos;
  final String? descricao;
  final DateTime atualizadoEm;
  final int validadeEmDias;

  ConfigSistema({
    required this.id,
    required this.dataEstabelecimento,
    required this.precoDoCredito,
    required this.precoDaSolicitacaoEmCreditos,
    this.descricao,
    required this.atualizadoEm,
    required this.validadeEmDias,
  });

  factory ConfigSistema.fromJson(Map<String, dynamic> json) {
    return ConfigSistema(
      id: json['id'],
      dataEstabelecimento: DateTime.parse(json['data_estabelecimento']),
      precoDoCredito: json['preco_do_credito'].toString(),
      precoDaSolicitacaoEmCreditos: json['preco_da_solicitacao_em_creditos'],
      descricao: json['descricao'],
      atualizadoEm: DateTime.parse(json['atualizado_em']),
      validadeEmDias: json['validade_em_dias'] ?? 0,
    );
  }
}
