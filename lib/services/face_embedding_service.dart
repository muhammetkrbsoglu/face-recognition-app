import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../core/error_handler.dart';
import '../core/exceptions.dart' as app_exceptions;
import 'gpu_delegate_service.dart';

class FaceEmbeddingService {
  Interpreter? _interpreter;
  static const String _modelPath = 'assets/models/arcface_512d.tflite';
  static const String _modelName = 'ArcFace 512D';

  /// Model yükleme durumunu kontrol et
  bool get isModelLoaded => _interpreter != null;

  /// Model yükle
  Future<void> loadModel() async {
    try {
      ErrorHandler.info(
        'Model yükleniyor: $_modelName',
        category: ErrorCategory.model,
        tag: 'LOAD_START',
      );

      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: GpuDelegateService.getGpuOptions(),
      );

      ErrorHandler.info(
        'Model başarıyla yüklendi: $_modelName',
        category: ErrorCategory.model,
        tag: 'LOAD_SUCCESS',
        metadata: {
          'modelPath': _modelPath,
          'inputShape': _interpreter!.getInputTensor(0).shape,
          'outputShape': _interpreter!.getOutputTensor(0).shape,
        },
      );
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

  /// Embedding çıkar
  Future<List<double>> extractEmbedding(File imageFile) async {
    try {
      // Model yüklü mü kontrol et
      if (!isModelLoaded) {
        throw app_exceptions.FaceRecognitionException.modelNotLoaded();
      }

      // Dosya varlığını kontrol et
      if (!await imageFile.exists()) {
        throw app_exceptions.FileSystemException.fileNotFound(imageFile.path);
      }

      ErrorHandler.debug(
        'Embedding çıkarma başladı',
        category: ErrorCategory.faceRecognition,
        tag: 'EXTRACT_START',
        metadata: {'imagePath': imageFile.path},
      );

      // Görüntü dosyasını oku
      final imageBytes = await imageFile.readAsBytes();
      
      // Görüntüyü decode et
      img.Image? oriImage = img.decodeImage(imageBytes);
      if (oriImage == null) {
        throw app_exceptions.FaceRecognitionException.embeddingExtractionFailed('Görüntü decode edilemedi');
      }

      // Görüntüyü model için yeniden boyutlandır (112x112)
      img.Image face = img.copyResize(oriImage, width: 112, height: 112);
      
      // Normalize [0,255] -> [-1,1]
      Float32List input = Float32List(112 * 112 * 3);
      int idx = 0;
      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          final pixel = face.getPixel(x, y);
          input[idx++] = ((pixel.r / 255.0) - 0.5) * 2.0;
          input[idx++] = ((pixel.g / 255.0) - 0.5) * 2.0;
          input[idx++] = ((pixel.b / 255.0) - 0.5) * 2.0;
        }
      }

      // Model giriş ve çıkış şekillerini kontrol et
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      
      // Tensörleri hazırla
      var inputTensor = input.reshape([1, 112, 112, 3]);
      var outputTensor = List.filled(512, 0.0).reshape([1, 512]);
      
      // Model çalıştır
      _interpreter!.run(inputTensor, outputTensor);
      
      // Embedding'i çıkar
      final embedding = List<double>.from(outputTensor[0]);
      
      ErrorHandler.debug(
        'Embedding başarıyla çıkarıldı',
        category: ErrorCategory.faceRecognition,
        tag: 'EXTRACT_SUCCESS',
        metadata: {
          'imagePath': imageFile.path,
          'embeddingLength': embedding.length,
          'embeddingPreview': embedding.sublist(0, 5).map((e) => e.toStringAsFixed(4)).join(', '),
          'inputShape': inputShape,
          'outputShape': outputShape,
        },
      );

      return embedding;
    } catch (e, stackTrace) {
      // AppException türündeki hataları yeniden fırlat
      if (e is app_exceptions.AppException) {
        rethrow;
      }
      
      // Bilinmeyen hataları wrap et
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

  /// Model'i temizle
  void dispose() {
    try {
      _interpreter?.close();
      _interpreter = null;
      
      ErrorHandler.debug(
        'Model kaynakları temizlendi',
        category: ErrorCategory.model,
        tag: 'DISPOSE',
      );
    } catch (e) {
      ErrorHandler.warning(
        'Model kaynakları temizlenirken hata',
        category: ErrorCategory.model,
        tag: 'DISPOSE_ERROR',
      );
    }
  }
}
