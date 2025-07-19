import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import '../core/error_handler.dart';

class FaceDetectionResult {
  final List<Face> faces;
  final bool hasQualityFace;
  final String message;
  final Rect? primaryFaceRect;
  final double confidence;

  FaceDetectionResult({
    required this.faces,
    required this.hasQualityFace,
    required this.message,
    this.primaryFaceRect,
    required this.confidence,
  });
}

class FaceQualityResult {
  final bool isQuality;
  final String message;
  final double confidence;

  FaceQualityResult({
    required this.isQuality,
    required this.message,
    required this.confidence,
  });
}

class RealTimeFaceDetectionService {
  static final RealTimeFaceDetectionService _instance = RealTimeFaceDetectionService._internal();
  factory RealTimeFaceDetectionService() => _instance;
  RealTimeFaceDetectionService._internal();

  FaceDetector? _faceDetector;
  bool _isProcessing = false;

  Future<void> initialize() async {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<FaceDetectionResult> detectFaces(CameraImage cameraImage, CameraController cameraController) async {
    if (_isProcessing || _faceDetector == null) {
      return FaceDetectionResult(faces: [], hasQualityFace: false, message: 'İşlem devam ediyor...', confidence: 0.0);
    }

    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(cameraImage, cameraController);
      if (inputImage == null) {
        return FaceDetectionResult(faces: [], hasQualityFace: false, message: 'Kamera görüntüsü işlenemedi', confidence: 0.0);
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceDetectionResult(faces: [], hasQualityFace: false, message: '🚫 Yüz bulunamadı. Kameraya bakın.', confidence: 0.0);
      }

      Face? primaryFace = faces.reduce((a, b) => a.boundingBox.width * a.boundingBox.height > b.boundingBox.width * b.boundingBox.height ? a : b);
      final qualityResult = _evaluateFaceQuality(primaryFace, cameraImage);

      return FaceDetectionResult(
        faces: faces,
        hasQualityFace: qualityResult.isQuality,
        message: qualityResult.message,
        primaryFaceRect: primaryFace.boundingBox,
        confidence: qualityResult.confidence,
      );
    } catch (e) {
      ErrorHandler.error('Face detection error', category: ErrorCategory.faceRecognition, tag: 'FACE_DETECTION_ERROR', error: e);
      return FaceDetectionResult(faces: [], hasQualityFace: false, message: 'Yüz tespiti hatası: $e', confidence: 0.0);
    } finally {
      _isProcessing = false;
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraController cameraController) {
    final camera = cameraController.description;
    final sensorOrientation = camera.sensorOrientation;
    final deviceOrientation = cameraController.value.deviceOrientation;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  FaceQualityResult _evaluateFaceQuality(Face face, CameraImage cameraImage) {
    List<String> issues = [];
    double totalScore = 0.0;
    int checks = 0;

    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final imageArea = cameraImage.width * cameraImage.height;
    final faceRatio = faceArea / imageArea;

    if (faceRatio < 0.05) {
      issues.add('📱 Telefonu yüzünüze yaklaştırın');
    } else if (faceRatio > 0.4) {
      issues.add('📱 Telefonu yüzünüzden uzaklaştırın');
    } else {
      totalScore += 25.0;
    }
    checks++;

    final rotY = face.headEulerAngleY ?? 0.0;
    final rotZ = face.headEulerAngleZ ?? 0.0;
    if (rotY.abs() > 15 || rotZ.abs() > 15) {
      issues.add('👤 Yüzünüzü kameraya doğru çevirin');
    } else {
      totalScore += 25.0;
    }
    checks++;

    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.5;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.5;
    if (leftEyeOpen < 0.4 || rightEyeOpen < 0.4) {
      issues.add('👁️ Gözlerinizi açın');
    } else {
      totalScore += 25.0;
    }
    checks++;

    totalScore += 25; // Placeholder for other checks
    checks++;

    final finalScore = totalScore / checks;
    final isQuality = finalScore >= 60.0;

    String message;
    if (isQuality) {
      message = '✅ Mükemmel kalite!';
    } else {
      message = issues.isNotEmpty ? '❌ ${issues.join(', ')}' : '⚠️ Kalite düşük';
    }

    return FaceQualityResult(isQuality: isQuality, message: message, confidence: finalScore);
  }

  Color getFaceFrameColor(double confidence) {
    if (confidence >= 75.0) return Colors.green;
    if (confidence >= 50.0) return Colors.yellow;
    return Colors.red;
  }

  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
  }
}
