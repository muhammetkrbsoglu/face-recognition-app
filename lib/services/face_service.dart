import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../models/face_model.dart';

/// Sqflite tabanlı yüz kayıt servis sınıfı
class FaceService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final dbFilePath = path.join(dbPath, 'faces.db');
    return await openDatabase(
      dbFilePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE faces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            imagePaths TEXT NOT NULL,
            embedding TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Yüz ekle
  static Future<int> addFace(FaceModel face) async {
    final db = await database;
    return await db.insert('faces', {
      'name': face.name,
      'imagePaths': face.imagePaths.join(','),
      'embedding': face.embedding?.join(',') ?? '',
    });
  }

  /// Yüz sil
  static Future<int> deleteFace(int id) async {
    final db = await database;
    return await db.delete('faces', where: 'id = ?', whereArgs: [id]);
  }

  /// Belirli bir yüzü getir
  static Future<FaceModel?> getFace(int id) async {
    final db = await database;
    final maps = await db.query('faces', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return FaceModel.fromMap(maps.first);
    }
    return null;
  }

  /// Tüm yüzleri getir
  static Future<List<FaceModel>> getAllFaces() async {
    final db = await database;
    final maps = await db.query('faces');
    return maps.map((map) => FaceModel.fromMap(map)).toList();
  }

  /// Yüz güncelle
  static Future<int> updateFace(FaceModel face) async {
    final db = await database;
    return await db.update(
      'faces',
      {
        'name': face.name,
        'imagePaths': face.imagePaths.join(','),
        'embedding': face.embedding?.join(',') ?? '',
      },
      where: 'id = ?',
      whereArgs: [face.id],
    );
  }
}
