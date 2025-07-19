import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import '../models/face_model.dart';
import 'dart:math';
import '../core/error_handler.dart';
import 'face_match_service.dart';

/// Multi-face detection sonucu
class MultiFaceResult {
  final List<Face> allFaces;
  final Face? primaryFace;
  final List<Face> qualityFaces;
  final String message;
  final Map<String, dynamic> metrics;
  final List<FaceMatch> matches;

  MultiFaceResult({
    required this.allFaces,
    this.primaryFace,
    required this.qualityFaces,
    required this.message,
    required this.metrics,
    required this.matches,
  });
}

/// Yüz eşleşme sonucu
class FaceMatch {
  final Face detectedFace;
  final FaceModel? matchedModel;
  final double similarity;
  final String confidence;

  FaceMatch({
    required this.detectedFace,
    this.matchedModel,
    required this.similarity,
    required this.confidence,
  });
}

/// Multi-face handling servisi
class MultiFaceHandler {
  static final MultiFaceHandler _instance = MultiFaceHandler._internal();
  factory MultiFaceHandler() => _instance;
  MultiFaceHandler._internal();

  /// Multi-face detection ve matching
  Future<MultiFaceResult> processMultipleFaces(
    List<Face> faces,
    List<FaceModel> registeredFaces,
  ) async {
    if (faces.isEmpty) {
      return MultiFaceResult(
        allFaces: [],
        message: '🚫 No faces detected',
        metrics: {},
        qualityFaces: [],
        matches: [],
      );
    }

    // 1. Yüz kalitesi değerlendirme
    final qualityFaces = _filterQualityFaces(faces);
    
    // 2. Ana yüz seçimi
    final primaryFace = _selectPrimaryFace(qualityFaces);
    
    // 3. Tüm yüzleri eşleştir
    final matches = await _matchAllFaces(qualityFaces, registeredFaces);
    
    // 4. Metrikleri hesapla
    final metrics = _calculateMetrics(faces, qualityFaces, matches);
    
    // 5. Mesaj oluştur
    final message = _generateMessage(faces, qualityFaces, matches);

    return MultiFaceResult(
      allFaces: faces,
      primaryFace: primaryFace,
      qualityFaces: qualityFaces,
      message: message,
      metrics: metrics,
      matches: matches,
    );
  }

  /// Kaliteli yüzleri filtrele
  List<Face> _filterQualityFaces(List<Face> faces) {
    return faces.where((face) {
      // Minimum boyut kontrolü
      final area = face.boundingBox.width * face.boundingBox.height;
      if (area < 5000) return false;
      
      // Yüz yönelimi kontrolü
      final rotX = face.headEulerAngleX?.abs() ?? 0.0;
      final rotY = face.headEulerAngleY?.abs() ?? 0.0;
      final rotZ = face.headEulerAngleZ?.abs() ?? 0.0;
      
      if (rotX > 20 || rotY > 20 || rotZ > 20) return false;
      
      // Göz açıklığı kontrolü
      final leftEye = face.leftEyeOpenProbability ?? 0.5;
      final rightEye = face.rightEyeOpenProbability ?? 0.5;
      
      if (leftEye < 0.3 || rightEye < 0.3) return false;
      
      return true;
    }).toList();
  }

  /// Ana yüz seçimi (en büyük ve merkeze en yakın)
  Face? _selectPrimaryFace(List<Face> faces) {
    if (faces.isEmpty) return null;
    
    // Yüz skorlarını hesapla
    final scoredFaces = faces.map((face) {
      final area = face.boundingBox.width * face.boundingBox.height;
      final centerX = face.boundingBox.left + face.boundingBox.width / 2;
      final centerY = face.boundingBox.top + face.boundingBox.height / 2;
      
      // Merkeze uzaklık (normalize edilmiş)
      final distanceFromCenter = sqrt(
        pow(centerX - 200, 2) + pow(centerY - 200, 2)
      );
      
      // Boyut skoru (0-100)
      final sizeScore = min(100, area / 100);
      
      // Merkez skoru (0-100)
      final centerScore = max(0, 100 - distanceFromCenter / 5);
      
      // Toplam skor
      final totalScore = sizeScore * 0.6 + centerScore * 0.4;
      
      return MapEntry(face, totalScore);
    }).toList();
    
    // En yüksek skoru seç
    scoredFaces.sort((a, b) => b.value.compareTo(a.value));
    return scoredFaces.first.key;
  }

  /// Tüm yüzleri eşleştir
  Future<List<FaceMatch>> _matchAllFaces(
    List<Face> faces,
    List<FaceModel> registeredFaces,
  ) async {
    final matches = <FaceMatch>[];
    
    for (final face in faces) {
      try {
        // Bu yüz için embedding çıkart (simülasyon)
        final match = await _matchSingleFace(face, registeredFaces);
        matches.add(match);
      } catch (e) {
        ErrorHandler.error(
          'Face matching error',
          category: ErrorCategory.faceRecognition,
          tag: 'FACE_MATCHING_ERROR',
          error: e,
        );
        matches.add(FaceMatch(
          detectedFace: face,
          similarity: 0.0,
          confidence: 'Error',
        ));
      }
    }
    
    return matches;
  }

