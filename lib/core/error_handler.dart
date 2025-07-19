import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Log seviyeleri
enum LogLevel {
  debug(0, '🔍 DEBUG', Colors.grey),
  info(1, '📋 INFO', Colors.blue),
  warning(2, '⚠️ WARNING', Colors.orange),
  error(3, '❌ ERROR', Colors.red),
  critical(4, '🚨 CRITICAL', Colors.purple);
  
  const LogLevel(this.value, this.label, this.color);
  final int value;
  final String label;
  final Color color;
}

/// Hata kategorileri
enum ErrorCategory {
  authentication('AUTH', 'Kimlik Doğrulama'),
  camera('CAMERA', 'Kamera'),
  faceRecognition('FACE', 'Yüz Tanıma'),
  database('DB', 'Veritabanı'),
  network('NET', 'Ağ'),
  fileSystem('FILE', 'Dosya İşlemi'),
  model('MODEL', 'Model'),
  validation('VALID', 'Doğrulama'),
  system('SYS', 'Sistem'),
  ui('UI', 'Kullanıcı Arayüzü'),
  performance('PERF', 'Performans');
  
  const ErrorCategory(this.tag, this.displayName);
  final String tag;
  final String displayName;
}

/// Gelişmiş hata yönetimi ve loglama sistemi
class ErrorHandler {
  static const String _logFileName = 'app_logs.txt';
  static bool _fileLoggingEnabled = true;
  
  /// Kullanıcı dostu hata mesajları
  static final Map<String, String> _userFriendlyMessages = {
    'camera_permission': 'Kamera izni gereklidir. Lütfen uygulama ayarlarından kamera iznini açın.',
    'camera_not_available': 'Kamera kullanılamıyor. Lütfen cihazınızın kamerası çalışır durumda olduğundan emin olun.',
    'model_load_failed': 'Yüz tanıma modeli yüklenemedi. Lütfen uygulamayı yeniden başlatın.',
    'face_not_detected': 'Yüz bulunamadı. Lütfen kameraya doğru bakın ve yeterli ışık olduğundan emin olun.',
    'database_error': 'Veritabanı hatası oluştu. Lütfen uygulamayı yeniden başlatın.',
    'network_error': 'Ağ bağlantısı hatası. Lütfen internet bağlantınızı kontrol edin.',
    'file_not_found': 'Dosya bulunamadı. Uygulama dosyalarında bir sorun olabilir.',
    'invalid_input': 'Geçersiz giriş. Lütfen bilgileri doğru formatta girin.',
    'processing_error': 'İşlem sırasında hata oluştu. Lütfen tekrar deneyin.',
    'permission_denied': 'İzin reddedildi. Lütfen gerekli izinleri verin.',
    'unknown_error': 'Bilinmeyen bir hata oluştu. Lütfen uygulamayı yeniden başlatın.',
  };
  
  /// Gelişmiş loglama
  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    ErrorCategory? category,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final categoryTag = category?.tag ?? 'GENERAL';
    final customTag = tag ?? '';
    final fullTag = customTag.isNotEmpty ? '$categoryTag-$customTag' : categoryTag;
    
