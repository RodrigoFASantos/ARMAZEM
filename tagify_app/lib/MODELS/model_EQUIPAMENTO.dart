class Equipamento {
  final int id;
  final int idArtigo;
  final int? idEstado;
  final String? nSerie;
  final String? marca;
  final String? modelo;
  final DateTime? dataAquisicao;
  final bool requerInspecao;
  final int? cicloInspecaoDias;

  // Objetos relacionados
  final String? artigoDesignacao;
  final String? estadoDesignacao;

  Equipamento({
    required this.id,
    required this.idArtigo,
    this.idEstado,
    this.nSerie,
    this.marca,
    this.modelo,
    this.dataAquisicao,
    required this.requerInspecao,
    this.cicloInspecaoDias,
    this.artigoDesignacao,
    this.estadoDesignacao,
  });

  factory Equipamento.fromJson(Map<String, dynamic> json) {
    return Equipamento(
      id: json['ID_equipamento'],
      idArtigo: json['ID_artigo'],
      idEstado: json['ID_Estado'],
      nSerie: json['N_serie'],
      marca: json['Marca'],
      modelo: json['Modelo'],
      dataAquisicao: json['Data_aquisicao'] != null
          ? DateTime.parse(json['Data_aquisicao'])
          : null,
      requerInspecao:
          json['Requer_inspecao'] == 1 || json['Requer_inspecao'] == true,
      cicloInspecaoDias: json['Ciclo_inpecao_dias'],
      artigoDesignacao: json['artigo_designacao'],
      estadoDesignacao: json['estado_designacao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_equipamento': id,
      'ID_artigo': idArtigo,
      'ID_Estado': idEstado,
      'N_serie': nSerie,
      'Marca': marca,
      'Modelo': modelo,
      'Data_aquisicao': dataAquisicao?.toIso8601String(),
      'Requer_inspecao': requerInspecao ? 1 : 0,
      'Ciclo_inpecao_dias': cicloInspecaoDias,
    };
  }

  // Calcula a próxima data de inspeção
  DateTime? get proximaInspecao {
    if (!requerInspecao || dataAquisicao == null || cicloInspecaoDias == null) {
      return null;
    }
    return dataAquisicao!.add(Duration(days: cicloInspecaoDias!));
  }

  // Verifica se está atrasado na inspeção
  bool get inspecaoAtrasada {
    final proxima = proximaInspecao;
    if (proxima == null) return false;
    return DateTime.now().isAfter(proxima);
  }
}
