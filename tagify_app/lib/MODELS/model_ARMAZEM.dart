class Armazem {
  final int id;
  final String descricao;
  final String? localizacao;

  Armazem({
    required this.id,
    required this.descricao,
    this.localizacao,
  });

  factory Armazem.fromJson(Map<String, dynamic> json) {
    return Armazem(
      id: json['ID_armazem'],
      descricao: json['Descricao'] ?? '',
      localizacao: json['Localizacao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_armazem': id,
      'Descricao': descricao,
      'Localizacao': localizacao,
    };
  }


}