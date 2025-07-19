import 'package:flutter_test/flutter_test.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_match_service.dart';

void main() {
  test('Cosine similarity returns correct value', () {
    final a = [1.0, 0.0];
    final b = [1.0, 0.0];
    expect(FaceMatchService.cosineSimilarity(a, b), 1.0);
  });
}