  /// Tek yüz eşleştirme
  Future<FaceMatch> _matchSingleFace(
    Face face,
    List<FaceModel> registeredFaces,
  ) async {
    if (registeredFaces.isEmpty) {
      return FaceMatch(
        detectedFace: face,
        similarity: 0.0,
        confidence: 'No registered faces',
      );
    }

    try {
      // Gerçek embedding karşılaştırması
      double bestSimilarity = 0.0;
      FaceModel? bestMatch;
      
      for (final registeredFace in registeredFaces) {
        if (registeredFace.embedding != null && registeredFace.embedding!.isNotEmpty) {
          // Cosine similarity hesapla
          final similarity = FaceMatchService.cosineSimilarity(
            face.embedding ?? [],
            registeredFace.embedding!,
          );
          
          if (similarity > bestSimilarity) {
            bestSimilarity = similarity;
            bestMatch = registeredFace;
          }
        }
      }
      
      // Eşik değerlerine göre confidence belirle
      if (bestSimilarity > 0.7 && bestMatch != null) {
        return FaceMatch(
          detectedFace: face,
          matchedModel: bestMatch,
          similarity: bestSimilarity,
          confidence: 'High',
        );
      } else if (bestSimilarity > 0.4) {
        return FaceMatch(
          detectedFace: face,
          similarity: bestSimilarity,
          confidence: 'Medium',
        );
      } else {
        return FaceMatch(
          detectedFace: face,
          similarity: bestSimilarity,
          confidence: 'Low',
        );
      }
    } catch (e) {
      ErrorHandler.error(
        'Face matching error',
        category: ErrorCategory.faceRecognition,
        tag: 'FACE_MATCHING_ERROR',
        error: e,
      );
      return FaceMatch(
        detectedFace: face,
        similarity: 0.0,
        confidence: 'Error',
      );
    }
  }

  /// Metrikleri hesapla
  Map<String, dynamic> _calculateMetrics(
    List<Face> allFaces,
    List<Face> qualityFaces,
    List<FaceMatch> matches,
  ) {
    final highConfidenceMatches = matches.where((m) => m.confidence == 'High').length;
    final mediumConfidenceMatches = matches.where((m) => m.confidence == 'Medium').length;
    
    return {
      'totalFaces': allFaces.length,
      'qualityFaces': qualityFaces.length,
      'highConfidenceMatches': highConfidenceMatches,
      'mediumConfidenceMatches': mediumConfidenceMatches,
      'qualityRatio': allFaces.isNotEmpty ? qualityFaces.length / allFaces.length : 0.0,
      'matchSuccessRate': matches.isNotEmpty ? highConfidenceMatches / matches.length : 0.0,
    };
  }

  /// Mesaj oluştur
  String _generateMessage(
    List<Face> allFaces,
    List<Face> qualityFaces,
    List<FaceMatch> matches,
  ) {
    final totalFaces = allFaces.length;
    final qualityCount = qualityFaces.length;
    final highConfidenceMatches = matches.where((m) => m.confidence == 'High').length;
    
    if (totalFaces == 0) {
      return '🚫 No faces detected';
    } else if (totalFaces == 1) {
      if (qualityCount == 1) {
        return highConfidenceMatches > 0 
          ? '✅ Single face detected and matched'
          : '👤 Single face detected';
      } else {
        return '⚠️ Single face detected but quality is poor';
      }
    } else {
      if (qualityCount == 0) {
        return '❌ Multiple faces detected but none meet quality standards';
      } else if (qualityCount == 1) {
        return highConfidenceMatches > 0 
          ? '✅ Multiple faces detected, one quality face matched'
          : '👤 Multiple faces detected, one quality face found';
      } else {
        return highConfidenceMatches > 0 
          ? '✅ Multiple quality faces detected, $highConfidenceMatches matched'
          : '👥 Multiple quality faces detected';
      }
    }
  }
}

/// Multi-face overlay painter
class MultiFacePainter extends CustomPainter {
  final MultiFaceResult result;
  final Size imageSize;
  final bool showAllFaces;
  final bool showQualityOnly;

  MultiFacePainter({
    required this.result,
    required this.imageSize,
    this.showAllFaces = true,
    this.showQualityOnly = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final faces = showQualityOnly ? result.qualityFaces : result.allFaces;
    
    for (int i = 0; i < faces.length; i++) {
      final face = faces[i];
      final isPrimary = face == result.primaryFace;
      final isQuality = result.qualityFaces.contains(face);
      
      _drawFaceBox(canvas, face, size, i, isPrimary, isQuality);
    }
  }

  void _drawFaceBox(
    Canvas canvas, 
    Face face, 
    Size size, 
    int index, 
    bool isPrimary, 
    bool isQuality,
  ) {
    final rect = _scaleRect(face.boundingBox, size);
    
    // Renk seçimi
    Color color;
    double strokeWidth;
    
    if (isPrimary) {
      color = Colors.green;
      strokeWidth = 3.0;
    } else if (isQuality) {
      color = Colors.blue;
      strokeWidth = 2.0;
    } else {
      color = Colors.red;
      strokeWidth = 1.5;
    }
    
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    // Yüz kutusu çiz
    canvas.drawRect(rect, paint);
    
    // Etiket çiz
    _drawLabel(canvas, rect, index, isPrimary, isQuality, color);
  }

  void _drawLabel(
    Canvas canvas, 
    Rect rect, 
    int index, 
    bool isPrimary, 
    bool isQuality, 
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: isPrimary ? 'Primary' : 'Face $index',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    final textOffset = Offset(
      rect.left,
      rect.top - textPainter.height - 5,
    );
    
    // Arka plan
    final backgroundRect = Rect.fromLTWH(
      textOffset.dx - 2,
      textOffset.dy - 2,
      textPainter.width + 4,
      textPainter.height + 4,
    );
    
    canvas.drawRect(
      backgroundRect,
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );
    
    textPainter.paint(canvas, textOffset);
  }

  Rect _scaleRect(Rect rect, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    
    return Rect.fromLTWH(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 