/// Özel exception sınıfları
/// 
/// Bu dosya, uygulamada kullanılacak tüm özel exception türlerini içerir.
/// Her exception, kullanıcı dostu mesajlar ve hata kategorileri içerir.

import 'error_handler.dart';

/// Temel uygulama exception sınıfı
abstract class AppException implements Exception {
  final String message;
  final String? userFriendlyMessage;
  final ErrorCategory category;
  final String? errorCode;
  final Map<String, dynamic>? metadata;

  const AppException({
    required this.message,
    required this.category,
    this.userFriendlyMessage,
    this.errorCode,
    this.metadata,
  });

  @override
  String toString() {
    return 'AppException: $message';
  }
}

/// Kamera ile ilgili hatalar
class CameraException extends AppException {
  const CameraException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.camera,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory CameraException.permissionDenied() {
    return const CameraException(
      message: 'Camera permission denied',
      userFriendlyMessage: 'Kamera izni gereklidir. Lütfen uygulama ayarlarından kamera iznini açın.',
      errorCode: 'CAMERA_PERMISSION_DENIED',
    );
  }

  factory CameraException.notAvailable() {
    return const CameraException(
      message: 'Camera not available',
      userFriendlyMessage: 'Kamera kullanılamıyor. Lütfen cihazınızın kamerası çalışır durumda olduğundan emin olun.',
      errorCode: 'CAMERA_NOT_AVAILABLE',
    );
  }

  factory CameraException.initializationFailed(String details) {
    return CameraException(
      message: 'Camera initialization failed: $details',
      userFriendlyMessage: 'Kamera başlatılamadı. Lütfen uygulamayı yeniden başlatın.',
      errorCode: 'CAMERA_INIT_FAILED',
      metadata: {'details': details},
    );
  }

  factory CameraException.captureFailed(String details) {
    return CameraException(
      message: 'Camera capture failed: $details',
      userFriendlyMessage: 'Fotoğraf çekilemedi. Lütfen tekrar deneyin.',
      errorCode: 'CAMERA_CAPTURE_FAILED',
      metadata: {'details': details},
    );
  }
}

/// Yüz tanıma ile ilgili hatalar
class FaceRecognitionException extends AppException {
  const FaceRecognitionException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.faceRecognition,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory FaceRecognitionException.modelNotLoaded() {
    return const FaceRecognitionException(
      message: 'Face recognition model not loaded',
      userFriendlyMessage: 'Yüz tanıma modeli yüklenemedi. Lütfen uygulamayı yeniden başlatın.',
      errorCode: 'MODEL_NOT_LOADED',
    );
  }

  factory FaceRecognitionException.noFaceDetected() {
    return const FaceRecognitionException(
      message: 'No face detected in image',
      userFriendlyMessage: 'Yüz bulunamadı. Lütfen kameraya doğru bakın ve yeterli ışık olduğundan emin olun.',
      errorCode: 'NO_FACE_DETECTED',
    );
  }

  factory FaceRecognitionException.multipleFacesDetected(int count) {
    return FaceRecognitionException(
      message: 'Multiple faces detected: $count',
      userFriendlyMessage: 'Birden fazla yüz algılandı. Lütfen sadece bir kişi kameraya baksın.',
      errorCode: 'MULTIPLE_FACES_DETECTED',
      metadata: {'faceCount': count},
    );
  }

  factory FaceRecognitionException.poorImageQuality(String reason) {
    return FaceRecognitionException(
      message: 'Poor image quality: $reason',
      userFriendlyMessage: 'Görüntü kalitesi yetersiz. Lütfen daha iyi ışıkta ve net bir şekilde çekin.',
      errorCode: 'POOR_IMAGE_QUALITY',
      metadata: {'reason': reason},
    );
  }

  factory FaceRecognitionException.embeddingExtractionFailed(String details) {
    return FaceRecognitionException(
      message: 'Embedding extraction failed: $details',
      userFriendlyMessage: 'Yüz analizi başarısız. Lütfen tekrar deneyin.',
      errorCode: 'EMBEDDING_EXTRACTION_FAILED',
      metadata: {'details': details},
    );
  }

  factory FaceRecognitionException.noMatchFound(double confidence) {
    return FaceRecognitionException(
      message: 'No matching face found',
      userFriendlyMessage: 'Yüz tanınamadı. Lütfen kayıtlı bir yüz ile deneyin.',
      errorCode: 'NO_MATCH_FOUND',
      metadata: {'confidence': confidence},
    );
  }
}

/// Kimlik doğrulama ile ilgili hatalar
class AuthenticationException extends AppException {
  const AuthenticationException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.authentication,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory AuthenticationException.biometricNotSupported() {
    return const AuthenticationException(
      message: 'Biometric authentication not supported',
      userFriendlyMessage: 'Cihazınız biyometrik doğrulamayı desteklemiyor.',
      errorCode: 'BIOMETRIC_NOT_SUPPORTED',
    );
  }

