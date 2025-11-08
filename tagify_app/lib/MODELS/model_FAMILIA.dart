class Familia {
  final int id;
  final String designacao;

  Familia({
    required this.id,
    required this.designacao,
  });

  factory Familia.fromJson(Map<String, dynamic> json) {
    return Familia(
      id: json['ID_familia'],
      designacao: json['Designacao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_familia': id,
      'Designacao': designacao,
    };
  }
}