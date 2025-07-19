import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

import '../models/face_model.dart';
import 'dart:math';
import '../core/error_handler.dart';
import 'face_match_service.dart';
import 'face_embedding_service.dart';

/// Birden fazla yüz tespiti sonucunu modelleyen sınıf.
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

/// Tek bir yüzün eşleşme sonucunu modelleyen sınıf.
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


/// Bir görüntüdeki birden fazla yüzü yöneten, analiz eden ve eşleştiren servis.
class MultiFaceHandler {
  static final MultiFaceHandler _instance = MultiFaceHandler._internal();
  factory MultiFaceHandler() => _instance;
  MultiFaceHandler._internal();

  /// Tespit edilen yüzleri işler, kalitelerini filtreler ve kayıtlı yüzlerle eşleştirir.
  Future<MultiFaceResult> processMultipleFaces(
    List<Face> faces,
    File imageFile,
    FaceEmbeddingService embeddingService,
    List<FaceModel> registeredFaces,
  ) async {
    if (faces.isEmpty) {
      return MultiFaceResult(
        allFaces: [],
        message: '🚫 Yüz tespit edilmedi',
        metrics: {},
        qualityFaces: [],
        matches: [],
      );
    }
    
    final qualityFaces = _filterQualityFaces(faces);
    final primaryFace = _selectPrimaryFace(qualityFaces);
    
    final matches = await _matchAllFaces(qualityFaces, imageFile, embeddingService, registeredFaces);
    
    final metrics = _calculateMetrics(faces, qualityFaces, matches);
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

  /// Düşük kaliteli yüzleri (çok küçük, yanlış açılı vb.) listeden çıkarır.
  List<Face> _filterQualityFaces(List<Face> faces) {
    return faces.where((face) {
      final area = face.boundingBox.width * face.boundingBox.height;
      if (area < 5000) return false;
      
      final rotX = face.headEulerAngleX?.abs() ?? 0.0;
      final rotY = face.headEulerAngleY?.abs() ?? 0.0;
      final rotZ = face.headEulerAngleZ?.abs() ?? 0.0;
      
      if (rotX > 20 || rotY > 20 || rotZ > 20) return false;
      
      final leftEye = face.leftEyeOpenProbability ?? 0.5;
      final rightEye = face.rightEyeOpenProbability ?? 0.5;
      
      if (leftEye < 0.3 || rightEye < 0.3) return false;
      
      return true;
    }).toList();
  }

  /// Görüntüdeki en merkezi ve en büyük yüzü "ana yüz" olarak seçer.
  Face? _selectPrimaryFace(List<Face> faces) {
    if (faces.isEmpty) return null;
    if (faces.length == 1) return faces.first;
    
    Face? bestFace;
    double maxScore = -1;

    for (final face in faces) {
      final area = face.boundingBox.width * face.boundingBox.height;
      // Basitçe en büyük alana sahip yüzü seçiyoruz.
      if (area > maxScore) {
        maxScore = area;
        bestFace = face;
      }
    }
    return bestFace;
  }

  /// Kaliteli yüzlerin her biri için eşleştirme işlemini başlatır.
  Future<List<FaceMatch>> _matchAllFaces(
    List<Face> faces,
    File imageFile,
    FaceEmbeddingService embeddingService,
    List<FaceModel> registeredFaces,
  ) async {
    final matches = <FaceMatch>[];
    if (registeredFaces.isEmpty) return matches;

    final imageBytes = await imageFile.readAsBytes();
    final fullImage = img.decodeImage(imageBytes);
    if (fullImage == null) return matches;
    
    for (final face in faces) {
      try {
        final match = await _matchSingleFace(face, fullImage, embeddingService, registeredFaces);
        matches.add(match);
      } catch (e) {
        ErrorHandler.error(
          'Tek bir yüz için eşleştirme hatası',
          category: ErrorCategory.faceRecognition,
          tag: 'SINGLE_FACE_MATCH_ERROR',
          error: e,
        );
        matches.add(FaceMatch(
          detectedFace: face,
          similarity: 0.0,
          confidence: 'Hata',
        ));
      }
    }
    
    return matches;
  }

  /// Tek bir yüzü görüntüden kırpar, embedding'ini çıkarır ve en iyi eşleşmeyi bulur.
  Future<FaceMatch> _matchSingleFace(
    Face face,
    img.Image fullImage,
    FaceEmbeddingService embeddingService,
    List<FaceModel> registeredFaces,
  ) async {
    // 1. Yüzü görüntüden kırp
    final x = face.boundingBox.left.toInt();
    final y = face.boundingBox.top.toInt();
    final w = face.boundingBox.width.toInt();
    final h = face.boundingBox.height.toInt();
    final croppedFaceImage = img.copyCrop(fullImage, x: x, y: y, width: w, height: h);

    // 2. Kırpılan yüzü geçici bir dosyaya yaz
    final tempDir = await Directory.systemTemp.createTemp();
    final tempFile = File('${tempDir.path}/temp_face.jpg');
    await tempFile.writeAsBytes(img.encodeJpg(croppedFaceImage));

    // 3. Kırpılan yüzden embedding çıkar (KRİTİK DÜZELTME)
    final detectedEmbedding = await embeddingService.extractEmbedding(tempFile);
    
    // 4. Geçici dosyayı temizle
    await tempFile.delete();
    await tempDir.delete();

    // 5. En iyi eşleşmeyi bul
    double bestSimilarity = 0.0;
    FaceModel? bestMatch;
    
    for (final registeredFace in registeredFaces) {
      if (registeredFace.embedding != null && registeredFace.embedding!.isNotEmpty) {
        final similarity = FaceMatchService.cosineSimilarity(
          detectedEmbedding,
          registeredFace.embedding!,
        );
        
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = registeredFace;
        }
      }
    }
    
    String confidence;
    if (bestSimilarity > 0.7) confidence = 'Yüksek';
    else if (bestSimilarity > 0.4) confidence = 'Orta';
    else confidence = 'Düşük';

    return FaceMatch(
      detectedFace: face,
      matchedModel: bestSimilarity > 0.7 ? bestMatch : null,
      similarity: bestSimilarity,
      confidence: confidence,
    );
  }

