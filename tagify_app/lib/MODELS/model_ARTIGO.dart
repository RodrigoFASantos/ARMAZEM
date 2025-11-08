import 'model_TIPO.dart';
import 'model_FAMILIA.dart';

class Artigo {
  final int id;
  final int? idTipo;
  final int? idFamilia;
  final String? referencia;
  final String designacao;
  final String? imagem;
  final String? codBar;
  final String? codNfc;
  final String? codRfid;

  // Objetos relacionados (carregados via JOIN na API)
  final Tipo? tipo;
  final Familia? familia;
  final double? stockTotal;
  final List<LocalizacaoStock>? localizacoes;

  Artigo({
    required this.id,
    this.idTipo,
    this.idFamilia,
    this.referencia,
    required this.designacao,
    this.imagem,
    this.codBar,
    this.codNfc,
    this.codRfid,
    this.tipo,
    this.familia,
    this.stockTotal,
    this.localizacoes,
  });

  factory Artigo.fromJson(Map<String, dynamic> json) {
    return Artigo(
      id: json['ID_artigo'],
      idTipo: json['ID_tipo'],
      idFamilia: json['ID_familia'],
      referencia: json['Referencia'],
      designacao: json['Designacao'],
      imagem: json['Imagem'],
      codBar: json['Cod_bar'],
      codNfc: json['Cod_NFC'],
      codRfid: json['Cod_RFID'],
      tipo: json['tipo'] != null ? Tipo.fromJson(json['tipo']) : null,
      familia: json['familia'] != null ? Familia.fromJson(json['familia']) : null,
      stockTotal: json['stock_total'] != null 
          ? (json['stock_total'] as num).toDouble() 
          : null,
      localizacoes: json['localizacoes'] != null
          ? (json['localizacoes'] as List)
              .map((loc) => LocalizacaoStock.fromJson(loc))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_artigo': id,
      'ID_tipo': idTipo,
      'ID_familia': idFamilia,
      'Referencia': referencia,
      'Designacao': designacao,
      'Imagem': imagem,
      'Cod_bar': codBar,
      'Cod_NFC': codNfc,
      'Cod_RFID': codRfid,
    };
  }
}

// Classe auxiliar para stock por localização
class LocalizacaoStock {
  final int idArmazem;
  final String armazem;
  final String? localizacao;
  final double stock;

  LocalizacaoStock({
    required this.idArmazem,
    required this.armazem,
    this.localizacao,
    required this.stock,
  });

  factory LocalizacaoStock.fromJson(Map<String, dynamic> json) {
    return LocalizacaoStock(
      idArmazem: json['ID_armazem'],
      armazem: json['armazem'],
      localizacao: json['localizacao'],
      stock: (json['stock'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_armazem': idArmazem,
      'armazem': armazem,
      'localizacao': localizacao,
      'stock': stock,
    };
  }
}