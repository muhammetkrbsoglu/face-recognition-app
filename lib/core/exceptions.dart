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
    return 'AppException ($category): $message';
  }
}

/// Kamera ile ilgili hatalar
class CameraException extends AppException {
  const CameraException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.camera);

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
}

/// Yüz tanıma ile ilgili hatalar
class FaceRecognitionException extends AppException {
  const FaceRecognitionException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.faceRecognition);

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

  factory FaceRecognitionException.embeddingExtractionFailed(String details) {
    return FaceRecognitionException(
      message: 'Embedding extraction failed: $details',
      userFriendlyMessage: 'Yüz analizi başarısız. Lütfen tekrar deneyin.',
      errorCode: 'EMBEDDING_EXTRACTION_FAILED',
      metadata: {'details': details},
    );
  }
}

// Diğer exception sınıfları da benzer şekilde `use_super_parameters` kuralına göre güncellendi.

/// Kimlik doğrulama ile ilgili hatalar
class AuthenticationException extends AppException {
  const AuthenticationException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.authentication);
}

/// Veritabanı ile ilgili hatalar
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.database);

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
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.network);

  factory NetworkException.connectionTimeout() {
    return const NetworkException(
      message: 'Network connection timeout',
      userFriendlyMessage: 'Bağlantı zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin.',
      errorCode: 'CONNECTION_TIMEOUT',
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
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.fileSystem);

  factory FileSystemException.fileNotFound(String path) {
    return FileSystemException(
      message: 'File not found: $path',
      userFriendlyMessage: 'Dosya bulunamadı.',
      errorCode: 'FILE_NOT_FOUND',
      metadata: {'path': path},
    );
  }
}

/// Model ile ilgili hatalar
class ModelException extends AppException {
  const ModelException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.model);

  factory ModelException.loadFailed(String modelName, String error) {
    return ModelException(
      message: 'Model load failed: $error',
      userFriendlyMessage: 'Model yüklenemedi. Lütfen uygulamayı yeniden başlatın.',
      errorCode: 'MODEL_LOAD_FAILED',
      metadata: {'modelName': modelName, 'error': error},
    );
  }
}

/// Doğrulama ile ilgili hatalar
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.validation);

  factory ValidationException.requiredField(String field) {
    return ValidationException(
      message: 'Required field missing: $field',
      userFriendlyMessage: 'Gerekli alan boş bırakılamaz.',
      errorCode: 'REQUIRED_FIELD',
      metadata: {'field': field},
    );
  }
}

/// Sistem ile ilgili hatalar
class SystemException extends AppException {
  const SystemException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.system);
}

/// Performans ile ilgili hatalar
class PerformanceException extends AppException {
  const PerformanceException({
    required super.message,
    super.userFriendlyMessage,
    super.errorCode,
    super.metadata,
  }) : super(category: ErrorCategory.performance);
}
