import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../core/error_handler.dart';
import '../core/exceptions.dart' as app_exceptions;
// import 'gpu_delegate_service.dart'; // GPU Delegate şimdilik kullanılmayacak.
import 'dart:math';

/// TFLite modelini yöneten ve yüz embedding'i çıkaran merkezi servis.
class FaceEmbeddingService {
  static final FaceEmbeddingService _instance = FaceEmbeddingService._internal();
  factory FaceEmbeddingService() => _instance;
  FaceEmbeddingService._internal();

  Interpreter? _interpreter;
  static const String _modelPath = 'assets/models/arcface_512d.tflite';
  static const String _modelName = 'ArcFace 512D';

  bool get isModelLoaded => _interpreter != null;

  void _debugLog(String message) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toString().substring(11, 23);
      debugPrint('[$timestamp] [FaceEmbeddingService] $message');
    }
  }

  /// Modeli yükler.
  Future<void> loadModel() async {
    if (isModelLoaded) {
      _debugLog('Model zaten yüklü, tekrar yükleme atlanıyor.');
      return;
    }
    try {
      _debugLog('Model yükleme başlıyor: $_modelName');

      // --- KRİTİK DÜZELTME: GPU DELEGATE DEVRE DIŞI BIRAKILDI ---
      // Sorunun GPU uyumluluğu olup olmadığını test etmek için
      // modeli sadece CPU üzerinde çalışacak şekilde yüklüyoruz.
      // Bu, en stabil ve en güvenilir yöntemdir.
      final options = InterpreterOptions();

      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: options, // GpuDelegateService.getGpuOptions() yerine boş options kullanılıyor.
      );

      _debugLog('Model başarıyla yüklendi (CPU üzerinde): $_modelName');
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
  
  List<double> _normalize(List<double> embedding) {
    final double norm = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    if (norm == 0) return embedding;
    return embedding.map((e) => e / norm).toList();
  }

  Future<List<double>> extractEmbedding(File imageFile) async {
    if (!isModelLoaded) {
      throw app_exceptions.FaceRecognitionException.modelNotLoaded();
    }
    if (!await imageFile.exists()) {
      throw app_exceptions.FileSystemException.fileNotFound(imageFile.path);
    }

    try {
      _debugLog('Embedding çıkarma başladı: ${imageFile.path}');
      
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw app_exceptions.FaceRecognitionException.embeddingExtractionFailed('Görüntü çözümlenemedi.');
      }
      img.Image resizedImage = img.copyResize(originalImage, width: 112, height: 112);

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

      _interpreter!.run(input, output);
      
      final embedding = _normalize(List<double>.from(output[0]));
      _debugLog('Embedding başarıyla çıkarıldı. Uzunluk: ${embedding.length}');
      
      return embedding;

    } catch (e, stackTrace) {
      if (e is app_exceptions.AppException) rethrow;
      
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

  void dispose() {
    if(isModelLoaded) {
      _interpreter?.close();
      _interpreter = null;
      _debugLog('Servis kaynakları temizlendi.');
    }
  }
}