    // Structured log mesajı oluştur
    final logEntry = _buildLogEntry(
      timestamp: timestamp,
      level: level,
      tag: fullTag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
    
    // Konsola yazdır
    _printToConsole(logEntry, level);
    
    // Dosyaya yazdır
    if (_fileLoggingEnabled) {
      _writeToFile(logEntry);
    }
    
    // Developer log (Flutter DevTools için)
    developer.log(
      message,
      time: DateTime.now(),
      level: level.value,
      name: fullTag,
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Hata mesajını kullanıcıya göster
  static void showError(
    BuildContext context, 
    String message, {
    ErrorCategory? category,
    String? userFriendlyKey,
    bool isUserFriendly = false,
  }) {
    // Kullanıcı dostu mesaj varsa onu kullan
    String displayMessage = message;
    if (userFriendlyKey != null && _userFriendlyMessages.containsKey(userFriendlyKey)) {
      displayMessage = _userFriendlyMessages[userFriendlyKey]!;
    } else if (!isUserFriendly) {
      displayMessage = 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
    
    // Hatayı logla
    log(
      message,
      level: LogLevel.error,
      category: category ?? ErrorCategory.ui,
      tag: 'USER_ERROR',
    );
    
    // Kullanıcıya göster
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearMaterialBanners();
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: Text(
            displayMessage,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          leading: Icon(
            Icons.error_outline,
            color: Colors.red[700],
            size: 24,
          ),
          backgroundColor: Colors.red[50],
          actions: [
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text(
                'Kapat',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
  
  /// Başarı mesajını kullanıcıya göster
  static void showSuccess(
    BuildContext context, 
    String message, {
    ErrorCategory? category,
  }) {
    // Başarıyı logla
    log(
      message,
      level: LogLevel.info,
      category: category ?? ErrorCategory.ui,
      tag: 'SUCCESS',
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// Bilgi mesajını kullanıcıya göster
  static void showInfo(
    BuildContext context, 
    String message, {
    ErrorCategory? category,
  }) {
    // Bilgiyi logla
    log(
      message,
      level: LogLevel.info,
      category: category ?? ErrorCategory.ui,
      tag: 'INFO',
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// Uyarı mesajını kullanıcıya göster
  static void showWarning(
    BuildContext context, 
    String message, {
    ErrorCategory? category,
  }) {
    // Uyarıyı logla
    log(
      message,
      level: LogLevel.warning,
      category: category ?? ErrorCategory.ui,
      tag: 'WARNING',
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  
  /// Hızlı debug loglama
  static void debug(String message, {String? tag, ErrorCategory? category, Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.debug, tag: tag, category: category, metadata: metadata);
  }
  
  /// Hızlı info loglama
  static void info(String message, {String? tag, ErrorCategory? category, Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.info, tag: tag, category: category, metadata: metadata);
  }
  
  /// Hızlı warning loglama
  static void warning(String message, {String? tag, ErrorCategory? category, Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.warning, tag: tag, category: category, metadata: metadata);
  }
  
  /// Hızlı error loglama
  static void error(String message, {String? tag, ErrorCategory? category, Object? error, StackTrace? stackTrace, Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.error, tag: tag, category: category, error: error, stackTrace: stackTrace, metadata: metadata);
  }
  
  /// Hızlı critical loglama
  static void critical(String message, {String? tag, ErrorCategory? category, Object? error, StackTrace? stackTrace, Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.critical, tag: tag, category: category, error: error, stackTrace: stackTrace, metadata: metadata);
  }
  
  /// Dosyaya loglama durumunu değiştir
  static void setFileLogging(bool enabled) {
    _fileLoggingEnabled = enabled;
    log('File logging ${enabled ? 'enabled' : 'disabled'}', level: LogLevel.info, tag: 'CONFIG');
  }
  
  /// Log dosyasını temizle
  static Future<void> clearLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_logFileName');
      if (await file.exists()) {
        await file.delete();
        log('Log file cleared', level: LogLevel.info, tag: 'CONFIG');
      }
    } catch (e) {
      log('Failed to clear log file', level: LogLevel.error, error: e);
    }
  }
  
  /// Log dosyasını oku
  static Future<String?> readLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_logFileName');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      log('Failed to read log file', level: LogLevel.error, error: e);
      return null;
    }
  }
  
  // Private methods
  
  static String _buildLogEntry({
    required String timestamp,
    required LogLevel level,
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final buffer = StringBuffer();
    
    // Ana log satırı
    buffer.writeln('[$timestamp] [${level.label}] [$tag] $message');
    
    // Hata varsa ekle
    if (error != null) {
      buffer.writeln('  └── Error: $error');
    }
    
    // Stack trace varsa ekle
    if (stackTrace != null) {
      buffer.writeln('  └── Stack trace:');
      buffer.writeln('      ${stackTrace.toString().replaceAll('\n', '\n      ')}');
    }
    
    // Metadata varsa ekle
    if (metadata != null && metadata.isNotEmpty) {
      buffer.writeln('  └── Metadata:');
      metadata.forEach((key, value) {
        buffer.writeln('      $key: $value');
      });
    }
    
    return buffer.toString();
  }
  
  static void _printToConsole(String logEntry, LogLevel level) {
    // Konsola yazdır
    debugPrint(logEntry);
  }
  
  static void _writeToFile(String logEntry) {
    // Dosyaya yazma işlemi asenkron olarak yapılır
    _writeToFileAsync(logEntry);
  }
  
  static Future<void> _writeToFileAsync(String logEntry) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_logFileName');
      
      // Dosyaya append mode'da yaz
      await file.writeAsString(
        '$logEntry\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // Dosya yazma hatası - sadece debug yazdır
      debugPrint('Failed to write to log file: $e');
    }
  }
}
