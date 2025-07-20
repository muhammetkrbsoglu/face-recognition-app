import 'dart:async';

import 'package:akilli_kapi_guvenlik_sistemi/core/error_handler.dart';
// HATA DÜZELTMESİ: Kendi exception sınıfımızı kullanmak için sqflite'ınkini gizliyoruz.
import 'package:akilli_kapi_guvenlik_sistemi/core/exceptions.dart' as custom_exceptions;
import 'package:akilli_kapi_guvenlik_sistemi/models/face_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Yüz verilerini yerel SQLite veritabanında yöneten servis.
class FaceDatabaseService {
  // Singleton pattern
  FaceDatabaseService._privateConstructor();
  static final FaceDatabaseService instance =
      FaceDatabaseService._privateConstructor();

  static Database? _database;
  static const String _dbName = 'faces.db';
  static const String _tableName = 'faces';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initialize();
    return _database!;
  }

  /// Veritabanını başlatır. Eğer mevcut değilse oluşturur ve tabloyu kurar.
  Future<Database> initialize() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Veritabanı ilk kez oluşturulduğunda çalışır.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gender TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        embeddings TEXT NOT NULL
      )
    ''');
  }

  /// Veritabanı sürümü yükseltildiğinde çalışır.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN gender TEXT NOT NULL DEFAULT "Belirtilmedi"');
      } catch (e) {
         ErrorHandler.log("'gender' sütunu zaten mevcut olabilir.", level: LogLevel.warning);
      }
    }
  }

  /// Veritabanına yeni bir yüz kaydı ekler.
  Future<void> insertFace(FaceModel face) async {
    try {
      final db = await database;
      await db.insert(
        _tableName,
        face.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, s) {
      ErrorHandler.log('Veritabanına yüz eklenemedi.', error: e, stackTrace: s, category: ErrorCategory.database);
      // HATA DÜZELTMESİ: Kendi exception sınıfımızı doğru şekilde çağırıyoruz.
      throw custom_exceptions.DatabaseException(message: 'Veritabanına kayıt eklenirken bir hata oluştu.');
    }
  }

  /// Veritabanındaki tüm yüz kayıtlarını getirir.
  Future<List<FaceModel>> getAllFaces() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(_tableName);
      return List.generate(maps.length, (i) {
        return FaceModel.fromMap(maps[i]);
      });
    } catch (e, s) {
       ErrorHandler.log('Veritabanından yüzler okunamadı.', error: e, stackTrace: s, category: ErrorCategory.database);
       throw custom_exceptions.DatabaseException(message: 'Veritabanından kayıtlar okunurken bir hata oluştu.');
    }
  }

  /// Belirtilen ID'ye sahip yüz kaydını siler.
  Future<void> deleteFace(int id) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, s) {
      ErrorHandler.log('Veritabanından yüz silinemedi.', error: e, stackTrace: s, category: ErrorCategory.database);
      throw custom_exceptions.DatabaseException(message: 'Veritabanından kayıt silinirken bir hata oluştu.');
    }
  }

  /// Veritabanındaki tüm kayıtları siler (Test veya sıfırlama için).
  Future<void> deleteAllFaces() async {
    try {
      final db = await database;
      await db.delete(_tableName);
    } catch (e, s) {
      ErrorHandler.log('Veritabanındaki tüm yüzler silinemedi.', error: e, stackTrace: s, category: ErrorCategory.database);
      throw custom_exceptions.DatabaseException(message: 'Veritabanı temizlenirken bir hata oluştu.');
    }
  }
}
