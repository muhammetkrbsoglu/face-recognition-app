// face_model.dart

class FaceModel {
  int? id;
  String name;
  String gender; // 'male' veya 'female'
  List<String> imagePaths;
  List<double>? embedding;

  FaceModel({
    this.id,
    required this.name,
    required this.gender,
    required this.imagePaths,
    required this.embedding,
  });

  factory FaceModel.fromMap(Map<String, dynamic> map) {
    return FaceModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      gender: map['gender'] as String? ?? 'male',
      imagePaths: (map['imagePaths'] as String).split(','),
      embedding: (map['embedding'] as String)
          .split(',')
          .where((e) => e.isNotEmpty)
          .map((e) => double.tryParse(e) ?? 0.0)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'imagePaths': imagePaths.join(','),
      'embedding': embedding?.map((e) => e.toString()).join(',') ?? '',
    };
  }
}
