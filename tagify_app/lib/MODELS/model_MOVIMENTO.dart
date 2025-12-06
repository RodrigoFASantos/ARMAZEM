class Movimento {
  final int id;
  final int idArtigo;
  final int idArmazem;
  final DateTime dataMov;
  final double qtdEntrada;
  final double qtdSaida;
  final int? rack;
  final int? NPrateleira;
  final String? DPrateleira;
  final int? NCorredor;
  final String? DCorredor;
  final int? zona;

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
    this.rack,
    this.NPrateleira,
    this.DPrateleira,
    this.NCorredor,
    this.DCorredor,
    this.zona,
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
      rack: json['Rack'],
      NPrateleira: json['NPrateleira'],
      DPrateleira: json['DPrateleira'],
      NCorredor: json['NCorredor'],
      DCorredor: json['DCorredor'],
      zona: json['Zona'],
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
      'Rack': rack,
      'NPrateleira': NPrateleira,
      'DPrateleira': DPrateleira,
      'NCorredor': NCorredor,
      'DCorredor': DCorredor,
      'Zona': zona,
    };
  }

  // Calcula o saldo do movimento
  double get saldo => qtdEntrada - qtdSaida;

  // ==========================================
  // HELPERS DE DISPLAY
  // ==========================================

  /// Retorna localização completa formatada
  String get localizacaoCompleta {
    List<String> partes = [];

    if (rack != null) partes.add('Rack $rack');
    if (prateleiraDisplay != 'N/A') partes.add('Prat. $prateleiraDisplay');
    if (corredorDisplay != 'N/A') partes.add('Corr. $corredorDisplay');
    if (zona != null) partes.add('Zona $zona');

    return partes.isNotEmpty ? partes.join(' | ') : 'N/A';
  }

  /// Retorna rack formatado
  String get rackDisplay {
    if (rack != null) return rack.toString();
    return 'N/A';
  }

  /// Retorna prateleira (prefere descrição, fallback para número)
  String get prateleiraDisplay {
    if (DPrateleira != null && DPrateleira!.isNotEmpty) return DPrateleira!;
    if (NPrateleira != null) return NPrateleira.toString();
    return 'N/A';
  }

  /// Retorna corredor (prefere descrição, fallback para número)
  String get corredorDisplay {
    if (DCorredor != null && DCorredor!.isNotEmpty) return DCorredor!;
    if (NCorredor != null) return NCorredor.toString();
    return 'N/A';
  }

  /// Retorna zona formatada
  String get zonaDisplay {
    if (zona != null) return zona.toString();
    return 'N/A';
  }
}
