import 'package:sqflite_sqlcipher/sqflite.dart';

class SecureStorage {
  // SQLite şifreleme için örnek
  static Future<Database> openEncryptedDb(String path, String password) async {
    return await openDatabase(path, password: password);
  }
}
