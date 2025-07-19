import 'dart:math';

class FaceMatchService {
  // Cosine similarity
  static double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  // KNN (k=3)
  static String knnMatch(List<double> embedding, List<Map<String, dynamic>> faces, {int k = 3}) {
    List<_MatchScore> scores = [];
    for (final face in faces) {
      final emb = face['embedding'] as List<double>?;
      if (emb == null) continue;
      final score = cosineSimilarity(embedding, emb);
      scores.add(_MatchScore(face['name'], score));
    }
    scores.sort((a, b) => b.score.compareTo(a.score));
    final top = scores.take(k).toList();
    final nameCounts = <String, int>{};
    for (final m in top) {
      nameCounts[m.name] = (nameCounts[m.name] ?? 0) + 1;
    }
    return nameCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

class _MatchScore {
  final String name;
  final double score;
  _MatchScore(this.name, this.score);
}
