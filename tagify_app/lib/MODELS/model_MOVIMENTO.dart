class Movimento {
  final int id;
  final int idArtigo;
  final int idArmazem;
  final DateTime dataMov;
  final double qtdEntrada;
  final double qtdSaida;

  // Objetos relacionados (opcional)
  final String? artigoDesignacao;
  final String? armazemDescricao;

  Movimento({
    required this.id,
    required this.idArtigo,
    required this.idArmazem,
    required this.dataMov,
    required this.qtdEntrada,
    required this.qtdSaida,
    this.artigoDesignacao,
    this.armazemDescricao,
  });

  factory Movimento.fromJson(Map<String, dynamic> json) {
    return Movimento(
      id: json['ID_movimento'],
      idArtigo: json['ID_artigo'],
      idArmazem: json['ID_armazem'],
      dataMov: DateTime.parse(json['Data_mov']),
      qtdEntrada: (json['Qtd_entrada'] ?? 0).toDouble(),
      qtdSaida: (json['Qtd_saida'] ?? 0).toDouble(),
      artigoDesignacao: json['artigo_designacao'],
      armazemDescricao: json['armazem_descricao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_movimento': id,
      'ID_artigo': idArtigo,
      'ID_armazem': idArmazem,
      'Data_mov': dataMov.toIso8601String(),
      'Qtd_entrada': qtdEntrada,
      'Qtd_saida': qtdSaida,
    };
  }

  // Calcula o saldo do movimento
  double get saldo => qtdEntrada - qtdSaida;
}