import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:tagify_app/models/models.dart';
import 'database_helper.dart';

class ApiService {
  // IMPORTANTE: Ajustar conforme necessario
  // Telemovel fisico -> usar o IP do PC: http://172.20.10.2:8000
  // Emulador Android: http://10.0.2.2:8000
  static const String baseUrl = 'http://172.20.10.2:8000';

  // ============================================
  // AUTENTICACAO (OFFLINE-FIRST)
  // ============================================
  
  /// Login que funciona OFFLINE usando base de dados local
  Future<LoginResponse> login(String username, String password) async {
    try {
      // PRIMEIRO: Tenta login OFFLINE (base de dados local)
      final offlineResult = await _loginOffline(username, password);
      
      if (offlineResult.success) {
        print('Login offline bem-sucedido');
        
        // SEGUNDO: Tenta sincronizar com servidor (background, nao bloqueia)
        _tryBackgroundSync(username, password);
        
        return offlineResult;
      }
      
      // Se falhou offline, tenta online (primeira vez ou sem dados locais)
      print('Login offline falhou, tentando online...');
      return await _loginOnline(username, password);
      
    } catch (e) {
      print('Erro no login: $e');
      return LoginResponse(
        success: false,
        message: 'Erro ao fazer login: $e',
      );
    }
  }

  /// Login OFFLINE usando SQLite
  Future<LoginResponse> _loginOffline(String username, String password) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      final results = await db.query(
        'UTILIZADOR',
        where: 'Username = ? AND Password = ? AND Ativo = 1',
        whereArgs: [username, password],
      );

      if (results.isEmpty) {
        return LoginResponse(
          success: false,
          message: 'Utilizador nao encontrado ou inativo (offline)',
        );
      }

      final userData = results.first;
      
      final utilizador = Utilizador(
        id: userData['ID_utilizador'] as int,
        nome: userData['Nome'] as String,
        email: userData['Email'] as String,
        username: userData['Username'] as String,
        password: userData['Password'] as String,
        ativo: (userData['Ativo'] as int) == 1,
      );

      return LoginResponse(
        success: true,
        message: 'Login bem-sucedido (modo offline)',
        utilizador: utilizador,
      );
      
    } catch (e) {
      print('Erro no login offline: $e');
      return LoginResponse(
        success: false,
        message: 'Dados locais nao disponiveis. Sincronize primeiro.',
      );
    }
  }

  /// Login ONLINE usando API
  Future<LoginResponse> _loginOnline(String username, String password) async {
    try {
      print('Tentando login online...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final loginResponse = LoginResponse.fromJson(json);
        
        // Se login online teve sucesso, salva utilizador localmente
        if (loginResponse.success && loginResponse.utilizador != null) {
          await _saveUserLocally(loginResponse.utilizador!);
        }
        
        return loginResponse;
      } else {
        return LoginResponse(
          success: false,
          message: 'Erro no servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erro no login online: $e');
      return LoginResponse(
        success: false,
        message: 'Sem conexao ao servidor. Use modo offline.',
      );
    }
  }

  /// Salva utilizador na base de dados local (para login offline)
  Future<void> _saveUserLocally(Utilizador user) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.insert(
        'UTILIZADOR',
        user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('Utilizador guardado localmente');
    } catch (e) {
      print('Erro ao guardar utilizador: $e');
    }
  }

  /// Tenta sincronizar em background (nao bloqueia o login)
  void _tryBackgroundSync(String username, String password) async {
    try {
      await _loginOnline(username, password);
    } catch (e) {
      // Ignora erros - e apenas tentativa em background
      print('Background sync falhou (ignorado): $e');
    }
  }

  // ============================================
  // HEALTH CHECK
  // ============================================

  Future<bool> healthCheck() async {
    try {
      print('Testando conexao com $baseUrl/sync/tipos');
      final response = await http
          .get(Uri.parse('$baseUrl/sync/tipos'))
          .timeout(const Duration(seconds: 5));
      
      print('Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('Servidor acessivel!');
        return true;
      }
      
      print('Servidor respondeu com codigo ${response.statusCode}');
      return false;
    } catch (e) {
      print('Health check falhou: $e');
      return false;
    }
  }

  /// Verifica se o servidor esta acessivel
  Future<bool> isServerAvailable() async {
    return await healthCheck();
  }

  // ============================================
  // ARTIGOS (OFFLINE-FIRST)
  // ============================================

  /// Busca artigos (OFFLINE primeiro, SEM background sync automatico)
  Future<List<Artigo>> getAllArtigos() async {
    try {
      // PRIMEIRO: Tenta buscar localmente
      final localArtigos = await _getArtigosOffline();
      
      if (localArtigos.isNotEmpty) {
        print('Carregados ${localArtigos.length} artigos do cache local');
        return localArtigos;
      }
      
      // Se nao ha dados locais, tenta buscar online
      print('Sem dados locais, tentando online...');
      return await _getArtigosOnline();
      
    } catch (e) {
      print('Erro ao buscar artigos: $e');
      return [];
    }
  }

  /// Busca artigos do SQLite local
  Future<List<Artigo>> _getArtigosOffline() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('ARTIGO');
      
      return results.map((row) => Artigo.fromJson(row)).toList();
    } catch (e) {
      print('Erro ao buscar artigos offline: $e');
      return [];
    }
  }

  /// Busca artigos da API
  Future<List<Artigo>> _getArtigosOnline() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/artigos'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        final artigos = json.map((item) => Artigo.fromJson(item)).toList();
        
        // Salva localmente para proxima vez
        await _saveArtigosLocally(artigos);
        
        return artigos;
      } else {
        print('Erro: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erro ao buscar artigos online: $e');
      return [];
    }
  }

  /// Salva artigos localmente
  Future<void> _saveArtigosLocally(List<Artigo> artigos) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final batch = db.batch();
      
      for (var artigo in artigos) {
        batch.insert(
          'ARTIGO',
          artigo.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
      print('${artigos.length} artigos guardados localmente');
    } catch (e) {
      print('Erro ao guardar artigos: $e');
    }
  }

  // ============================================
  // EQUIPAMENTOS (OFFLINE-FIRST)
  // ============================================

  /// Busca equipamentos com estados (OFFLINE primeiro)
  Future<List<Equipamento>> getAllEquipamentos() async {
    try {
      // PRIMEIRO: Tenta buscar localmente
      final localEquipamentos = await _getEquipamentosOffline();
      
      if (localEquipamentos.isNotEmpty) {
        print('Carregados ${localEquipamentos.length} equipamentos do cache local');
        return localEquipamentos;
      }
      
      // Se nao ha dados locais, tenta buscar online
      print('Sem dados locais, tentando online...');
      return await _getEquipamentosOnline();
      
    } catch (e) {
      print('Erro ao buscar equipamentos: $e');
      return [];
    }
  }

  /// Busca equipamentos do SQLite local com JOIN para pegar estado
  Future<List<Equipamento>> _getEquipamentosOffline() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Query com JOIN para buscar estado
      final results = await db.rawQuery('''
        SELECT 
          e.*,
          a.Designacao as artigo_designacao,
          est.Designacao as estado_designacao
        FROM EQUIPAMENTO e
        LEFT JOIN ARTIGO a ON e.ID_artigo = a.ID_artigo
        LEFT JOIN ESTADO est ON e.ID_Estado = est.ID_Estado
      ''');
      
      return results.map((row) => Equipamento.fromJson(row)).toList();
    } catch (e) {
      print('Erro ao buscar equipamentos offline: $e');
      return [];
    }
  }

  /// Busca equipamentos da API
