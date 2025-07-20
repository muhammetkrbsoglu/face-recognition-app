import 'dart:math';
import 'dart:typed_data';

import 'package:akilli_kapi_guvenlik_sistemi/models/face_model.dart';

/// Yüz eşleştirme sonuçlarını tutan model.
class MatchResult {
  final FaceModel? bestMatch;
  final double confidence;

  MatchResult({this.bestMatch, required this.confidence});
}

/// Canlı yüz embedding'i ile veritabanındaki kayıtlı yüzleri karşılaştıran servis.
class FaceMatchService {
  /// Canlı embedding'i, kayıtlı yüzler listesindeki en iyi eşleşmeyle karşılaştırır.
  ///
  /// @param liveEmbeddings Anlık olarak kameradan alınan yüzün embedding vektörü.
  /// @param registeredFaces Veritabanından alınan kayıtlı yüzlerin listesi.
  /// @return En iyi eşleşmeyi ve benzerlik oranını içeren bir `MatchResult` nesnesi.
  MatchResult findBestMatch(
      Float32List liveEmbeddings, List<FaceModel> registeredFaces) {
    if (registeredFaces.isEmpty) {
      return MatchResult(confidence: 0);
    }

    double maxConfidence = 0.0;
    FaceModel? bestMatch;

    for (var face in registeredFaces) {
      final double confidence =
          _cosineSimilarity(liveEmbeddings, face.embeddings);
      if (confidence > maxConfidence) {
        maxConfidence = confidence;
        bestMatch = face;
      }
    }

    return MatchResult(bestMatch: bestMatch, confidence: maxConfidence);
  }

  /// İki embedding vektörü arasındaki kosinüs benzerliğini hesaplar.
  /// Değer 1'e ne kadar yakınsa, yüzler o kadar benzerdir.
  double _cosineSimilarity(Float32List x1, Float32List x2) {
    double dotProduct = 0.0;
    double normX1 = 0.0;
    double normX2 = 0.0;

    for (int i = 0; i < x1.length; i++) {
      dotProduct += x1[i] * x2[i];
      normX1 += x1[i] * x1[i];
      normX2 += x2[i] * x2[i];
    }

    if (normX1 == 0 || normX2 == 0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normX1) * sqrt(normX2));
  }
}
