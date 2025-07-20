import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// HATA DÜZELTMESİ: Hata raporundaki tüm eksik kategoriler eklendi.
enum ErrorCategory {
  general,
  camera,
  database,
  faceRecognition,
  faceDetection,
  imageProcessing,
  network,
  file,
  authentication,
  fileSystem,
  model,
  validation,
  system,
  performance,
}

enum LogLevel {
  info,
  warning,
  error,
  critical,
  debug,
}

/// Uygulama genelinde hata yönetimi ve loglama işlemlerini merkeziyileştiren sınıf.
class ErrorHandler {
  static bool _logToFile = false;
  static String? _logFilePath;

  /// Hata yöneticisini başlatır.
  static Future<void> initialize({bool logToFile = false}) async {
    _logToFile = logToFile;
    if (_logToFile) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        _logFilePath = '${directory.path}/app_logs.txt';
        final file = File(_logFilePath!);
        if (await file.exists()) {
          await file.writeAsString('');
        }
        log('Loglama başlatıldı. Dosya yolu: $_logFilePath', level: LogLevel.info);
      } catch (e) {
        developer.log('Log dosyası oluşturulamadı: $e', name: 'ErrorHandler');
        _logToFile = false;
      }
    }
  }

  /// Hataları ve olayları loglar.
  static void log(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    LogLevel level = LogLevel.info,
    ErrorCategory category = ErrorCategory.general,
  }) {
    final now = DateTime.now();
    final logMessage =
        '[$now] [${level.name.toUpperCase()}] [${category.name.toUpperCase()}] $message';
    
    developer.log(
      logMessage,
      name: 'AppLogger',
      error: error,
      stackTrace: stackTrace,
      level: level.index * 500,
    );

    if (_logToFile && _logFilePath != null) {
      try {
        final file = File(_logFilePath!);
        file.writeAsStringSync('$logMessage\n', mode: FileMode.append);
        if (error != null) {
          file.writeAsStringSync('  ERROR: $error\n', mode: FileMode.append);
        }
        if (stackTrace != null) {
          file.writeAsStringSync('  STACKTRACE: $stackTrace\n', mode: FileMode.append);
        }
      } catch (e) {
        developer.log('Log dosyasına yazılamadı: $e', name: 'ErrorHandler');
      }
    }
  }

  /// Kullanıcıya bir hata mesajı gösterir (SnackBar).
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Kullanıcıya bir başarı mesajı gösterir (SnackBar).
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
