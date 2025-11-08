class Tipo {
  final int id;
  final String tipo;
  final String designacao;

  Tipo({
    required this.id,
    required this.tipo,
    required this.designacao,
  });

  factory Tipo.fromJson(Map<String, dynamic> json) {
    return Tipo(
      id: json['ID_tipo'],
      tipo: json['Tipo'],
      designacao: json['Designacao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_tipo': id,
      'Tipo': tipo,
      'Designacao': designacao,
    };
  }
}