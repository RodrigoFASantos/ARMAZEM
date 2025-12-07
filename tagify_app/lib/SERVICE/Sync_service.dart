import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class SyncService {
  static const String baseUrl = 'http://172.20.10.2:8000';

  /// Sincroniza todos os dados do servidor para o SQLite local
  Future<SyncResult> syncAllData({
    Function(String)? onProgress,
  }) async {
    final startTime = DateTime.now();
    int totalRecords = 0;

    try {
      onProgress?.call('Iniciando sincronização...');
      print(' Iniciando sincronização completa...');

      // 1. Limpar dados antigos
      onProgress?.call('Limpando dados antigos...');
      print('  Limpando dados antigos...');
      await DatabaseHelper.instance.clearAllData();

      // 2. Buscar e inserir Tipos
      onProgress?.call('Sincronizando Tipos...');
      print(' Sincronizando Tipos...');
      final tipos = await _fetchTipos();
      print('   Recebidos ${tipos.length} tipos');
      if (tipos.isNotEmpty) {
        await DatabaseHelper.instance.insertTipos(tipos);
        totalRecords += tipos.length;
      }

      // 3. Buscar e inserir Famílias
      onProgress?.call('Sincronizando Famílias...');
      print(' Sincronizando Famílias...');
      final familias = await _fetchFamilias();
      print('   Recebidas ${familias.length} famílias');
      if (familias.isNotEmpty) {
        await DatabaseHelper.instance.insertFamilias(familias);
        totalRecords += familias.length;
      }

      // 4. Buscar e inserir Estados
      onProgress?.call('Sincronizando Estados...');
      print(' Sincronizando Estados...');
      final estados = await _fetchEstados();
      print('   Recebidos ${estados.length} estados');
      if (estados.isNotEmpty) {
        await DatabaseHelper.instance.insertEstados(estados);
        totalRecords += estados.length;
      }

      // 5. Buscar e inserir Armazéns
      onProgress?.call('Sincronizando Armazéns...');
      print(' Sincronizando Armazéns...');
      final armazens = await _fetchArmazens();
      print('   Recebidos ${armazens.length} armazéns');
      if (armazens.isNotEmpty) {
        await DatabaseHelper.instance.insertArmazens(armazens);
        totalRecords += armazens.length;
      }

      // 6. Buscar e inserir Artigos
      onProgress?.call('Sincronizando Artigos...');
      print(' Sincronizando Artigos...');
      final artigos = await _fetchArtigos();
      print('   Recebidos ${artigos.length} artigos');
      if (artigos.isNotEmpty) {
        await DatabaseHelper.instance.insertArtigos(artigos);
        totalRecords += artigos.length;
      }

      // 7. Buscar e inserir Equipamentos
      onProgress?.call('Sincronizando Equipamentos...');
      print(' Sincronizando Equipamentos...');
      final equipamentos = await _fetchEquipamentos();
      print('   Recebidos ${equipamentos.length} equipamentos');
      if (equipamentos.isNotEmpty) {
        await DatabaseHelper.instance.insertEquipamentos(equipamentos);
        totalRecords += equipamentos.length;
      }

      // 8. Buscar e inserir Movimentos
      onProgress?.call('Sincronizando Movimentos...');
      print(' Sincronizando Movimentos...');
      final movimentos = await _fetchMovimentos();
      print('   Recebidos ${movimentos.length} movimentos');
      if (movimentos.isNotEmpty) {
        await DatabaseHelper.instance.insertMovimentos(movimentos);
        totalRecords += movimentos.length;
      }

      // 9. Buscar e inserir Utilizadores
      onProgress?.call('Sincronizando Utilizadores...');
      print(' Sincronizando Utilizadores...');
      final utilizadores = await _fetchUtilizadores();
      print('   Recebidos ${utilizadores.length} utilizadores');
      if (utilizadores.isNotEmpty) {
        await DatabaseHelper.instance.insertUtilizadores(utilizadores);
        totalRecords += utilizadores.length;
      }

      // 10. Registar log de sincronização
      await DatabaseHelper.instance.logSync(totalRecords, true);

      final duration = DateTime.now().difference(startTime);
      onProgress?.call('Sincronização concluída!');
      print(' Sincronização concluída! Total: $totalRecords registos em ${duration.inSeconds}s');

      // Verificar estatísticas finais
      final stats = await DatabaseHelper.instance.getStats();
      print(' Estatísticas finais:');
      stats.forEach((key, value) {
        print('   $key: $value');
      });

      return SyncResult(
        success: true,
        totalRecords: totalRecords,
        duration: duration,
        message: 'Sincronização concluída com sucesso!',
      );
    } catch (e, stackTrace) {
      print(' Erro na sincronização: $e');
      print('Stack trace: $stackTrace');
      
      // Registar erro
      await DatabaseHelper.instance.logSync(totalRecords, false);

      return SyncResult(
        success: false,
        totalRecords: totalRecords,
        duration: DateTime.now().difference(startTime),
        message: 'Erro: ${e.toString()}',
      );
    }
  }

  // ==========================================
  // MÉTODOS PRIVADOS PARA BUSCAR DADOS
  // ==========================================

  Future<List<Map<String, dynamic>>> _fetchTipos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/tipos'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        print('   Raw data sample: ${data.take(1)}');
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar tipos: $e');
      throw Exception('Erro ao buscar tipos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFamilias() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/familias'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar famílias: $e');
      throw Exception('Erro ao buscar famílias: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEstados() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/estados'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar estados: $e');
      throw Exception('Erro ao buscar estados: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchArmazens() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/armazens'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar armazéns: $e');
      throw Exception('Erro ao buscar armazéns: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchArtigos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/artigos'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar artigos: $e');
      throw Exception('Erro ao buscar artigos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEquipamentos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/equipamentos'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar equipamentos: $e');
      throw Exception('Erro ao buscar equipamentos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMovimentos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/movimentos'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar movimentos: $e');
      throw Exception('Erro ao buscar movimentos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUtilizadores() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/utilizadores'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data.map((e) => _convertToSQLiteMap(e)).toList();
      }
      throw Exception('Status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('     Erro ao buscar utilizadores: $e');
      throw Exception('Erro ao buscar utilizadores: $e');
    }
  }

  /// Converte dados do servidor para formato SQLite
  /// Remove objetos aninhados e converte booleanos para int
  Map<String, dynamic> _convertToSQLiteMap(dynamic data) {
    if (data is! Map) {
      print('  Dado não é Map: $data');
      return {};
    }

    final result = <String, dynamic>{};
    
    (data as Map<String, dynamic>).forEach((key, value) {
      // Ignora campos aninhados (Maps e Lists)
      if (value is Map || value is List) {
        // Não adiciona ao resultado
        return;
      }
      
      // Converte boolean para int (SQLite não suporta boolean)
      if (value is bool) {
        result[key] = value ? 1 : 0;
      } 
      // Mantém null
      else if (value == null) {
        result[key] = null;
      }
      // Converte números para o tipo correto
      else if (value is num) {
        result[key] = value;
      }
      // Strings e outros tipos primitivos
      else {
        result[key] = value;
      }
    });
    
    return result;
  }

  /// Verifica se há dados sincronizados
  Future<bool> hasSyncedData() async {
    final stats = await DatabaseHelper.instance.getStats();
    return stats['artigos']! > 0;
  }

  /// Obtém estatísticas da última sincronização
  Future<Map<String, dynamic>?> getLastSyncInfo() async {
    return await DatabaseHelper.instance.getLastSync();
  }
}

/// Resultado da sincronização
class SyncResult {
  final bool success;
  final int totalRecords;
  final Duration duration;
  final String message;

  SyncResult({
    required this.success,
    required this.totalRecords,
    required this.duration,
    required this.message,
  });

  String get durationFormatted {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}