  factory AuthenticationException.biometricNotEnrolled() {
    return const AuthenticationException(
      message: 'Biometric not enrolled',
      userFriendlyMessage: 'Cihazınızda biyometrik doğrulama ayarlanmamış. Lütfen ayarlardan biyometrik doğrulamayı etkinleştirin.',
      errorCode: 'BIOMETRIC_NOT_ENROLLED',
    );
  }

  factory AuthenticationException.authenticationFailed() {
    return const AuthenticationException(
      message: 'Authentication failed',
      userFriendlyMessage: 'Kimlik doğrulama başarısız. Lütfen tekrar deneyin.',
      errorCode: 'AUTHENTICATION_FAILED',
    );
  }

  factory AuthenticationException.authenticationCanceled() {
    return const AuthenticationException(
      message: 'Authentication canceled by user',
      userFriendlyMessage: 'Kimlik doğrulama iptal edildi.',
      errorCode: 'AUTHENTICATION_CANCELED',
    );
  }
}

/// Veritabanı ile ilgili hatalar
class DatabaseException extends AppException {
  const DatabaseException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.database,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory DatabaseException.connectionFailed() {
    return const DatabaseException(
      message: 'Database connection failed',
      userFriendlyMessage: 'Veritabanı bağlantısı kurulamadı. Lütfen uygulamayı yeniden başlatın.',
      errorCode: 'DB_CONNECTION_FAILED',
    );
  }

  factory DatabaseException.queryFailed(String query, String error) {
    return DatabaseException(
      message: 'Database query failed: $error',
      userFriendlyMessage: 'Veritabanı işlemi başarısız. Lütfen tekrar deneyin.',
      errorCode: 'DB_QUERY_FAILED',
      metadata: {'query': query, 'error': error},
    );
  }

  factory DatabaseException.dataNotFound(String table) {
    return DatabaseException(
      message: 'Data not found in $table',
      userFriendlyMessage: 'Veri bulunamadı.',
      errorCode: 'DATA_NOT_FOUND',
      metadata: {'table': table},
    );
  }

  factory DatabaseException.duplicateEntry(String field) {
    return DatabaseException(
      message: 'Duplicate entry for $field',
      userFriendlyMessage: 'Bu kayıt zaten mevcut.',
      errorCode: 'DUPLICATE_ENTRY',
      metadata: {'field': field},
    );
  }
}

/// Ağ bağlantısı ile ilgili hatalar
class NetworkException extends AppException {
  const NetworkException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.network,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory NetworkException.connectionTimeout() {
    return const NetworkException(
      message: 'Network connection timeout',
      userFriendlyMessage: 'Bağlantı zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin.',
      errorCode: 'CONNECTION_TIMEOUT',
    );
  }

  factory NetworkException.noInternetConnection() {
    return const NetworkException(
      message: 'No internet connection',
      userFriendlyMessage: 'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.',
      errorCode: 'NO_INTERNET_CONNECTION',
    );
  }

  factory NetworkException.serverError(int statusCode) {
    return NetworkException(
      message: 'Server error: $statusCode',
      userFriendlyMessage: 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.',
      errorCode: 'SERVER_ERROR',
      metadata: {'statusCode': statusCode},
    );
  }

  factory NetworkException.requestFailed(String url, String error) {
    return NetworkException(
      message: 'Request failed: $error',
      userFriendlyMessage: 'İstek başarısız. Lütfen tekrar deneyin.',
      errorCode: 'REQUEST_FAILED',
      metadata: {'url': url, 'error': error},
    );
  }
}

/// Dosya sistemi ile ilgili hatalar
class FileSystemException extends AppException {
  const FileSystemException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.fileSystem,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory FileSystemException.fileNotFound(String path) {
    return FileSystemException(
      message: 'File not found: $path',
      userFriendlyMessage: 'Dosya bulunamadı.',
      errorCode: 'FILE_NOT_FOUND',
      metadata: {'path': path},
    );
  }

  factory FileSystemException.permissionDenied(String path) {
    return FileSystemException(
      message: 'Permission denied: $path',
      userFriendlyMessage: 'Dosya erişim izni reddedildi.',
      errorCode: 'PERMISSION_DENIED',
      metadata: {'path': path},
    );
  }

  factory FileSystemException.diskFull() {
    return const FileSystemException(
      message: 'Disk full',
      userFriendlyMessage: 'Cihaz belleği dolu. Lütfen boş alan açın.',
      errorCode: 'DISK_FULL',
    );
  }

  factory FileSystemException.readFailed(String path, String error) {
    return FileSystemException(
      message: 'File read failed: $error',
      userFriendlyMessage: 'Dosya okunamadı.',
      errorCode: 'FILE_READ_FAILED',
      metadata: {'path': path, 'error': error},
    );
  }

  factory FileSystemException.writeFailed(String path, String error) {
    return FileSystemException(
      message: 'File write failed: $error',
      userFriendlyMessage: 'Dosya yazılamadı.',
      errorCode: 'FILE_WRITE_FAILED',
      metadata: {'path': path, 'error': error},
    );
  }
}

