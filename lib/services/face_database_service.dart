// face_database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:akilli_kapi_guvenlik_sistemi/models/face_model.dart';
import '../core/error_handler.dart';
import '../core/exceptions.dart' as app_exceptions;

class FaceDatabaseService {
  static final FaceDatabaseService _instance = FaceDatabaseService._internal();
  factory FaceDatabaseService() => _instance;
  FaceDatabaseService._internal();

  static Database? _db;
  static const String _dbName = 'faces.db';
  static const int _dbVersion = 2;
  static const String _tableName = 'faces';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    try {
      ErrorHandler.info(
        'Veritabanı başlatılıyor',
        category: ErrorCategory.database,
        tag: 'INIT_START',
        metadata: {
          'dbName': _dbName,
          'dbVersion': _dbVersion,
        },
      );

      final dbPath = await getDatabasesPath();
      final dbFilePath = path.join(dbPath, _dbName);
      
      final db = await openDatabase(
        dbFilePath,
        version: _dbVersion,
        onCreate: (db, version) async {
          ErrorHandler.debug(
            'Veritabanı tabloları oluşturuluyor',
            category: ErrorCategory.database,
            tag: 'CREATE_TABLES',
          );
          
          await db.execute('''
            CREATE TABLE $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              gender TEXT NOT NULL,
              imagePaths TEXT NOT NULL,
              embedding TEXT NOT NULL
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          ErrorHandler.info(
            'Veritabanı güncelleniyor',
            category: ErrorCategory.database,
            tag: 'UPGRADE',
            metadata: {
              'oldVersion': oldVersion,
              'newVersion': newVersion,
            },
          );
          
          if (oldVersion == 1 && newVersion == 2) {
            await db.execute('ALTER TABLE $_tableName ADD COLUMN gender TEXT NOT NULL DEFAULT "male"');
          }
        },
      );

      ErrorHandler.info(
        'Veritabanı başarıyla başlatıldı',
        category: ErrorCategory.database,
        tag: 'INIT_SUCCESS',
        metadata: {
          'dbPath': dbFilePath,
          'dbVersion': _dbVersion,
        },
      );

      return db;
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'Veritabanı başlatma başarısız',
        category: ErrorCategory.database,
        tag: 'INIT_FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      
      throw app_exceptions.DatabaseException.connectionFailed();
    }
  }

  static Future<int> insertFace(FaceModel face) async {
    try {
      // Input validation
      if (face.name.trim().isEmpty) {
        throw app_exceptions.ValidationException.requiredField('name');
      }
      
      if (face.imagePaths.isEmpty) {
        throw app_exceptions.ValidationException.requiredField('imagePaths');
      }
      
      if (face.embedding == null || face.embedding!.isEmpty) {
        throw app_exceptions.ValidationException.requiredField('embedding');
      }

      ErrorHandler.debug(
        'Yüz kaydı ekleniyor',
        category: ErrorCategory.database,
        tag: 'INSERT_START',
        metadata: {
          'name': face.name,
          'gender': face.gender,
          'imageCount': face.imagePaths.length,
          'embeddingLength': face.embedding?.length ?? 0,
        },
      );

      final db = await database;
      
      // Aynı isimde kayıt var mı kontrol et
      final existingFaces = await db.query(
        _tableName,
        where: 'name = ?',
        whereArgs: [face.name.trim()],
      );
      
      if (existingFaces.isNotEmpty) {
        throw app_exceptions.DatabaseException.duplicateEntry('name');
      }
      
      final id = await db.insert(_tableName, {
        'name': face.name.trim(),
        'imagePaths': face.imagePaths.join(','),
        'embedding': face.embedding?.join(',') ?? '',
        'gender': face.gender,
      });

      ErrorHandler.info(
        'Yüz kaydı başarıyla eklendi',
        category: ErrorCategory.database,
        tag: 'INSERT_SUCCESS',
        metadata: {
          'id': id,
          'name': face.name,
          'gender': face.gender,
        },
      );

      return id;
    } catch (e, stackTrace) {
      // AppException türündeki hataları yeniden fırlat
      if (e is app_exceptions.AppException) {
        rethrow;
      }
      
      ErrorHandler.error(
        'Yüz kaydı eklenemedi',
        category: ErrorCategory.database,
        tag: 'INSERT_FAILED',
        error: e,
        stackTrace: stackTrace,
        metadata: {'name': face.name},
      );
      
      throw app_exceptions.DatabaseException.queryFailed('INSERT INTO $_tableName', e.toString());
    }
  }

  static Future<List<FaceModel>> getAllFaces() async {
    try {
      ErrorHandler.debug(
        'Tüm yüz kayıtları yükleniyor',
        category: ErrorCategory.database,
        tag: 'SELECT_ALL_START',
      );

      final db = await database;
      final maps = await db.query(_tableName);
      
      final faces = maps.map((map) => FaceModel.fromMap(map)).toList();

      ErrorHandler.debug(
        'Yüz kayıtları başarıyla yüklendi',
        category: ErrorCategory.database,
        tag: 'SELECT_ALL_SUCCESS',
        metadata: {
          'count': faces.length,
          'names': faces.map((f) => f.name).join(', '),
        },
      );

      return faces;
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'Yüz kayıtları yüklenemedi',
        category: ErrorCategory.database,
        tag: 'SELECT_ALL_FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      
      // Boş liste döndür ama hatayı logla
      return [];
    }
  }

  static Future<FaceModel?> getFaceById(int id) async {
    try {
      ErrorHandler.debug(
        'ID ile yüz kaydı aranıyor',
        category: ErrorCategory.database,
        tag: 'SELECT_BY_ID_START',
        metadata: {'id': id},
      );

      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isEmpty) {
        ErrorHandler.debug(
          'ID ile yüz kaydı bulunamadı',
          category: ErrorCategory.database,
          tag: 'SELECT_BY_ID_NOT_FOUND',
          metadata: {'id': id},
        );
        return null;
      }

      final face = FaceModel.fromMap(maps.first);
      
      ErrorHandler.debug(
        'ID ile yüz kaydı bulundu',
        category: ErrorCategory.database,
        tag: 'SELECT_BY_ID_SUCCESS',
        metadata: {
          'id': id,
          'name': face.name,
        },
      );

      return face;
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'ID ile yüz kaydı aranamadı',
        category: ErrorCategory.database,
        tag: 'SELECT_BY_ID_FAILED',
        error: e,
        stackTrace: stackTrace,
        metadata: {'id': id},
      );
      
      return null;
    }
  }

  static Future<int> deleteFace(FaceModel face) async {
    try {
      if (face.id == null) {
        throw app_exceptions.ValidationException.requiredField('id');
      }

      ErrorHandler.debug(
        'Yüz kaydı siliniyor',
        category: ErrorCategory.database,
        tag: 'DELETE_START',
        metadata: {
          'id': face.id,
          'name': face.name,
        },
      );

      final db = await database;
      final deletedRows = await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [face.id],
      );

      if (deletedRows == 0) {
        throw app_exceptions.DatabaseException.dataNotFound(_tableName);
      }

      ErrorHandler.info(
        'Yüz kaydı başarıyla silindi',
        category: ErrorCategory.database,
        tag: 'DELETE_SUCCESS',
        metadata: {
          'id': face.id,
          'name': face.name,
          'deletedRows': deletedRows,
        },
      );

      return deletedRows;
    } catch (e, stackTrace) {
      // AppException türündeki hataları yeniden fırlat
      if (e is app_exceptions.AppException) {
        rethrow;
      }
      
      ErrorHandler.error(
        'Yüz kaydı silinemedi',
        category: ErrorCategory.database,
        tag: 'DELETE_FAILED',
        error: e,
        stackTrace: stackTrace,
        metadata: {
          'id': face.id,
          'name': face.name,
        },
      );
      
      throw app_exceptions.DatabaseException.queryFailed('DELETE FROM $_tableName', e.toString());
    }
  }

  static Future<int> updateFace(FaceModel face) async {
    try {
      if (face.id == null) {
        throw app_exceptions.ValidationException.requiredField('id');
      }
      
      if (face.name.trim().isEmpty) {
        throw app_exceptions.ValidationException.requiredField('name');
      }

      ErrorHandler.debug(
        'Yüz kaydı güncelleniyor',
        category: ErrorCategory.database,
        tag: 'UPDATE_START',
        metadata: {
          'id': face.id,
          'name': face.name,
        },
      );

      final db = await database;
      final updatedRows = await db.update(
        _tableName,
        {
          'name': face.name.trim(),
          'gender': face.gender,
          'imagePaths': face.imagePaths.join(','),
          'embedding': face.embedding?.join(',') ?? '',
        },
        where: 'id = ?',
        whereArgs: [face.id],
      );

      if (updatedRows == 0) {
        throw app_exceptions.DatabaseException.dataNotFound(_tableName);
      }

      ErrorHandler.info(
        'Yüz kaydı başarıyla güncellendi',
        category: ErrorCategory.database,
        tag: 'UPDATE_SUCCESS',
        metadata: {
          'id': face.id,
          'name': face.name,
          'updatedRows': updatedRows,
        },
      );

      return updatedRows;
    } catch (e, stackTrace) {
      // AppException türündeki hataları yeniden fırlat
      if (e is app_exceptions.AppException) {
        rethrow;
      }
      
      ErrorHandler.error(
        'Yüz kaydı güncellenemedi',
        category: ErrorCategory.database,
        tag: 'UPDATE_FAILED',
        error: e,
        stackTrace: stackTrace,
        metadata: {
          'id': face.id,
          'name': face.name,
        },
      );
      
      throw app_exceptions.DatabaseException.queryFailed('UPDATE $_tableName', e.toString());
    }
  }

  /// Veritabanını kapat
  static Future<void> close() async {
    try {
      if (_db != null) {
        await _db!.close();
        _db = null;
        
        ErrorHandler.info(
          'Veritabanı bağlantısı kapatıldı',
          category: ErrorCategory.database,
          tag: 'CLOSE_SUCCESS',
        );
      }
    } catch (e) {
      ErrorHandler.warning(
        'Veritabanı bağlantısı kapatılırken hata',
        category: ErrorCategory.database,
        tag: 'CLOSE_ERROR',
      );
    }
  }
}
