import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _databaseVersion = 1;
  static const String _databaseName = 'guardiao_urbano.db';

  static const String categoriasTable = 'categorias';
  static const String ocorrenciasTable = 'ocorrencias';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _criarTabelas,
      onUpgrade: _atualizarBanco,
    );

    return _database!;
  }

  Future<void> _criarTabelas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $categoriasTable (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        atualizado_em TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $ocorrenciasTable (
        id_local TEXT PRIMARY KEY,
        id_servidor TEXT,
        usuario_id TEXT NOT NULL,
        categoria_id INTEGER,
        categoria_nome TEXT,
        descricao TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDENTE',
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        foto_caminho TEXT,
        foto_url TEXT,
        criado_em TEXT NOT NULL,
        estado_sincronizacao TEXT NOT NULL DEFAULT 'PENDENTE',
        erro_sincronizacao TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_ocorrencias_usuario
      ON $ocorrenciasTable (usuario_id, criado_em)
    ''');

    await db.execute('''
      CREATE INDEX idx_ocorrencias_sincronizacao
      ON $ocorrenciasTable (estado_sincronizacao)
    ''');
  }

  Future<void> _atualizarBanco(
      Database db,
      int versaoAntiga,
      int versaoNova,
      ) async {
  }

  Future<void> salvarCategorias(List<Map<String, dynamic>> categorias) async {
    final db = await database;
    final batch = db.batch();

    for (final categoria in categorias) {
      final id = _intOuNull(categoria['id']);
      final nome = categoria['nome']?.toString().trim();

      if (id == null || nome == null || nome.isEmpty) continue;

      batch.insert(
        categoriasTable,
        {
          'id': id,
          'nome': nome,
          'atualizado_em': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> listarCategorias() async {
    final db = await database;
    return db.query(categoriasTable, orderBy: 'nome COLLATE NOCASE ASC');
  }

  Future<void> salvarOcorrenciaLocal({
    required String idLocal,
    required String usuarioId,
    required String descricao,
    required double latitude,
    required double longitude,
    int? categoriaId,
    String? categoriaNome,
    String? fotoCaminho,
    String status = 'PENDENTE',
  }) async {
    final db = await database;

    await db.insert(
      ocorrenciasTable,
      {
        'id_local': idLocal,
        'usuario_id': usuarioId,
        'categoria_id': categoriaId,
        'categoria_nome': categoriaNome,
        'descricao': descricao,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'foto_caminho': fotoCaminho,
        'criado_em': DateTime.now().toIso8601String(),
        'estado_sincronizacao': 'PENDENTE',
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> listarOcorrencias({
    required String usuarioId,
  }) async {
    final db = await database;

    return db.query(
      ocorrenciasTable,
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: 'criado_em DESC',
    );
  }

  Future<List<Map<String, dynamic>>> listarPendentes() async {
    final db = await database;

    return db.query(
      ocorrenciasTable,
      where: "estado_sincronizacao IN ('PENDENTE', 'ERRO')",
      orderBy: 'criado_em ASC',
    );
  }

  Future<void> marcarSincronizando(String idLocal) async {
    final db = await database;

    await db.update(
      ocorrenciasTable,
      {
        'estado_sincronizacao': 'SINCRONIZANDO',
        'erro_sincronizacao': null,
      },
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  Future<void> marcarSincronizada({
    required String idLocal,
    required String idServidor,
    String? fotoUrl,
  }) async {
    final db = await database;

    await db.update(
      ocorrenciasTable,
      {
        'id_servidor': idServidor,
        'foto_url': fotoUrl,
        'estado_sincronizacao': 'SINCRONIZADO',
        'erro_sincronizacao': null,
      },
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  Future<void> marcarErroSincronizacao({
    required String idLocal,
    required String mensagem,
  }) async {
    final db = await database;

    await db.update(
      ocorrenciasTable,
      {
        'estado_sincronizacao': 'ERRO',
        'erro_sincronizacao': mensagem,
      },
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  Future<void> atualizarOcorrenciaDoServidor({
    required String idLocal,
    required String idServidor,
    required String status,
    String? fotoUrl,
  }) async {
    final db = await database;

    await db.update(
      ocorrenciasTable,
      {
        'id_servidor': idServidor,
        'status': status,
        if (fotoUrl != null) 'foto_url': fotoUrl,
        'estado_sincronizacao': 'SINCRONIZADO',
        'erro_sincronizacao': null,
      },
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  Future<void> fechar() async {
    await _database?.close();
    _database = null;
  }

  int? _intOuNull(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    return int.tryParse(valor.toString());
  }
}
