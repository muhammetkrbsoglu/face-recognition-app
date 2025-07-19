import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../core/error_handler.dart';
import '../core/exceptions.dart' as app_exceptions;
import 'gpu_delegate_service.dart';
import 'dart:math';

/// TFLite modelini yöneten ve yüz embedding'i çıkaran merkezi servis.
/// Bu servis, FaceRecognitionService ve FaceEmbeddingService'in birleştirilmiş ve iyileştirilmiş halidir.
class FaceEmbeddingService {
  static final FaceEmbeddingService _instance = FaceEmbeddingService._internal();
  factory FaceEmbeddingService() => _instance;
  FaceEmbeddingService._internal();

  Interpreter? _interpreter;
  static const String _modelPath = 'assets/models/arcface_512d.tflite';
  static const String _modelName = 'ArcFace 512D';

  /// Modelin yüklenip yüklenmediğini kontrol eder.
  bool get isModelLoaded => _interpreter != null;

  /// Geliştirme modunda detaylı loglama yapar.
  void _debugLog(String message) {
    // Sadece debug modunda konsola log basar.
    if (kDebugMode) {
      final timestamp = DateTime.now().toString().substring(11, 23);
      debugPrint('[$timestamp] [FaceEmbeddingService] $message');
    }
  }

  /// TFLite modelini hafızaya yükler.
  Future<void> loadModel() async {
    if (isModelLoaded) {
      _debugLog('Model zaten yüklü, tekrar yükleme atlanıyor.');
      return;
    }
    try {
      _debugLog('Model yükleme başlıyor: $_modelName');
      // GPU delegate ile modeli yükleyerek performansı artırır.
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: GpuDelegateService.getGpuOptions(),
      );
      _debugLog('Model başarıyla yüklendi: $_modelName');
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'Model yükleme başarısız: $_modelName',
        category: ErrorCategory.model,
        tag: 'LOAD_FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      throw app_exceptions.ModelException.loadFailed(_modelName, e.toString());
    }
  }
  
  /// Verilen bir embedding vektörünü L2 normuna göre normalize eder.
  /// Bu, kosinüs benzerliği hesaplamalarında doğruluğu artırır.
  List<double> _normalize(List<double> embedding) {
    final double norm = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    if (norm == 0) return embedding; // Sıfıra bölme hatasını önle
    return embedding.map((e) => e / norm).toList();
  }

  /// Bir görüntü dosyasından 512 boyutlu yüz embedding'i çıkarır.
  Future<List<double>> extractEmbedding(File imageFile) async {
    if (!isModelLoaded) {
      throw app_exceptions.FaceRecognitionException.modelNotLoaded();
    }
    if (!await imageFile.exists()) {
      throw app_exceptions.FileSystemException.fileNotFound(imageFile.path);
    }

    try {
      _debugLog('Embedding çıkarma başladı: ${imageFile.path}');
      
      // Görüntüyü oku ve işle
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw app_exceptions.FaceRecognitionException.embeddingExtractionFailed('Görüntü çözümlenemedi.');
      }
      // Modeli giriş boyutuna (112x112) yeniden boyutlandır.
      img.Image resizedImage = img.copyResize(originalImage, width: 112, height: 112);

      // Görüntüyü tensöre dönüştür (normalizasyon: [-1, 1])
      Float32List imageAsFloat32List = Float32List(1 * 112 * 112 * 3);
      int pixelIndex = 0;
      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          final pixel = resizedImage.getPixel(x, y);
          imageAsFloat32List[pixelIndex++] = (pixel.r - 127.5) / 127.5;
          imageAsFloat32List[pixelIndex++] = (pixel.g - 127.5) / 127.5;
          imageAsFloat32List[pixelIndex++] = (pixel.b - 127.5) / 127.5;
        }
      }
      
      final input = imageAsFloat32List.reshape([1, 112, 112, 3]);
      final output = List.filled(1 * 512, 0.0).reshape([1, 512]);

      // Modeli çalıştır
      _interpreter!.run(input, output);
      
      // Çıktıyı normalize et ve döndür
      final embedding = _normalize(List<double>.from(output[0]));
      _debugLog('Embedding başarıyla çıkarıldı. Uzunluk: ${embedding.length}');
      
      return embedding;

    } catch (e, stackTrace) {
      // Bilinen bir hata ise tekrar fırlat
      if (e is app_exceptions.AppException) rethrow;
      
      // Bilinmeyen hataları logla ve özel bir istisna ile sarmala
      ErrorHandler.error(
        'Embedding çıkarma sırasında beklenmeyen hata',
        category: ErrorCategory.faceRecognition,
        tag: 'EXTRACT_FAILED',
        error: e,
        stackTrace: stackTrace,
        metadata: {'imagePath': imageFile.path},
      );
      throw app_exceptions.FaceRecognitionException.embeddingExtractionFailed(e.toString());
    }
  }

  /// Servis kaynaklarını (TFLite interpreter) temizler.
  void dispose() {
    if(isModelLoaded) {
      _interpreter?.close();
      _interpreter = null;
      _debugLog('Servis kaynakları temizlendi.');
    }
  }
}
