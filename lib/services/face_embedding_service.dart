import 'dart:typed_data';

import 'package:akilli_kapi_guvenlik_sistemi/core/error_handler.dart';
import 'package:akilli_kapi_guvenlik_sistemi/core/exceptions.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Yüz görüntülerinden embedding vektörleri çıkaran servis.
class FaceEmbeddingService {
  // Singleton pattern
  FaceEmbeddingService._privateConstructor();
  static final FaceEmbeddingService instance =
      FaceEmbeddingService._privateConstructor();

  Interpreter? _interpreter;
  static const String _modelPath = 'assets/models/facenet.tflite';
  static const int _inputSize = 112;
  static const int _outputSize = 512;

  /// Modeli yükler ve servisi başlatır.
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      ErrorHandler.log('FaceNet modeli başarıyla yüklendi.',
          level: LogLevel.info);
    } catch (e, s) {
      ErrorHandler.log('TFLite modeli yüklenemedi: $_modelPath',
          error: e, stackTrace: s, category: ErrorCategory.model);
      throw ModelLoadException(
          message: 'FaceNet modeli yüklenirken bir hata oluştu.');
    }
  }

  /// Verilen bir görüntüden 512 boyutlu bir embedding vektörü çıkarır.
  Future<Float32List?> getEmbeddingsFromImage(img.Image image) async {
    if (_interpreter == null) {
      ErrorHandler.log('Interpreter başlatılmamış.',
          level: LogLevel.error, category: ErrorCategory.model);
      throw ModelNotLoadedException(
          message: 'Embedding servisi başlatılmamış.');
    }
    try {
      // Görüntüyü modelin istediği formata getir (112x112 RGB)
      final img.Image resizedImage =
          img.copyResize(image, width: _inputSize, height: _inputSize);
      final Float32List imageBuffer = _imageToFloat32List(resizedImage);

      // Giriş ve çıkış tensörlerini hazırla
      final input = imageBuffer.reshape([1, _inputSize, _inputSize, 3]);
      final output = List.filled(1 * _outputSize, 0.0)
          .reshape([1, _outputSize]);

      // Modeli çalıştır
      _interpreter!.run(input, output);

      return (output[0] as List<double>).toFloat32List();
    } catch (e, s) {
      ErrorHandler.log('Embedding oluşturma hatası',
          error: e, stackTrace: s, category: ErrorCategory.faceRecognition);
      return null;
    }
  }

  /// Bir `img.Image` nesnesini TFLite modelinin girdisi için Float32List'e dönüştürür.
  /// Piksel değerlerini normalize eder (0-255 aralığından -1 ile 1 aralığına).
  Float32List _imageToFloat32List(img.Image image) {
    var buffer = Float32List(_inputSize * _inputSize * 3);
    var bufferIndex = 0;
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        var pixel = image.getPixel(x, y);
        buffer[bufferIndex++] = (pixel.r - 127.5) / 127.5;
        buffer[bufferIndex++] = (pixel.g - 127.5) / 127.5;
        buffer[bufferIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }
    return buffer;
  }

  /// Servisi sonlandırır ve kaynakları serbest bırakır.
  void dispose() {
    _interpreter?.close();
  }
}

// Helper extension for Float32List conversion
extension on List<double> {
  Float32List toFloat32List() {
    return Float32List.fromList(this);
  }
}
