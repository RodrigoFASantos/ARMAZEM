import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';
import '../screens/equipamento_detail_screen.dart';
import '../screens/materia_prima_detail_screen.dart';
import '../screens/produto_detail_screen.dart';

/// =============================================================================
/// HELPER PARA NAVEGAÇÃO INTELIGENTE BASEADA NO TIPO DE ITEM
/// =============================================================================
/// A navegação é feita com base na seguinte lógica:
///
/// PRIORIDADE 1: Verificar se é EQUIPAMENTO (tem registo na tabela EQUIPAMENTO)
///   → Sim: EquipamentoDetailScreen
///
/// PRIORIDADE 2: Se é ARTIGO (não tem registo na tabela EQUIPAMENTO):
///   → ID_Tipo = 1: MateriaPrimaDetailScreen
///   → ID_Tipo = 2: ProdutoDetailScreen
/// =============================================================================
class ArtigoNavigationHelper {
  
  /// Navega para o ecrã de detalhe apropriado
  static Future<void> navigateToArtigoDetail(
    BuildContext context,
    Artigo artigo,
  ) async {
    final db = DatabaseHelper.instance;
    
    // =========================================================================
    // PRIORIDADE 1: Verificar se é EQUIPAMENTO
    // =========================================================================
    final equipamentoData = await db.getEquipamentoComEstado(artigo.id);
    
    if (equipamentoData != null) {
      // É um EQUIPAMENTO - vai para EquipamentoDetailScreen
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
    
    // =========================================================================
    // PRIORIDADE 2: É um ARTIGO - verificar ID_Tipo
    // =========================================================================
    final idTipo = artigo.idTipo;
    
    if (idTipo == 1) {
      // Matéria-Prima
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MateriaPrimaDetailScreen(artigo: artigo),
          ),
        );
      }
      return;
    }
    
    if (idTipo == 2) {
      // Produto Final
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProdutoDetailScreen(artigo: artigo),
          ),
        );
      }
      return;
    }
    
    // =========================================================================
    // FALLBACK: Se não tem ID_Tipo definido, usa designação
    // =========================================================================
    final tipoDesignacao = artigo.tipo?.designacao?.toLowerCase() ?? '';
    
    if (_isProduto(tipoDesignacao)) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProdutoDetailScreen(artigo: artigo),
          ),
        );
      }
    } else {
      // Default: Matéria-Prima
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
  
  /// Verifica se é produto pela designação (fallback)
  static bool _isProduto(String tipoDesignacao) {
    return tipoDesignacao.contains('produto') ||
           tipoDesignacao.contains('acabado') ||
           tipoDesignacao.contains('final') ||
           tipoDesignacao.contains('product') ||
           tipoDesignacao.contains('finished');
  }
  
  /// Retorna o ícone apropriado para o tipo de item
  /// NOTA: Esta função precisa de saber se é equipamento ou artigo
  static Future<IconData> getArtigoIconAsync(Artigo artigo) async {
    final db = DatabaseHelper.instance;
    final equipamentoData = await db.getEquipamentoComEstado(artigo.id);
    
    if (equipamentoData != null) {
      return Icons.build; // Equipamento
    }
    
    final idTipo = artigo.idTipo;
    if (idTipo == 1) {
      return Icons.inventory_2; // Matéria-Prima
    } else if (idTipo == 2) {
      return Icons.shopping_bag; // Produto Final
    }
    
    return Icons.category; // Default
  }
  
  /// Retorna o ícone baseado apenas no ID_Tipo (para uso síncrono)
  static IconData getArtigoIcon(Artigo artigo) {
    final idTipo = artigo.idTipo;
    
    if (idTipo == 1) {
      return Icons.inventory_2; // Matéria-Prima
    } else if (idTipo == 2) {
      return Icons.shopping_bag; // Produto Final
    }
    
    return Icons.category; // Default
  }
  
  /// Retorna a cor apropriada para o tipo de artigo
  static Color getArtigoColor(Artigo artigo) {
    final idTipo = artigo.idTipo;
    
    if (idTipo == 1) {
      return Colors.blue; // Matéria-Prima
    } else if (idTipo == 2) {
      return Colors.purple; // Produto Final
    }
    
    return Colors.grey; // Default
  }
  
  /// Retorna o nome do tipo de artigo
  static String getArtigoTipoNome(Artigo artigo) {
    final idTipo = artigo.idTipo;
    
    if (idTipo == 1) {
      return 'Matéria-Prima';
    } else if (idTipo == 2) {
      return 'Produto Final';
    }
    
    // Usar designação do tipo se existir
    if (artigo.tipo?.designacao != null) {
      return artigo.tipo!.designacao;
    }
    
    return 'Artigo';
  }
  
  /// Retorna a cor do estado do equipamento
  static Color getEstadoColor(int? idEstado) {
    switch (idEstado) {
      case 1: // Operacional
        return Colors.green;
      case 2: // Em Manutenção
        return Colors.orange;
      case 3: // Não Operacional
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  /// Retorna o nome do estado do equipamento
  static String getEstadoNome(int? idEstado) {
    switch (idEstado) {
      case 1:
        return 'Operacional';
      case 2:
        return 'Em Manutenção';
      case 3:
        return 'Não Operacional';
      default:
        return 'Desconhecido';
    }
  }
}