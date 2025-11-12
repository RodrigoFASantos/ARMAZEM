import 'dart:convert';
import 'package:http/http.dart' as http;
import 'db_helper.dart';

class SyncService {
  static const String baseUrl = 'http://127.0.0.1:8000';
  
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Estado da sincronização
  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Sincronização completa
  Future<bool> syncAll({Function(String)? onProgress}) async {
    if (_isSyncing) {
      print('⚠️ Sincronização já em progresso');
      return false;
    }

    _isSyncing = true;
    _lastError = null;
    
    try {
      onProgress?.call('Verificando conexão...');
      
      // Verifica conectividade
      final isOnline = await _checkConnection();
      if (!isOnline) {
        throw Exception('Sem conexão ao servidor');
      }

      onProgress?.call('Baixando dados do servidor...');

      // Busca todos os dados do servidor
      final syncData = await _fetchAllData();

      onProgress?.call('Limpando dados antigos...');
      
      // Limpa dados antigos
      await _db.clearAllData();

      onProgress?.call('Guardando novos dados...');

      // Insere dados novos
      int totalRegistos = 0;
      
      if (syncData['estados'] != null) {
        await _db.insertBatch('ESTADO', _convertList(syncData['estados']));
        totalRegistos += (syncData['estados'] as List).length;
        onProgress?.call('Estados: ${(syncData['estados'] as List).length}');
      }

      if (syncData['tipos'] != null) {
        await _db.insertBatch('TIPO', _convertList(syncData['tipos']));
        totalRegistos += (syncData['tipos'] as List).length;
        onProgress?.call('Tipos: ${(syncData['tipos'] as List).length}');
      }

      if (syncData['familias'] != null) {
        await _db.insertBatch('FAMILIA', _convertList(syncData['familias']));
        totalRegistos += (syncData['familias'] as List).length;
        onProgress?.call('Famílias: ${(syncData['familias'] as List).length}');
      }

      if (syncData['armazens'] != null) {
        await _db.insertBatch('ARMAZEM', _convertList(syncData['armazens']));
        totalRegistos += (syncData['armazens'] as List).length;
        onProgress?.call('Armazéns: ${(syncData['armazens'] as List).length}');
      }

      if (syncData['artigos'] != null) {
        await _db.insertBatch('ARTIGO', _convertList(syncData['artigos']));
        totalRegistos += (syncData['artigos'] as List).length;
        onProgress?.call('Artigos: ${(syncData['artigos'] as List).length}');
      }

      if (syncData['equipamentos'] != null) {
        await _db.insertBatch('EQUIPAMENTO', _convertList(syncData['equipamentos']));
        totalRegistos += (syncData['equipamentos'] as List).length;
        onProgress?.call('Equipamentos: ${(syncData['equipamentos'] as List).length}');
      }

      if (syncData['movimentos'] != null) {
        await _db.insertBatch('MOVIMENTOS', _convertList(syncData['movimentos']));
        totalRegistos += (syncData['movimentos'] as List).length;
        onProgress?.call('Movimentos: ${(syncData['movimentos'] as List).length}');
      }

      // Regista sincronização bem-sucedida
      await _db.logSync(totalRegistos, true);
      _lastSyncTime = DateTime.now();

      onProgress?.call('✅ Sincronização completa! ($totalRegistos registos)');
      
      _isSyncing = false;
      return true;

    } catch (e) {
      _lastError = e.toString();
      print('❌ Erro na sincronização: $e');
      
      // Regista sincronização falhada
      await _db.logSync(0, false);
      
      onProgress?.call('❌ Erro: ${e.toString()}');
      _isSyncing = false;
      return false;
    }
  }

  // Verifica conexão ao servidor
  Future<bool> _checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Busca todos os dados do endpoint /sync
  Future<Map<String, dynamic>> _fetchAllData() async {
    final response = await http
        .get(Uri.parse('$baseUrl/sync'))
        .timeout(Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar dados: ${response.statusCode}');
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // Converte lista de objetos dinâmicos para Map<String, dynamic>
  List<Map<String, dynamic>> _convertList(dynamic data) {
    if (data is! List) return [];
    return data.map((item) {
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      return <String, dynamic>{};
    }).toList();
  }

  // Sincronização apenas de artigos (mais rápido)
  Future<bool> syncArtigosOnly() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/artigos'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        // Limpa apenas artigos
        final db = await _db.database;
        await db.delete('ARTIGO');
        
        // Insere novos
        await _db.insertBatch('ARTIGO', _convertList(data));
        
        _lastSyncTime = DateTime.now();
        _isSyncing = false;
        return true;
      }
      
      throw Exception('Erro ao buscar artigos');
      
    } catch (e) {
      _lastError = e.toString();
      _isSyncing = false;
      return false;
    }
  }

  // Obter informação da última sincronização
  Future<Map<String, dynamic>?> getLastSyncInfo() async {
    return await _db.getUltimaSync();
  }

  // Verifica se precisa sincronizar (por exemplo, se passou mais de 24h)
  Future<bool> needsSync({Duration maxAge = const Duration(hours: 24)}) async {
    final lastSync = await _db.getUltimaSync();
    
    if (lastSync == null) return true;
    
    final lastSyncTime = DateTime.parse(lastSync['ultima_sync']);
    final now = DateTime.now();
    
    return now.difference(lastSyncTime) > maxAge;
  }
}