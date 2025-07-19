import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';
import '../core/error_handler.dart';

/// Yüz tespiti sonucu
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

/// Yüz kalitesi değerlendirme sonucu
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

/// Gerçek zamanlı yüz tespiti servisi
class RealTimeFaceDetectionService {
  static final RealTimeFaceDetectionService _instance = RealTimeFaceDetectionService._internal();
  factory RealTimeFaceDetectionService() => _instance;
  RealTimeFaceDetectionService._internal();

  FaceDetector? _faceDetector;
  bool _isProcessing = false;

  /// Face detector'ı başlat
  Future<void> initialize() async {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.1, // Minimum yüz boyutu
      performanceMode: FaceDetectorMode.fast, // Hızlı mode
    );
    
    _faceDetector = FaceDetector(options: options);
  }

  /// CameraImage'dan InputImage'a dönüştürme
  InputImage? _cameraImageToInputImage(CameraImage cameraImage) {
    try {
      // Kamera formatını kontrol et
      final inputImageRotation = _getImageRotation(cameraImage);
      final inputImageFormat = _getInputImageFormat(cameraImage.format);

      if (inputImageFormat == null) {
        ErrorHandler.warning(
          'Unsupported camera format',
          category: ErrorCategory.camera,
          tag: 'UNSUPPORTED_CAMERA_FORMAT',
          metadata: {'format': cameraImage.format.group.toString()},
        );
        return null;
      }

      // Plane'leri kontrol et
      if (cameraImage.planes.isEmpty) {
        ErrorHandler.warning(
          'Empty camera planes',
          category: ErrorCategory.camera,
          tag: 'EMPTY_CAMERA_PLANES',
        );
        return null;
      }

      // Metadata oluştur
      final inputImageMetadata = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: inputImageRotation,
        format: inputImageFormat,
        bytesPerRow: cameraImage.planes.first.bytesPerRow,
      );

      // InputImage oluştur
      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(cameraImage.planes),
        metadata: inputImageMetadata,
      );

      return inputImage;
    } catch (e) {
      ErrorHandler.error(
        'CameraImage to InputImage conversion error',
        category: ErrorCategory.camera,
        tag: 'IMAGE_CONVERSION_ERROR',
        error: e,
      );
      return null;
    }
  }

  /// Image rotation hesaplama
  InputImageRotation _getImageRotation(CameraImage cameraImage) {
    // Kamera yönelimini belirle
    // Front camera için genellikle 270 derece rotasyon gerekir
    // Cihaz orientation'ını da dikkate almak gerekir
    
    // Şimdilik basit yaklaşım: front camera için 270 derece
    // Gerçek implementasyonda device orientation da dikkate alınmalı
    return InputImageRotation.rotation270deg;
  }

  /// Input image format belirleme
  InputImageFormat? _getInputImageFormat(ImageFormat format) {
    try {
      switch (format.group) {
        case ImageFormatGroup.yuv420:
          return InputImageFormat.yuv420;
        case ImageFormatGroup.bgra8888:
          return InputImageFormat.bgra8888;
        case ImageFormatGroup.nv21:
          return InputImageFormat.nv21;
        default:
          ErrorHandler.warning(
            'Unsupported image format: ${format.group}',
            category: ErrorCategory.camera,
            tag: 'UNSUPPORTED_FORMAT',
            metadata: {'format': format.group.toString()},
          );
          return InputImageFormat.yuv420; // Varsayılan olarak YUV420 döndür
      }
    } catch (e) {
      ErrorHandler.error(
        'Image format detection error',
        category: ErrorCategory.camera,
        tag: 'FORMAT_DETECTION_ERROR',
        error: e,
      );
      return InputImageFormat.yuv420; // Fallback
    }
  }

  /// Kamera plane'lerini birleştir
  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  /// Gerçek zamanlı yüz tespiti
  Future<FaceDetectionResult> detectFaces(CameraImage cameraImage) async {
    if (_isProcessing || _faceDetector == null) {
      return FaceDetectionResult(
        faces: [],
        hasQualityFace: false,
        message: 'İşlem devam ediyor...',
        confidence: 0.0,
      );
    }

    _isProcessing = true;

    try {
      final inputImage = _cameraImageToInputImage(cameraImage);
      if (inputImage == null) {
        return FaceDetectionResult(
          faces: [],
          hasQualityFace: false,
          message: 'Kamera görüntüsü işlenemedi',
          confidence: 0.0,
        );
      }

      final faces = await _faceDetector!.processImage(inputImage);
      
      if (faces.isEmpty) {
        return FaceDetectionResult(
          faces: [],
          hasQualityFace: false,
          message: '🚫 Yüz bulunamadı. Kameraya bakın.',
          confidence: 0.0,
        );
      }

      // En büyük yüzü bul (ana yüz)
      Face? primaryFace = faces.reduce((a, b) => 
        a.boundingBox.width * a.boundingBox.height > 
        b.boundingBox.width * b.boundingBox.height ? a : b);

      // Yüz kalitesini değerlendir
      final qualityResult = _evaluateFaceQuality(primaryFace, cameraImage);
      
      return FaceDetectionResult(
        faces: faces,
        hasQualityFace: qualityResult.isQuality,
        message: qualityResult.message,
        primaryFaceRect: primaryFace.boundingBox,
        confidence: qualityResult.confidence,
      );

    } catch (e) {
      ErrorHandler.error(
        'Face detection error',
        category: ErrorCategory.faceRecognition,
        tag: 'FACE_DETECTION_ERROR',
        error: e,
      );
      return FaceDetectionResult(
        faces: [],
        hasQualityFace: false,
        message: 'Yüz tespiti hatası: $e',
        confidence: 0.0,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Yüz kalitesini değerlendir
  FaceQualityResult _evaluateFaceQuality(Face face, CameraImage cameraImage) {
    List<String> issues = [];
    double totalScore = 0.0;
    int checks = 0;

    // 1. Yüz boyutu kontrolü
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final imageArea = cameraImage.width * cameraImage.height;
    final faceRatio = faceArea / imageArea;

    if (faceRatio < 0.02) {
      issues.add('📱 Telefonu yüzünüze yaklaştırın');
    } else if (faceRatio > 0.4) {
      issues.add('📱 Telefonu yüzünüzden uzaklaştırın');
    } else {
      totalScore += 25.0;
    }
    checks++;

    // 2. Yüz yönelimi kontrolü
    final rotX = face.headEulerAngleX ?? 0.0;
    final rotY = face.headEulerAngleY ?? 0.0;
    final rotZ = face.headEulerAngleZ ?? 0.0;

    if (rotX.abs() > 15 || rotY.abs() > 15 || rotZ.abs() > 15) {
      issues.add('👤 Yüzünüzü kameraya doğru çevirin');
    } else {
      totalScore += 25.0;
    }
    checks++;

    // 3. Yüz merkezi kontrolü
    final centerX = face.boundingBox.left + face.boundingBox.width / 2;
    final centerY = face.boundingBox.top + face.boundingBox.height / 2;
    final imageCenterX = cameraImage.width / 2;
    final imageCenterY = cameraImage.height / 2;

    final deltaX = (centerX - imageCenterX).abs() / imageCenterX;
    final deltaY = (centerY - imageCenterY).abs() / imageCenterY;

    if (deltaX > 0.3 || deltaY > 0.3) {
      issues.add('🎯 Yüzünüzü merkeze hizalayın');
    } else {
      totalScore += 25.0;
    }
    checks++;

    // 4. Gözlerin açık olma kontrolü
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.5;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.5;

    if (leftEyeOpen < 0.3 || rightEyeOpen < 0.3) {
      issues.add('👁️ Gözlerinizi açın');
    } else {
      totalScore += 25.0;
    }
    checks++;

    // Toplam skor hesaplama
    final finalScore = totalScore / checks;
    final isQuality = finalScore >= 60.0;

    // Mesaj oluşturma
    String message;
    if (isQuality) {
      if (finalScore >= 90.0) {
        message = '✅ Mükemmel kalite!';
      } else if (finalScore >= 75.0) {
        message = '👍 İyi kalite';
      } else {
        message = '📸 Kabul edilebilir kalite';
      }
    } else {
      if (issues.isEmpty) {
        message = '⚠️ Kalite düşük';
      } else {
        message = '❌ ${issues.join(', ')}';
      }
    }

    return FaceQualityResult(
      isQuality: isQuality,
      message: message,
      confidence: finalScore,
    );
  }

  /// Yüz çerçevesi için renk belirle
  Color getFaceFrameColor(double confidence) {
    if (confidence >= 90.0) return const Color(0xFF4CAF50); // Yeşil
    if (confidence >= 70.0) return const Color(0xFF8BC34A); // Açık yeşil
    if (confidence >= 50.0) return const Color(0xFFFF9800); // Turuncu
    if (confidence >= 30.0) return const Color(0xFFFF5722); // Koyu turuncu
    return const Color(0xFFF44336); // Kırmızı
  }

  /// Servisi kapat
  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
  }
} 