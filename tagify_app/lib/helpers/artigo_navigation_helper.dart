import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';
import '../screens/equipamento_detail_screen.dart';
import '../screens/materia_prima_detail_screen.dart';
import '../screens/produto_detail_screen.dart';

/// Helper para navegação inteligente baseada no tipo de artigo
class ArtigoNavigationHelper {
  
  /// Navega para o ecrã de detalhe apropriado com base no tipo do artigo
  static Future<void> navigateToArtigoDetail(
    BuildContext context,
    Artigo artigo,
  ) async {
    final db = DatabaseHelper.instance;
    
    // Determinar tipo do artigo
    final tipoId = artigo.idTipo;
    final tipoDesignacao = artigo.tipo?.designacao?.toLowerCase() ?? '';
    
    // Verificar se é equipamento (tem registro na tabela EQUIPAMENTO)
    final equipamentoData = await db.getEquipamentoComEstado(artigo.id);
    
    if (equipamentoData != null) {
      // É um equipamento
      final equipamento = Equipamento.fromJson(equipamentoData);
      
      if (context.mounted) {
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
      return;
    }
    
    // Verificar tipo por designação ou ID
    if (_isMateriaPrima(tipoId, tipoDesignacao)) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MateriaPrimaDetailScreen(artigo: artigo),
          ),
        );
      }
    } else if (_isProduto(tipoId, tipoDesignacao)) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProdutoDetailScreen(artigo: artigo),
          ),
        );
      }
    } else {
      // Default: mostrar como matéria-prima
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MateriaPrimaDetailScreen(artigo: artigo),
          ),
        );
      }
    }
  }
  
  /// Verifica se é matéria-prima
  static bool _isMateriaPrima(int? tipoId, String tipoDesignacao) {
    // Verificar por designação
    if (tipoDesignacao.contains('materia') ||
        tipoDesignacao.contains('matéria') ||
        tipoDesignacao.contains('prima') ||
        tipoDesignacao.contains('raw') ||
        tipoDesignacao.contains('material')) {
      return true;
    }
    
    // Verificar por ID (ajustar conforme a tua base de dados)
    // Exemplo: tipo 1 = matéria-prima
    if (tipoId == 1) return true;
    
    return false;
  }
  
  /// Verifica se é produto acabado
  static bool _isProduto(int? tipoId, String tipoDesignacao) {
    // Verificar por designação
    if (tipoDesignacao.contains('produto') ||
        tipoDesignacao.contains('acabado') ||
        tipoDesignacao.contains('final') ||
        tipoDesignacao.contains('product') ||
        tipoDesignacao.contains('finished')) {
      return true;
    }
    
    // Verificar por ID (ajustar conforme a tua base de dados)
    // Exemplo: tipo 2 = produto acabado
    if (tipoId == 2) return true;
    
    return false;
  }
  
  /// Retorna o ícone apropriado para o tipo de artigo
  static IconData getArtigoIcon(Artigo artigo) {
    final tipoDesignacao = artigo.tipo?.designacao?.toLowerCase() ?? '';
    
    if (tipoDesignacao.contains('equipamento') ||
        tipoDesignacao.contains('equipment')) {
      return Icons.build;
    } else if (_isMateriaPrima(artigo.idTipo, tipoDesignacao)) {
      return Icons.inventory_2;
    } else if (_isProduto(artigo.idTipo, tipoDesignacao)) {
      return Icons.shopping_bag;
    }
    
    return Icons.category;
  }
  
  /// Retorna a cor apropriada para o tipo de artigo
  static Color getArtigoColor(Artigo artigo) {
    final tipoDesignacao = artigo.tipo?.designacao?.toLowerCase() ?? '';
    
    if (tipoDesignacao.contains('equipamento') ||
        tipoDesignacao.contains('equipment')) {
      return Colors.orange;
    } else if (_isMateriaPrima(artigo.idTipo, tipoDesignacao)) {
      return Colors.blue;
    } else if (_isProduto(artigo.idTipo, tipoDesignacao)) {
      return Colors.green;
    }
    
    return Colors.grey;
  }
}