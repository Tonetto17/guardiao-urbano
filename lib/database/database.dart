import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final caminho = join(
      await getDatabasesPath(),
      'guardiao_urbano.db',
    );

    return await openDatabase(
      caminho,
      version: 3,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE ocorrencias_offline (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            categoria_id INTEGER NOT NULL,
            descricao TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            foto_path TEXT,
            sincronizada INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await database.execute('''
          CREATE TABLE categorias_offline (
            id INTEGER PRIMARY KEY,
            nome TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        await database.execute('''
          CREATE TABLE IF NOT EXISTS categorias_offline (
            id INTEGER PRIMARY KEY,
            nome TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<int> inserirOcorrencia(
      Map<String, dynamic> ocorrencia,
      ) async {
    final database = await DatabaseHelper.database;

    return await database.insert(
      'ocorrencias_offline',
      ocorrencia,
    );
  }

  static Future<List<Map<String, dynamic>>> listarOcorrencias() async {
    final database = await DatabaseHelper.database;

    return await database.rawQuery('''
      SELECT
        o.id,
        o.categoria_id,
        c.nome AS categoria,
        o.descricao,
        o.latitude,
        o.longitude,
        o.foto_path,
        o.sincronizada,
        o.created_at
      FROM ocorrencias_offline o
      LEFT JOIN categorias_offline c
        ON c.id = o.categoria_id
      WHERE o.sincronizada = 0
      ORDER BY o.id DESC
    ''');
  }

  static Future<List<Map<String, dynamic>>>
  listarOcorrenciasNaoSincronizadas() async {
    final database = await DatabaseHelper.database;

    return await database.query(
      'ocorrencias_offline',
      where: 'sincronizada = ?',
      whereArgs: [0],
      orderBy: 'id ASC',
    );
  }

  static Future<void> marcarOcorrenciaSincronizada(
      int id,
      ) async {
    final database = await DatabaseHelper.database;

    await database.update(
      'ocorrencias_offline',
      {
        'sincronizada': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> salvarCategorias(
      List<Map<String, dynamic>> categorias,
      ) async {
    final database = await DatabaseHelper.database;

    await database.transaction((transaction) async {
      await transaction.delete('categorias_offline');

      for (final categoria in categorias) {
        await transaction.insert(
          'categorias_offline',
          {
            'id': categoria['id'],
            'nome': categoria['nome'],
          },
        );
      }
    });
  }

  static Future<List<Map<String, dynamic>>> listarCategorias() async {
    final database = await DatabaseHelper.database;

    return await database.query(
      'categorias_offline',
      orderBy: 'nome',
    );
  }
}