  /// İstatistiksel metrikleri hesaplar.
  Map<String, dynamic> _calculateMetrics(List<Face> allFaces, List<Face> qualityFaces, List<FaceMatch> matches) {
    final highConfidenceMatches = matches.where((m) => m.confidence == 'Yüksek').length;
    final mediumConfidenceMatches = matches.where((m) => m.confidence == 'Orta').length;
    
    return {
      'totalFaces': allFaces.length,
      'qualityFaces': qualityFaces.length,
      'highConfidenceMatches': highConfidenceMatches,
      'mediumConfidenceMatches': mediumConfidenceMatches,
      'qualityRatio': allFaces.isNotEmpty ? qualityFaces.length / allFaces.length : 0.0,
      'matchSuccessRate': matches.isNotEmpty ? highConfidenceMatches / matches.length : 0.0,
    };
  }

  /// Sonuçlara göre kullanıcıya gösterilecek bir mesaj oluşturur.
  String _generateMessage(List<Face> allFaces, List<Face> qualityFaces, List<FaceMatch> matches) {
    final totalFaces = allFaces.length;
    final qualityCount = qualityFaces.length;
    final highConfidenceMatches = matches.where((m) => m.confidence == 'Yüksek').length;
    
    if (totalFaces == 0) {
      return '🚫 Yüz tespit edilmedi';
    } else if (totalFaces == 1) {
      if (qualityCount == 1) {
        return highConfidenceMatches > 0 
          ? '✅ Tek yüz algılandı ve eşleştirildi'
          : '👤 Tek yüz algılandı';
      } else {
        return '⚠️ Tek yüz algılandı fakat kalitesi düşük';
      }
    } else {
      if (qualityCount == 0) {
        return '❌ Birden fazla yüz algılandı fakat hiçbiri kaliteli değil';
      } else if (qualityCount == 1) {
        return highConfidenceMatches > 0 
          ? '✅ Birden fazla yüz algılandı, bir tanesi eşleştirildi'
          : '👤 Birden fazla yüz algılandı, bir tanesi kaliteli';
      } else {
        return highConfidenceMatches > 0 
          ? '✅ Birden fazla kaliteli yüz algılandı, $highConfidenceMatches tanesi eşleştirildi'
          : '👥 Birden fazla kaliteli yüz algılandı';
      }
    }
  }
}

/// Algılanan yüzlerin üzerine çerçeve ve bilgi çizen CustomPainter sınıfı.
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
      ..color = color.withOpacity(0.8)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    canvas.drawRect(rect, paint);
    
    _drawLabel(canvas, rect, index, isPrimary, color);
  }

  void _drawLabel(
    Canvas canvas, 
    Rect rect, 
    int index, 
    bool isPrimary, 
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: isPrimary ? 'Ana Yüz' : 'Yüz ${index + 1}',
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
    
    final backgroundRect = Rect.fromLTWH(
      textOffset.dx - 2,
      textOffset.dy - 2,
      textPainter.width + 4,
      textPainter.height + 4,
    );
    
    canvas.drawRect(
      backgroundRect,
      Paint()..color = Colors.black.withOpacity(0.7),
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
