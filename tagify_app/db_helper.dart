import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Singleton - garante uma única instância
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('armazem.db');
    return _database!;
  }

  // Inicializa a base de dados
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Cria as tabelas (primeira instalação)
  Future _createDB(Database db, int version) async {
    // Lê o ficheiro TABELAS.sql dos assets
    final schema = await rootBundle.loadString('assets/sql/TABELAS.sql');
    
    // Executa cada comando SQL
    final commands = schema.split(';');
    for (final command in commands) {
      if (command.trim().isNotEmpty) {
        await db.execute(command);
      }
    }

    // Carrega dados iniciais
    final seedData = await rootBundle.loadString('assets/sql/DADOS.sql');
    final seedCommands = seedData.split(';');
    for (final command in seedCommands) {
      if (command.trim().isNotEmpty && !command.trim().startsWith('--')) {
        try {
          await db.execute(command);
        } catch (e) {
          print('Erro ao carregar seed: $e');
        }
      }
    }

    print('Base de dados criada com sucesso!');
  }

  // Upgrade da BD (futuras versões)
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Implementar migrações futuras aqui
    print('Upgrade de v$oldVersion para v$newVersion');
  }

  // === MÉTODOS DE CONSULTA ===

  // Buscar todos os artigos
  Future<List<Map<String, dynamic>>> getArtigos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        a.*,
        t.Tipo as tipo_codigo,
        t.Designacao as tipo_designacao,
        f.Designacao as familia_designacao
      FROM ARTIGO a
      LEFT JOIN TIPO t ON a.ID_tipo = t.ID_tipo
      LEFT JOIN FAMILIA f ON a.ID_familia = f.ID_familia
      ORDER BY a.Designacao
    ''');
  }

  // Buscar artigo por ID
  Future<Map<String, dynamic>?> getArtigoById(int id) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        a.*,
        t.Tipo as tipo_codigo,
        t.Designacao as tipo_designacao,
        f.Designacao as familia_designacao
      FROM ARTIGO a
      LEFT JOIN TIPO t ON a.ID_tipo = t.ID_tipo
      LEFT JOIN FAMILIA f ON a.ID_familia = f.ID_familia
      WHERE a.ID_artigo = ?
    ''', [id]);
    
    return results.isNotEmpty ? results.first : null;
  }

  // Buscar artigo por código (QR/NFC/RFID/Referência)
  Future<Map<String, dynamic>?> getArtigoByCodigo(String codigo) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        a.*,
        t.Tipo as tipo_codigo,
        t.Designacao as tipo_designacao,
        f.Designacao as familia_designacao
      FROM ARTIGO a
      LEFT JOIN TIPO t ON a.ID_tipo = t.ID_tipo
      LEFT JOIN FAMILIA f ON a.ID_familia = f.ID_familia
      WHERE a.Cod_bar = ? OR a.Cod_NFC = ? OR a.Cod_RFID = ? OR a.Referencia = ?
    ''', [codigo, codigo, codigo, codigo]);
    
    return results.isNotEmpty ? results.first : null;
  }

  // Buscar stock de um artigo (soma dos movimentos)
  Future<List<Map<String, dynamic>>> getStockByArtigo(int idArtigo) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        m.ID_armazem,
        a.Descricao as armazem,
        a.Localizacao as localizacao,
        SUM(m.Qtd_entrada - m.Qtd_saida) as stock
      FROM MOVIMENTOS m
      INNER JOIN ARMAZEM a ON m.ID_armazem = a.ID_armazem
      WHERE m.ID_artigo = ?
      GROUP BY m.ID_armazem, a.Descricao, a.Localizacao
      HAVING stock > 0
    ''', [idArtigo]);
  }

  // Buscar equipamentos
  Future<List<Map<String, dynamic>>> getEquipamentos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        e.*,
        a.Designacao as artigo_designacao,
        est.Designacao as estado_designacao
      FROM EQUIPAMENTO e
      INNER JOIN ARTIGO a ON e.ID_artigo = a.ID_artigo
      LEFT JOIN ESTADO est ON e.ID_Estado = est.ID_Estado
      ORDER BY e.ID_equipamento DESC
    ''');
  }

  // Buscar movimentos recentes
  Future<List<Map<String, dynamic>>> getMovimentosRecentes({int limit = 50}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        m.*,
        a.Designacao as artigo_designacao,
        arm.Descricao as armazem_descricao
      FROM MOVIMENTOS m
      INNER JOIN ARTIGO a ON m.ID_artigo = a.ID_artigo
      INNER JOIN ARMAZEM arm ON m.ID_armazem = arm.ID_armazem
      ORDER BY m.Data_mov DESC
      LIMIT ?
    ''', [limit]);
  }

  // === MÉTODOS DE SINCRONIZAÇÃO ===

  // Limpar todas as tabelas (antes de sync)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('MOVIMENTOS');
      await txn.delete('EQUIPAMENTO');
      await txn.delete('ARTIGO');
      await txn.delete('ARMAZEM');
      await txn.delete('FAMILIA');
      await txn.delete('TIPO');
      await txn.delete('ESTADO');
    });
    print('Dados antigos limpos');
  }

  // Inserir dados em lote (bulk insert)
  Future<void> insertBatch(String table, List<Map<String, dynamic>> data) async {
    final db = await database;
    final batch = db.batch();
    
    for (var row in data) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    await batch.commit(noResult: true);
    print('Inseridos ${data.length} registos em $table');
  }

  // Registar sincronização
  Future<void> logSync(int totalRegistos, bool sucesso) async {
    final db = await database;
    await db.insert('SYNC_LOG', {
      'ultima_sync': DateTime.now().toIso8601String(),
      'total_registos': totalRegistos,
      'sucesso': sucesso ? 1 : 0,
    });
  }

  // Obter última sincronização
  Future<Map<String, dynamic>?> getUltimaSync() async {
    final db = await database;
    final results = await db.query(
      'SYNC_LOG',
      orderBy: 'id DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Fechar conexão
  Future close() async {
    final db = await database;
    db.close();
  }

  // Apagar base de dados (debug)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'armazem.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
    print('Base de dados apagada');
  }
}