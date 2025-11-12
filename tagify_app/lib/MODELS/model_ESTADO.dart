class Estado {
  final int id;
  final String designacao;

  Estado({
    required this.id,
    required this.designacao,
  });

  factory Estado.fromJson(Map<String, dynamic> json) {
    return Estado(
      id: json['ID_Estado'],
      designacao: json['Designacao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_Estado': id,
      'Designacao': designacao,
    };
  }
}