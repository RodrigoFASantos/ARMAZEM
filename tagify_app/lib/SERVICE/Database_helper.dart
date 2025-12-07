import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('armazem.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8, // INCREMENTADO para forçar upgrade (adiciona campo Design)
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Apaga tudo e recria com nova estrutura
        await db.execute('DROP TABLE IF EXISTS SYNC_LOG');
        await db.execute('DROP TABLE IF EXISTS MOVIMENTOS');
        await db.execute('DROP TABLE IF EXISTS EQUIPAMENTO');
        await db.execute('DROP TABLE IF EXISTS ARTIGO');
        await db.execute('DROP TABLE IF EXISTS ARMAZEM');
        await db.execute('DROP TABLE IF EXISTS ESTADO');
        await db.execute('DROP TABLE IF EXISTS FAMILIA');
        await db.execute('DROP TABLE IF EXISTS TIPO');
        await db.execute('DROP TABLE IF EXISTS UTILIZADOR');
        await _createDB(db, newVersion);
      },
    );
  }



  Future<void> _createDB(Database db, int version) async {
    final schema = await rootBundle.loadString('assets/sql/TABELAS.sql');
    final cleanedSchema = schema.replaceAll(',\n);', '\n);');
    final commands = cleanedSchema.split(';');

    for (var command in commands) {
      final trimmed = command.trim();
      if (trimmed.isNotEmpty) {
        try {
          await db.execute(trimmed);
        } catch (e) {
          print('Erro SQL: $e');
        }
      }
    }
    print('Base de dados SQLite criada!');
  }

  // ==========================================
  // LIMPEZA DE DADOS
  // ==========================================

  Future<void> clearAllData() async {
    final db = await instance.database;

    await db.execute('DROP TABLE IF EXISTS SYNC_LOG');
    await db.execute('DROP TABLE IF EXISTS MOVIMENTOS');
    await db.execute('DROP TABLE IF EXISTS EQUIPAMENTO');
    await db.execute('DROP TABLE IF EXISTS ARTIGO');
    await db.execute('DROP TABLE IF EXISTS ARMAZEM');
    await db.execute('DROP TABLE IF EXISTS ESTADO');
    await db.execute('DROP TABLE IF EXISTS FAMILIA');
    await db.execute('DROP TABLE IF EXISTS TIPO');
    await db.execute('DROP TABLE IF EXISTS UTILIZADOR');

    final schema = await rootBundle.loadString('assets/sql/TABELAS.sql');
    final cleanedSchema = schema.replaceAll(',\n);', '\n);');
    final commands = cleanedSchema.split(';');

    for (var command in commands) {
      final trimmed = command.trim();
      if (trimmed.isNotEmpty) {
        try {
          await db.execute(trimmed);
        } catch (e) {
          print('Erro: $e');
        }
      }
    }
    print('Base de dados limpa e recriada!');
  }

  // ==========================================
  // INSERÇÃO EM LOTE (SINCRONIZAÇÃO)
  // ==========================================

  Future<void> insertTipos(List<Map<String, dynamic>> tipos) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var tipo in tipos) {
      // Garante que só insere colunas que existem na tabela TIPO (ID_tipo, Designacao)
      final tipoData = {
        'ID_tipo': tipo['ID_tipo'],
        // Se o servidor só enviar "Tipo" e não "Designacao", aproveita
        'Designacao': tipo['Designacao'] ?? tipo['Tipo'],
      };

      batch.insert(
        'TIPO',
        tipoData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${tipos.length} tipos inseridos!');
  }

  Future<void> insertFamilias(List<Map<String, dynamic>> familias) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var familia in familias) {
      batch.insert('FAMILIA', familia, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('${familias.length} famílias inseridas!');
  }

  Future<void> insertEstados(List<Map<String, dynamic>> estados) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var estado in estados) {
      batch.insert('ESTADO', estado, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('${estados.length} estados inseridos!');
  }

  Future<void> insertArmazens(List<Map<String, dynamic>> armazens) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var armazem in armazens) {
      // Só usa as colunas que existem na tabela ARMAZEM (ID_armazem, Descricao, Localizacao)
      final armazemData = {
        'ID_armazem': armazem['ID_armazem'],
        'Descricao': armazem['Descricao'],
        'Localizacao': armazem['Localizacao'],
      };
      batch.insert('ARMAZEM', armazemData, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('${armazens.length} armazéns inseridos!');
  }

  Future<void> insertArtigos(List<Map<String, dynamic>> artigos) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var artigo in artigos) {
      batch.insert('ARTIGO', artigo, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('${artigos.length} artigos inseridos!');
  }

  Future<void> insertEquipamentos(List<Map<String, dynamic>> equipamentos) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var equipamento in equipamentos) {
      batch.insert('EQUIPAMENTO', equipamento, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('${equipamentos.length} equipamentos inseridos!');
  }

  Future<void> insertMovimentos(List<Map<String, dynamic>> movimentos) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var movimento in movimentos) {
      batch.insert('MOVIMENTOS', movimento, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('${movimentos.length} movimentos inseridos!');
  }

  Future<void> insertUtilizadores(List<Map<String, dynamic>> utilizadores) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var utilizador in utilizadores) {
      batch.insert('UTILIZADOR', utilizador, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('${utilizadores.length} utilizadores inseridos!');
  }

  // ========================================== 
  // LOG DE SINCRONIZAÇÃO
  // ==========================================

  Future<void> logSync(int totalRegistos, bool sucesso) async {
    final db = await instance.database;
    await db.insert('SYNC_LOG', {
      'ultima_sync': DateTime.now().toIso8601String(),
      'total_registos': totalRegistos,
      'sucesso': sucesso ? 1 : 0,
    });
  }

  Future<Map<String, dynamic>?> getLastSync() async {
    final db = await instance.database;
    final result = await db.query('SYNC_LOG', orderBy: 'id DESC', limit: 1);
    if (result.isEmpty) return null;
    return result.first;
  }

  // ==========================================
  // CONSULTAS - ARTIGOS
  // ==========================================

  Future<List<Map<String, dynamic>>> getAllArtigos() async {
    final db = await instance.database;
    return await db.query('ARTIGO');
  }

  Future<Map<String, dynamic>?> getArtigoById(int id) async {
    final db = await instance.database;
    final result = await db.query('ARTIGO', where: 'ID_artigo = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return result.first;
  }

  Future<Map<String, dynamic>?> getArtigoByCodigo(String codigo) async {
    final db = await instance.database;
    final result = await db.query(
      'ARTIGO',
      where: 'Cod_bar = ? OR Cod_NFC = ? OR Cod_RFID = ? OR Referencia = ?',
      whereArgs: [codigo, codigo, codigo, codigo],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  // ==========================================
  // CONSULTAS - ARMAZÉM
  // ==========================================

  Future<Map<String, dynamic>?> getArmazemById(int id) async {
    final db = await instance.database;
    final result = await db.query('ARMAZEM', where: 'ID_armazem = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getAllArmazens() async {
    final db = await instance.database;
    return await db.query('ARMAZEM');
  }

  /// Busca armazém onde está o artigo (último movimento)
  Future<Map<String, dynamic>?> getArmazemByArtigo(int idArtigo) async {
    final db = await instance.database;
    
    // Buscar último movimento do artigo
    final movimentos = await db.query(
      'MOVIMENTOS',
      where: 'ID_artigo = ?',
      whereArgs: [idArtigo],
      orderBy: 'Data_mov DESC',
      limit: 1,
    );
    
    if (movimentos.isEmpty) return null;
    
    final idArmazem = movimentos.first['ID_armazem'];
    if (idArmazem == null) return null;
    
    return await getArmazemById(idArmazem as int);
  }

  // ==========================================
  // CONSULTAS - MOVIMENTOS
  // ==========================================

  Future<List<Map<String, dynamic>>> getMovimentosByArtigo(int idArtigo) async {
    final db = await instance.database;
    return await db.query(
      'MOVIMENTOS',
      where: 'ID_artigo = ?',
      whereArgs: [idArtigo],
      orderBy: 'Data_mov DESC',
    );
  }

  /// Calcula stock total de um artigo
  Future<double> getStockByArtigo(int idArtigo) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(Qtd_entrada), 0) - COALESCE(SUM(Qtd_saida), 0) as stock
      FROM MOVIMENTOS
      WHERE ID_artigo = ?
    ''', [idArtigo]);
    if (result.isEmpty) return 0;
    return (result.first['stock'] as num?)?.toDouble() ?? 0;
  }

  /// Busca stock detalhado por armazém e localização
  Future<List<Map<String, dynamic>>> getStockByArtigoAndArmazem(int idArtigo) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        m.ID_armazem,
        a.Descricao as armazem_descricao,
        m.Rack, m.NPrateleira, m.DPrateleira,
        m.NCorredor, m.DCorredor, m.Zona,
        COALESCE(SUM(m.Qtd_entrada), 0) - COALESCE(SUM(m.Qtd_saida), 0) as stock
      FROM MOVIMENTOS m
      LEFT JOIN ARMAZEM a ON m.ID_armazem = a.ID_armazem
      WHERE m.ID_artigo = ?
      GROUP BY 
        m.ID_armazem,
        m.Rack, m.NPrateleira, m.DPrateleira,
        m.NCorredor, m.DCorredor, m.Zona
      HAVING stock > 0
    ''', [idArtigo]);
  }

  // ==========================================
  // CONSULTAS - EQUIPAMENTOS
  // ==========================================

  Future<Map<String, dynamic>?> getEquipamentoByArtigo(int idArtigo) async {
    final db = await instance.database;
    final result = await db.query('EQUIPAMENTO', where: 'ID_artigo = ?', whereArgs: [idArtigo]);
    if (result.isEmpty) return null;
    return result.first;
  }

  Future<Map<String, dynamic>?> getEquipamentoComEstado(int idArtigo) async {
    final db = await instance.database;
    final results = await db.rawQuery('''
      SELECT e.*, est.Designacao as estado_designacao
      FROM EQUIPAMENTO e
      LEFT JOIN ESTADO est ON e.ID_Estado = est.ID_Estado
      WHERE e.ID_artigo = ?
    ''', [idArtigo]);
    if (results.isEmpty) return null;
    return results.first;
  }

  // ==========================================
  // CONSULTAS - TIPOS E FAMÍLIAS
  // ==========================================

  Future<Map<String, dynamic>?> getTipoById(int id) async {
    final db = await instance.database;
    final result = await db.query('TIPO', where: 'ID_tipo = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return result.first;
  }

  Future<Map<String, dynamic>?> getFamiliaById(int id) async {
    final db = await instance.database;
    final result = await db.query('FAMILIA', where: 'ID_familia = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return result.first;
  }

  // ==========================================
  // ESTATÍSTICAS
  // ==========================================

  Future<Map<String, int>> getStats() async {
    final db = await instance.database;
    final tipos = await db.rawQuery('SELECT COUNT(*) as count FROM TIPO');
    final familias = await db.rawQuery('SELECT COUNT(*) as count FROM FAMILIA');
    final estados = await db.rawQuery('SELECT COUNT(*) as count FROM ESTADO');
    final armazens = await db.rawQuery('SELECT COUNT(*) as count FROM ARMAZEM');
    final artigos = await db.rawQuery('SELECT COUNT(*) as count FROM ARTIGO');
    final equipamentos = await db.rawQuery('SELECT COUNT(*) as count FROM EQUIPAMENTO');
    final movimentos = await db.rawQuery('SELECT COUNT(*) as count FROM MOVIMENTOS');
    final utilizadores = await db.rawQuery('SELECT COUNT(*) as count FROM UTILIZADOR');

    return {
      'tipos': tipos.first['count'] as int,
      'familias': familias.first['count'] as int,
      'estados': estados.first['count'] as int,
      'armazens': armazens.first['count'] as int,
      'artigos': artigos.first['count'] as int,
      'equipamentos': equipamentos.first['count'] as int,
      'movimentos': movimentos.first['count'] as int,
      'utilizadores': utilizadores.first['count'] as int,
    };
  }

  // ==========================================
  // FECHAR BASE DE DADOS
  // ==========================================

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}