Future<List<Equipamento>> _getEquipamentosOnline() async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/sync/equipamentos'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      final equipamentos =
          json.map((item) => Equipamento.fromJson(item)).toList();

      // (opcional) guardar localmente – ver ponto 3
      // await _saveEquipamentosLocally(equipamentos);

      return equipamentos;
    } else {
      print('Erro: ${response.statusCode} - ${response.body}');
      return [];
    }
  } catch (e) {
    print('Erro ao buscar equipamentos online: $e');
    return [];
  }
}
















  /// Busca equipamento por ID do artigo
  Future<Equipamento?> getEquipamentoByArtigoId(int idArtigo) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      final results = await db.rawQuery('''
        SELECT 
          e.*,
          a.Designacao as artigo_designacao,
          est.Designacao as estado_designacao
        FROM EQUIPAMENTO e
        LEFT JOIN ARTIGO a ON e.ID_artigo = a.ID_artigo
        LEFT JOIN ESTADO est ON e.ID_Estado = est.ID_Estado
        WHERE e.ID_artigo = ?
      ''', [idArtigo]);
      
      if (results.isEmpty) return null;
      return Equipamento.fromJson(results.first);
    } catch (e) {
      print('Erro ao buscar equipamento: $e');
      return null;
    }
  }

  // ============================================
  // ARTIGO POR ID (OFFLINE-FIRST)
  // ============================================

  Future<Artigo?> getArtigoById(int id) async {
    try {
      // Tenta offline primeiro
      final artigo = await _getArtigoByIdOffline(id);
      if (artigo != null) return artigo;
      
      // Se nao encontrou, tenta online
      return await _getArtigoByIdOnline(id);
    } catch (e) {
      print('Erro ao buscar artigo: $e');
      return null;
    }
  }

  Future<Artigo?> _getArtigoByIdOffline(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'ARTIGO',
        where: 'ID_artigo = ?',
        whereArgs: [id],
      );
      
      if (results.isEmpty) return null;
      return Artigo.fromJson(results.first);
    } catch (e) {
      return null;
    }
  }

  Future<Artigo?> _getArtigoByIdOnline(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/artigos/$id'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return Artigo.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Erro ao buscar artigo online: $e');
      return null;
    }
  }

  // ============================================
  // ARTIGO POR CODIGO (OFFLINE-FIRST)
  // ============================================

  Future<Artigo?> getArtigoByCodigo(String codigo) async {
    try {
      // Tenta offline primeiro
      final artigo = await _getArtigoByCodigoOffline(codigo);
      if (artigo != null) {
        print('Artigo encontrado offline: ${artigo.designacao}');
        return artigo;
      }
      
      // Se nao encontrou, tenta online
      return await _getArtigoByCodigoOnline(codigo);
    } catch (e) {
      print('Erro ao buscar artigo por codigo: $e');
      return null;
    }
  }

  Future<Artigo?> _getArtigoByCodigoOffline(String codigo) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'ARTIGO',
        where: 'Cod_bar = ? OR Cod_NFC = ? OR Cod_RFID = ? OR Referencia = ?',
        whereArgs: [codigo, codigo, codigo, codigo],
      );
      
      if (results.isEmpty) return null;
      return Artigo.fromJson(results.first);
    } catch (e) {
      return null;
    }
  }

  Future<Artigo?> _getArtigoByCodigoOnline(String codigo) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/artigos/codigo/$codigo'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final artigo = Artigo.fromJson(json);
        
        // Salva localmente
        await _saveArtigosLocally([artigo]);
        
        return artigo;
      }
      return null;
    } catch (e) {
      print('Erro ao buscar artigo por codigo online: $e');
      return null;
    }
  }
}