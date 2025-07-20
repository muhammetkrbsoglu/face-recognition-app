import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Hata için eklendi: DeviceOrientation
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/error_handler.dart';

/// Gerçek zamanlı yüz tespiti ve kalite analizi yapan servis.
class RealTimeFaceDetectionService {
  // Servis artık CameraController'ı kendi içinde yönetmiyor, dışarıdan alıyor.
  CameraController? _cameraController;
  late final FaceDetector _faceDetector;
  final StreamController<FaceDetectionResult> _detectionStreamController =
      StreamController<FaceDetectionResult>.broadcast();

  bool _isDetecting = false;

  /// Yüz tespit sonuçlarını dinlemek için kullanılan stream.
  Stream<FaceDetectionResult> get detectionStream =>
      _detectionStreamController.stream;

  /// Servisi başlatır, kamera ve yüz dedektörünü hazırlar.
  Future<void> initialize(CameraController controller) async {
    _cameraController = controller;
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: true,
      enableClassification: true,
    );
    _faceDetector = FaceDetector(options: options);
    log('RealTimeFaceDetectionService başlatıldı.', name: 'FaceDetectionService');
  }

  /// Gelen kamera görüntüsünü işler.
  Future<void> processImage(CameraImage image, CameraDescription camera) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isDetecting) return;

    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image, camera);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      log('Tespit edilen yüz sayısı: ${faces.length}', name: 'FaceDetectionService');

      if (faces.isEmpty) {
        _detectionStreamController.add(FaceDetectionResult(
          faces: [],
          message: "Kameraya bakın ve yüzünüzü ortalayın",
          confidence: 0,
          qualityMet: false,
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        ));
      } else {
        final Face firstFace = faces.first;
        final result = _analyzeFace(firstFace, image.width, image.height);
        _detectionStreamController.add(result);
      }
    } catch (e, s) {
      // Hata düzeltmesi: logError -> log
      ErrorHandler.log(
        'Görüntü işleme sırasında kritik hata oluştu.',
        error: e,
        stackTrace: s,
        level: LogLevel.error,
        category: 'FaceDetection',
      );
      _detectionStreamController.add(FaceDetectionResult(
        faces: [],
        message: "Hata: Görüntü işlenemedi.",
        confidence: 0,
        qualityMet: false,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      ));
    } finally {
      await Future.delayed(const Duration(milliseconds: 60));
      _isDetecting = false;
    }
  }

  /// Tespit edilen yüzü kalite kriterlerine göre analiz eder.
  FaceDetectionResult _analyzeFace(Face face, int imageWidth, int imageHeight) {
    double confidence = 1.0;
    String message = "Yüz kalitesi mükemmel!";
    bool qualityMet = true;

    final faceWidth = face.boundingBox.width;
    final minFaceWidth = imageWidth * 0.3;
    if (faceWidth < minFaceWidth) {
      confidence -= 0.3;
      message = "Lütfen biraz daha yaklaşın";
      qualityMet = false;
    }

    final faceCenterX = face.boundingBox.center.dx;
    final imageCenterX = imageWidth / 2;
    final deviation = (faceCenterX - imageCenterX).abs();
    if (deviation > imageWidth * 0.2) {
      confidence -= 0.2;
      message = "Yüzünüzü çerçevenin ortasına getirin";
      qualityMet = false;
    }

    if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 15) {
      confidence -= 0.3;
      message = "Lütfen kameraya düz bakın";
      qualityMet = false;
    }
    if (face.headEulerAngleZ != null && face.headEulerAngleZ!.abs() > 15) {
      confidence -= 0.3;
      message = "Lütfen başınızı dik tutun";
      qualityMet = false;
    }

    if ((face.leftEyeOpenProbability ?? 1.0) < 0.5 || (face.rightEyeOpenProbability ?? 1.0) < 0.5) {
      confidence -= 0.2;
      message = "Lütfen gözlerinizi açın";
      qualityMet = false;
    }

    return FaceDetectionResult(
      faces: [face],
      message: message,
      confidence: confidence.clamp(0.0, 1.0),
      qualityMet: qualityMet,
      imageSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
    );
  }

  /// `CameraImage`'i `InputImage`'e dönüştürür.
  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    try {
      // Hata düzeltmesi: InputImageFormatValue.fromRaw -> switch case
      final InputImageFormat? format = InputImageFormat.values.firstWhere(
        (element) => element.raw == image.format.raw,
        orElse: () => null,
      );

      if (format == null) {
        log('HATA: Desteklenmeyen görüntü formatı: ${image.format.group}', name: 'FaceDetectionService');
        return null;
      }

      final imageRotation = _getRotation(
          camera.sensorOrientation, _cameraController!.value.deviceOrientation);

      if (image.planes.isEmpty || image.planes[0].bytesPerRow == 0) {
        log('HATA: Geçersiz görüntü düzlemi (plane) verisi.', name: 'FaceDetectionService');
        return null;
      }

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } catch (e, s) {
      ErrorHandler.log(
        'InputImage oluşturulurken hata oluştu.',
        error: e,
        stackTrace: s,
        level: LogLevel.error,
        category: 'FaceDetection',
      );
      return null;
    }
  }

  /// Cihaz ve kamera sensör yönelimlerine göre doğru görüntü rotasyonunu hesaplar.
  InputImageRotation _getRotation(
      int sensorOrientation, DeviceOrientation deviceOrientation) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    } else if (Platform.isAndroid) {
      final Map<DeviceOrientation, int> orientationMap = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };
      final deviceOrientationAngle = orientationMap[deviceOrientation] ?? 0;
      final cameraLensDirection = _cameraController!.description.lensDirection;

      var rotation = (sensorOrientation - deviceOrientationAngle + 360) % 360;
      if (cameraLensDirection == CameraLensDirection.front) {
         rotation = (360 - rotation) % 360;
      }
      return InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg;
    }
    return InputImageRotation.rotation0deg;
  }

  /// Servisi sonlandırır ve kaynakları serbest bırakır.
  void dispose() {
    _faceDetector.close();
    _detectionStreamController.close();
    log('RealTimeFaceDetectionService sonlandırıldı.', name: 'FaceDetectionService');
  }
}

/// Yüz tespiti sonuçlarını ve kalite metriklerini içeren model sınıfı.
class FaceDetectionResult {
  final List<Face> faces;
  final String message;
  final double confidence;
  final bool qualityMet;
  final Size imageSize; // Hata için eklendi

  FaceDetectionResult({
    required this.faces,
    required this.message,
    required this.confidence,
    required this.imageSize,
    this.qualityMet = true,
  });
}
