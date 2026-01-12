// FILE: lib/models/empresa.dart

class Empresa {
  final int id;
  final String nome;
  final String cnpj;
  final String corTema;
  final String? logo;

  Empresa({
    required this.id,
    required this.nome,
    required this.cnpj,
    required this.corTema,
    this.logo,
  });

  factory Empresa.fromJson(Map<String, dynamic> j) {
    return Empresa(
      id: j['id'],
      nome: j['nome'],
      cnpj: j['cnpj'],
      corTema: j['corTema'],
      logo: j['logo'],
    );
  }
}
