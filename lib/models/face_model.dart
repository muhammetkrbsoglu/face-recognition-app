import 'dart:convert';
import 'dart:typed_data';

/// Veritabanında saklanacak yüz verilerini temsil eden model sınıfı.
class FaceModel {
  final int? id;
  final String name;
  final String gender;
  final String imagePath;
  final Float32List embeddings;

  FaceModel({
    this.id,
    required this.name,
    required this.gender,
    required this.imagePath,
    required this.embeddings,
  });

  /// Modeli veritabanına yazmak için bir Map'e dönüştürür.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'imagePath': imagePath,
      // Float32List doğrudan saklanamaz, JSON string'e çeviriyoruz.
      'embeddings': jsonEncode(embeddings.toList()),
    };
  }

  /// Veritabanından okunan bir Map'i Model nesnesine dönüştürür.
  factory FaceModel.fromMap(Map<String, dynamic> map) {
    return FaceModel(
      id: map['id'],
      name: map['name'],
      gender: map['gender'] ?? 'Belirtilmedi', // Geriye dönük uyumluluk
      imagePath: map['imagePath'],
      // JSON string'i tekrar Float32List'e çeviriyoruz.
      embeddings: Float32List.fromList(
        (jsonDecode(map['embeddings']) as List<dynamic>)
            .map((e) => e as double)
            .toList(),
      ),
    );
  }
}
