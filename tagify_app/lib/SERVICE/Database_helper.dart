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
    version: 2,  // Mudei de 1 para 2!
    onCreate: _createDB,
    onUpgrade: (db, oldVersion, newVersion) async {
      // Apaga tudo e recria
      await db.execute('DROP TABLE IF EXISTS EQUIPAMENTO');
      await _createDB(db, newVersion);
    },
  );
}

  Future<void> _createDB(Database db, int version) async {
    // Lê o schema SQL do arquivo assets
    final schema = await rootBundle.loadString('assets/sql/TABELAS.sql');

    // Remove vírgulas extras antes do último parêntese (erro no SQL)
    final cleanedSchema = schema.replaceAll(',\n);', '\n);');

    // Separa os comandos SQL
    final commands = cleanedSchema.split(';');

    // Executa cada comando
    for (var command in commands) {
      final trimmed = command.trim();
      if (trimmed.isNotEmpty) {
        try {
          await db.execute(trimmed);
        } catch (e) {
          print('Erro ao executar comando SQL: $e');
          print('Comando: $trimmed');
        }
      }
    }

    print('Base de dados SQLite criada com sucesso!');
  }

  // ==========================================
  // LIMPEZA DE DADOS
  // ==========================================

Future<void> clearAllData() async {
  final db = await instance.database;
  
  // Apaga as tabelas (se existirem) e recria-as
  await db.execute('DROP TABLE IF EXISTS MOVIMENTOS');
  await db.execute('DROP TABLE IF EXISTS EQUIPAMENTO');
  await db.execute('DROP TABLE IF EXISTS ARTIGO');
  await db.execute('DROP TABLE IF EXISTS ARMAZEM');
  await db.execute('DROP TABLE IF EXISTS ESTADO');
  await db.execute('DROP TABLE IF EXISTS FAMILIA');
  await db.execute('DROP TABLE IF EXISTS TIPO');
  await db.execute('DROP TABLE IF EXISTS UTILIZADOR');
  await db.execute('DROP TABLE IF EXISTS SYNC_LOG');
  
  // Recria o schema completo
  final schema = await rootBundle.loadString('assets/sql/TABELAS.sql');
  final cleanedSchema = schema.replaceAll(',\n);', '\n);');
  final commands = cleanedSchema.split(';');
  
  for (var command in commands) {
    final trimmed = command.trim();
    if (trimmed.isNotEmpty) {
      try {
        await db.execute(trimmed);
      } catch (e) {
        print('Erro ao executar: $e');
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
      batch.insert('TIPO', tipo, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    print('${tipos.length} tipos inseridos!');
  }

  Future<void> insertFamilias(List<Map<String, dynamic>> familias) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var familia in familias) {
      batch.insert(
        'FAMILIA',
        familia,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${familias.length} famílias inseridas!');
  }

  Future<void> insertEstados(List<Map<String, dynamic>> estados) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var estado in estados) {
      batch.insert(
        'ESTADO',
        estado,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${estados.length} estados inseridos!');
  }

  Future<void> insertArmazens(List<Map<String, dynamic>> armazens) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var armazem in armazens) {
      batch.insert(
        'ARMAZEM',
        armazem,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${armazens.length} armazéns inseridos!');
  }

  Future<void> insertArtigos(List<Map<String, dynamic>> artigos) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var artigo in artigos) {
      batch.insert(
        'ARTIGO',
        artigo,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${artigos.length} artigos inseridos!');
  }

  Future<void> insertEquipamentos(
    List<Map<String, dynamic>> equipamentos,
  ) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var equipamento in equipamentos) {
      batch.insert(
        'EQUIPAMENTO',
        equipamento,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${equipamentos.length} equipamentos inseridos!');
  }

  Future<void> insertMovimentos(List<Map<String, dynamic>> movimentos) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var movimento in movimentos) {
      batch.insert(
        'MOVIMENTOS',
        movimento,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${movimentos.length} movimentos inseridos!');
  }

  Future<void> insertUtilizadores(
    List<Map<String, dynamic>> utilizadores,
  ) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var utilizador in utilizadores) {
      batch.insert(
        'UTILIZADOR',
        utilizador,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('${utilizadores.length} utilizadores inseridos!');
  }

  // ==========================================
  // LOG DE SINCRONIZAÇÃO
  // ==========================================

  Future<void> logSync(int totalRegistos, bool sucesso) async {
    final db = await instance.database;

    // Cria a tabela se não existir
    await db.execute('''
    CREATE TABLE IF NOT EXISTS SYNC_LOG (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ultima_sync TEXT NOT NULL,
      total_registos INTEGER DEFAULT 0,
      sucesso INTEGER DEFAULT 1
    )
  ''');

    await db.insert('SYNC_LOG', {
      'ultima_sync': DateTime.now().toIso8601String(),
      'total_registos': totalRegistos,
      'sucesso': sucesso ? 1 : 0,
    });
  }

  Future<Map<String, dynamic>?> getLastSync() async {
    final db = await instance.database;

    // Cria a tabela se não existir
    await db.execute('''
    CREATE TABLE IF NOT EXISTS SYNC_LOG (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ultima_sync TEXT NOT NULL,
      total_registos INTEGER DEFAULT 0,
      sucesso INTEGER DEFAULT 1
    )
  ''');

    final result = await db.query('SYNC_LOG', orderBy: 'id DESC', limit: 1);

    if (result.isEmpty) return null;
    return result.first;
  }

  // ==========================================
  // CONSULTAS LOCAIS
  // ==========================================

  Future<List<Map<String, dynamic>>> getAllArtigos() async {
    final db = await instance.database;
    return await db.query('ARTIGO');
  }

  Future<Map<String, dynamic>?> getArtigoById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'ARTIGO',
      where: 'ID_artigo = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return result.first;
  }

  Future<Map<String, dynamic>?> getArtigoByCodigo(String codigo) async {
    final db = await instance.database;
    final result = await db.query(
      'ARTIGO',
      where: 'Cod_bar = ? OR Cod_NFC = ? OR Cod_RFID = ?',
      whereArgs: [codigo, codigo, codigo],
    );

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
    final equipamentos = await db.rawQuery(
      'SELECT COUNT(*) as count FROM EQUIPAMENTO',
    );
    final movimentos = await db.rawQuery(
      'SELECT COUNT(*) as count FROM MOVIMENTOS',
    );
    final utilizadores = await db.rawQuery(
      'SELECT COUNT(*) as count FROM UTILIZADOR',
    );

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
