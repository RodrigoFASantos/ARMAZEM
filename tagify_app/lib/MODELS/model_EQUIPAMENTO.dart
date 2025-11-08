class Equipamento {
  final int id;
  final int idArtigo;
  final String? nSerie;
  final String? marca;
  final String? modelo;
  final DateTime? dataAquisicao;
  final bool requerInspecao;
  final int? cicloInspecaoDias;
  final String? estado;

  // Objeto relacionado (opcional)
  final String? artigoDesignacao;

  Equipamento({
    required this.id,
    required this.idArtigo,
    this.nSerie,
    this.marca,
    this.modelo,
    this.dataAquisicao,
    required this.requerInspecao,
    this.cicloInspecaoDias,
    this.estado,
    this.artigoDesignacao,
  });

  factory Equipamento.fromJson(Map<String, dynamic> json) {
    return Equipamento(
      id: json['ID_equipamento'],
      idArtigo: json['ID_artigo'],
      nSerie: json['N_serie'],
      marca: json['Marca'],
      modelo: json['Modelo'],
      dataAquisicao: json['Data_aquisicao'] != null
          ? DateTime.parse(json['Data_aquisicao'])
          : null,
      requerInspecao: json['Requer_inspecao'] == 1 || json['Requer_inspecao'] == true,
      cicloInspecaoDias: json['Ciclo_inpecao_dias'],
      estado: json['Estado'],
      artigoDesignacao: json['artigo_designacao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_equipamento': id,
      'ID_artigo': idArtigo,
      'N_serie': nSerie,
      'Marca': marca,
      'Modelo': modelo,
      'Data_aquisicao': dataAquisicao?.toIso8601String(),
      'Requer_inspecao': requerInspecao ? 1 : 0,
      'Ciclo_inpecao_dias': cicloInspecaoDias,
      'Estado': estado,
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