/// Model ile ilgili hatalar
class ModelException extends AppException {
  const ModelException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.model,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory ModelException.loadFailed(String modelName, String error) {
    return ModelException(
      message: 'Model load failed: $error',
      userFriendlyMessage: 'Model yüklenemedi. Lütfen uygulamayı yeniden başlatın.',
      errorCode: 'MODEL_LOAD_FAILED',
      metadata: {'modelName': modelName, 'error': error},
    );
  }

  factory ModelException.inferenceError(String modelName, String error) {
    return ModelException(
      message: 'Model inference error: $error',
      userFriendlyMessage: 'Model çalıştırılamadı. Lütfen tekrar deneyin.',
      errorCode: 'MODEL_INFERENCE_ERROR',
      metadata: {'modelName': modelName, 'error': error},
    );
  }

  factory ModelException.unsupportedFormat(String format) {
    return ModelException(
      message: 'Unsupported model format: $format',
      userFriendlyMessage: 'Desteklenmeyen model formatı.',
      errorCode: 'UNSUPPORTED_FORMAT',
      metadata: {'format': format},
    );
  }
}

/// Doğrulama ile ilgili hatalar
class ValidationException extends AppException {
  const ValidationException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.validation,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory ValidationException.invalidInput(String field, String value) {
    return ValidationException(
      message: 'Invalid input for $field: $value',
      userFriendlyMessage: 'Geçersiz giriş. Lütfen bilgileri doğru formatta girin.',
      errorCode: 'INVALID_INPUT',
      metadata: {'field': field, 'value': value},
    );
  }

  factory ValidationException.requiredField(String field) {
    return ValidationException(
      message: 'Required field missing: $field',
      userFriendlyMessage: 'Gerekli alan boş bırakılamaz.',
      errorCode: 'REQUIRED_FIELD',
      metadata: {'field': field},
    );
  }

  factory ValidationException.invalidRange(String field, dynamic value, dynamic min, dynamic max) {
    return ValidationException(
      message: 'Value out of range for $field: $value (expected: $min-$max)',
      userFriendlyMessage: 'Değer geçerli aralığın dışında.',
      errorCode: 'INVALID_RANGE',
      metadata: {'field': field, 'value': value, 'min': min, 'max': max},
    );
  }
}

/// Sistem ile ilgili hatalar
class SystemException extends AppException {
  const SystemException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.system,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory SystemException.insufficientMemory() {
    return const SystemException(
      message: 'Insufficient memory',
      userFriendlyMessage: 'Yetersiz bellek. Lütfen diğer uygulamaları kapatın.',
      errorCode: 'INSUFFICIENT_MEMORY',
    );
  }

  factory SystemException.platformNotSupported(String platform) {
    return SystemException(
      message: 'Platform not supported: $platform',
      userFriendlyMessage: 'Bu platform desteklenmiyor.',
      errorCode: 'PLATFORM_NOT_SUPPORTED',
      metadata: {'platform': platform},
    );
  }

  factory SystemException.serviceFailed(String service, String error) {
    return SystemException(
      message: 'Service failed: $service - $error',
      userFriendlyMessage: 'Sistem servisi çalışmıyor. Lütfen uygulamayı yeniden başlatın.',
      errorCode: 'SERVICE_FAILED',
      metadata: {'service': service, 'error': error},
    );
  }
}

/// Performans ile ilgili hatalar
class PerformanceException extends AppException {
  const PerformanceException({
    required String message,
    String? userFriendlyMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  }) : super(
          message: message,
          category: ErrorCategory.performance,
          userFriendlyMessage: userFriendlyMessage,
          errorCode: errorCode,
          metadata: metadata,
        );

  factory PerformanceException.operationTimeout(String operation, int timeoutMs) {
    return PerformanceException(
      message: 'Operation timeout: $operation (${timeoutMs}ms)',
      userFriendlyMessage: 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.',
      errorCode: 'OPERATION_TIMEOUT',
      metadata: {'operation': operation, 'timeoutMs': timeoutMs},
    );
  }

  factory PerformanceException.resourceExhausted(String resource) {
    return PerformanceException(
      message: 'Resource exhausted: $resource',
      userFriendlyMessage: 'Sistem kaynakları yetersiz. Lütfen diğer uygulamaları kapatın.',
      errorCode: 'RESOURCE_EXHAUSTED',
      metadata: {'resource': resource},
    );
  }

  factory PerformanceException.performanceDegraded(String metric, double value, double threshold) {
    return PerformanceException(
      message: 'Performance degraded: $metric = $value (threshold: $threshold)',
      userFriendlyMessage: 'Performans düştü. Lütfen uygulamayı yeniden başlatın.',
      errorCode: 'PERFORMANCE_DEGRADED',
      metadata: {'metric': metric, 'value': value, 'threshold': threshold},
    );
  }
} 