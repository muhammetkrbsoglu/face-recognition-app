import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; // Görüntü işleme için eklendi
import 'dart:io'; // Dosya işlemleri için eklendi

import '../models/face_model.dart';
import 'dart:math';
import '../core/error_handler.dart';
import 'face_match_service.dart';
import 'face_embedding_service.dart'; // Embedding servisi eklendi

/// Multi-face detection sonucu
class MultiFaceResult {
  // ... (Sınıf tanımı aynı)
}

/// Yüz eşleşme sonucu
class FaceMatch {
  // ... (Sınıf tanımı aynı)
}

/// Multi-face handling servisi
class MultiFaceHandler {
  static final MultiFaceHandler _instance = MultiFaceHandler._internal();
  factory MultiFaceHandler() => _instance;
  MultiFaceHandler._internal();

  /// Birden fazla yüzü işler, kalitelerini kontrol eder ve kayıtlı yüzlerle eşleştirir.
  Future<MultiFaceResult> processMultipleFaces(
    List<Face> faces,
    File imageFile, // Orijinal resim dosyası eklendi
    FaceEmbeddingService embeddingService, // Servis eklendi
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
    
    final qualityFaces = _filterQualityFaces(faces);
    final primaryFace = _selectPrimaryFace(qualityFaces);
    
    // DÜZELTİLDİ: Orijinal görüntü ve servis ile eşleştirme yapılıyor
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

  List<Face> _filterQualityFaces(List<Face> faces) {
    // ... (Bu metodun içeriği aynı kalabilir)
  }

  Face? _selectPrimaryFace(List<Face> faces) {
    // ... (Bu metodun içeriği aynı kalabilir)
  }

  /// Tüm kaliteli yüzleri, orijinal görüntüden kırpıp embedding'lerini çıkararak eşleştirir.
  Future<List<FaceMatch>> _matchAllFaces(
    List<Face> faces,
    File imageFile,
    FaceEmbeddingService embeddingService,
    List<FaceModel> registeredFaces,
  ) async {
    final matches = <FaceMatch>[];
    if (registeredFaces.isEmpty) return matches;

    // Orijinal görüntüyü bir kez yükle
    final imageBytes = await imageFile.readAsBytes();
    final fullImage = img.decodeImage(imageBytes);
    if (fullImage == null) return matches;
    
    for (final face in faces) {
      try {
        final match = await _matchSingleFace(face, fullImage, embeddingService, registeredFaces);
        matches.add(match);
      } catch (e) {
        ErrorHandler.error(
          'Face matching error for one face',
          category: ErrorCategory.faceRecognition,
          tag: 'SINGLE_FACE_MATCH_ERROR',
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

  /// Tek bir yüzü kırpar, embedding'ini çıkarır ve en iyi eşleşmeyi bulur.
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

    // 3. Embedding'i çıkar
    // HATA BURADAYDI: face.embedding yerine, kırpılan resimden embedding çıkarılıyor.
    final detectedEmbedding = await embeddingService.extractEmbedding(tempFile);
    
    // 4. Geçici dosyayı sil
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
    if (bestSimilarity > 0.7) confidence = 'High';
    else if (bestSimilarity > 0.4) confidence = 'Medium';
    else confidence = 'Low';

    return FaceMatch(
      detectedFace: face,
      matchedModel: bestSimilarity > 0.7 ? bestMatch : null,
      similarity: bestSimilarity,
      confidence: confidence,
    );
  }

  Map<String, dynamic> _calculateMetrics(List<Face> allFaces, List<Face> qualityFaces, List<FaceMatch> matches) {
    // ... (Bu metodun içeriği aynı kalabilir)
  }

  String _generateMessage(List<Face> allFaces, List<Face> qualityFaces, List<FaceMatch> matches) {
    // ... (Bu metodun içeriği aynı kalabilir)
  }
}

// MultiFacePainter sınıfı aynı kalabilir...
