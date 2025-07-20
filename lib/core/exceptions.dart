import 'package:akilli_kapi_guvenlik_sistemi/core/error_handler.dart';
// HATA DÜZELTMESİ: İsim çakışmasını önlemek için sqflite'ın exception'ı gizlendi.
import 'package:sqflite/sqflite.dart' hide DatabaseException;

/// Uygulama içindeki özel hatalar için temel sınıf.
class AppException implements Exception {
  final String message;
  final String? developerMessage;
  final ErrorCategory category;

  AppException({
    required this.message,
    this.developerMessage,
    required this.category,
  });

  @override
  String toString() => 'AppException: [$category] $message';
}

// --- Kamera Hataları ---
class CameraException extends AppException {
  CameraException({
    String message = 'Kamera ile ilgili bir sorun oluştu.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.camera,
        );
}

// --- Veritabanı Hataları ---
class DatabaseException extends AppException {
  DatabaseException({
    String message = 'Veritabanı işlemi sırasında bir hata oluştu.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.database,
        );
}

// --- Yüz Tanıma ve İşleme Hataları ---
class FaceRecognitionException extends AppException {
  FaceRecognitionException({
    String message = 'Yüz tanıma sırasında bir hata oluştu.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.faceRecognition,
        );
}

class ImageProcessingException extends AppException {
  ImageProcessingException({
    String message = 'Görüntü işleme sırasında bir hata oluştu.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.imageProcessing,
        );
}

class ModelLoadException extends AppException {
    ModelLoadException({
    String message = 'Yapay zeka modeli yüklenemedi.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.general, // Model yükleme genel bir hatadır
        );
}

class ModelNotLoadedException extends AppException {
    ModelNotLoadedException({
    String message = 'Yapay zeka modeli henüz yüklenmedi.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.general,
        );
}


// --- Ağ Hataları ---
class NetworkException extends AppException {
  NetworkException({
    String message = 'Ağ bağlantısı kurulamadı veya zaman aşımına uğradı.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.network,
        );
}

// --- Dosya Sistemi Hataları ---
class FileSystemException extends AppException {
  FileSystemException({
    String message = 'Dosya okuma/yazma sırasında bir hata oluştu.',
    String? devMessage,
  }) : super(
          message: message,
          developerMessage: devMessage,
          category: ErrorCategory.file,
        );
}
