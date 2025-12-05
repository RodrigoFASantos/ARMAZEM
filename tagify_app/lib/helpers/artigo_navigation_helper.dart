import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';
import '../screens/equipamento_detail_screen.dart';
import '../screens/materia_prima_detail_screen.dart';
import '../screens/produto_detail_screen.dart';

/// Helper para navegação inteligente entre as telas de detalhes de artigos
/// Determina automaticamente qual tela usar baseado no tipo de artigo
class ArtigoNavigationHelper {
  
  /// Navega para a tela de detalhes apropriada baseando-se no tipo de artigo
  static Future<void> navigateToArtigoDetail(
    BuildContext context,
    Artigo artigo,
  ) async {
    // Verificar se tem equipamento associado
    final equipamento = await _buscarEquipamento(artigo.id);
    
    if (equipamento != null) {
      // É EQUIPAMENTO
      _navigateToEquipamento(context, artigo, equipamento);
    } else {
      // Determinar se é Matéria-Prima ou Produto baseado no tipo
      final tipoDesignacao = artigo.tipo?.designacao?.toLowerCase() ?? '';
      
      if (tipoDesignacao.contains('matéria') || 
          tipoDesignacao.contains('materia') ||
          tipoDesignacao.contains('prima') ||
          artigo.idTipo == 1) {
        // É MATÉRIA-PRIMA
        _navigateToMateriaPrima(context, artigo);
      } else {
        // É PRODUTO (caso padrão)
        final dataProduzido = await _buscarDataProducao(artigo.id);
        _navigateToProduto(context, artigo, dataProduzido);
      }
    }
  }
  
  /// Navega para tela de equipamento
  static void _navigateToEquipamento(
    BuildContext context,
    Artigo artigo,
    Equipamento equipamento,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EquipamentoDetailScreen(
          artigo: artigo,
          equipamento: equipamento,
        ),
      ),
    );
  }
  
  /// Navega para tela de matéria-prima
  static void _navigateToMateriaPrima(
    BuildContext context,
    Artigo artigo,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MateriaPrimaDetailScreen(
          artigo: artigo,
        ),
      ),
    );
  }
  
  /// Navega para tela de produto
  static void _navigateToProduto(
    BuildContext context,
    Artigo artigo,
    DateTime? dataProduzido,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProdutoDetailScreen(
          artigo: artigo,
          dataProduzido: dataProduzido,
        ),
      ),
    );
  }
  
  /// Busca equipamento associado ao artigo
  static Future<Equipamento?> _buscarEquipamento(int idArtigo) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'EQUIPAMENTO',
        where: 'ID_artigo = ?',
        whereArgs: [idArtigo],
      );
      
      if (result.isEmpty) return null;
      return Equipamento.fromJson(result.first);
    } catch (e) {
      print('Erro ao buscar equipamento: $e');
      return null;
    }
  }
  
  /// Busca data de produção do artigo (pode ser do primeiro movimento de entrada)
  static Future<DateTime?> _buscarDataProducao(int idArtigo) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'MOVIMENTOS',
        where: 'ID_artigo = ? AND Qtd_entrada > 0',
        whereArgs: [idArtigo],
        orderBy: 'Data_mov ASC',
        limit: 1,
      );
      
      if (result.isEmpty) return null;
      
      final dataStr = result.first['Data_mov'] as String;
      return DateTime.parse(dataStr);
    } catch (e) {
      print('Erro ao buscar data de produção: $e');
      return null;
    }
  }
}

// =============================================================================
// EXEMPLOS DE USO
// =============================================================================

/* 
// EXEMPLO 1: Uso em lista de artigos
class ArtigoListItem extends StatelessWidget {
  final Artigo artigo;
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(artigo.designacao),
      onTap: () {
        // Navega automaticamente para a tela correta
        ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
      },
    );
  }
}

// EXEMPLO 2: Uso após escanear código
Future<void> _handleScanResult(String codigo) async {
  final db = await DatabaseHelper.instance.database;
  
  // Buscar artigo pelo código
  final result = await db.query(
    'ARTIGO',
    where: 'Cod_bar = ? OR Cod_NFC = ? OR Cod_RFID = ?',
    whereArgs: [codigo, codigo, codigo],
  );
  
  if (result.isEmpty) {
    // Artigo não encontrado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Artigo não encontrado')),
    );
    return;
  }
  
  // Converter para objeto Artigo
  final artigo = Artigo.fromJson(result.first);
  
  // Navegar para detalhes (escolhe automaticamente a tela correta)
  ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
}

// EXEMPLO 3: Uso em grid de artigos
class ArtigoGridItem extends StatelessWidget {
  final Artigo artigo;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo),
      child: Card(
        child: Column(
          children: [
            // Imagem
            if (artigo.imagem != null)
              Image.network(artigo.imagem!, height: 100),
            // Nome
            Text(artigo.designacao),
          ],
        ),
      ),
    );
  }
}

// EXEMPLO 4: Navegação manual para tipo específico (caso precise)
void _navigateManually(BuildContext context, Artigo artigo) {
  // Forçar navegação para equipamento
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EquipamentoDetailScreen(
        artigo: artigo,
        equipamento: null, // Pode ser null
      ),
    ),
  );
  
  // Forçar navegação para matéria-prima
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MateriaPrimaDetailScreen(
        artigo: artigo,
      ),
    ),
  );
  
  // Forçar navegação para produto
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProdutoDetailScreen(
        artigo: artigo,
        dataProduzido: DateTime.now(),
      ),
    ),
  );
}
*/