import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FaceFileService {
  static Future<String> saveFaceImage(File image, String userName) async {
    final dir = await getApplicationDocumentsDirectory();
    final userDir = Directory('${dir.path}/faces/$userName');
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    final filePath = '${userDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await image.copy(filePath);
    return filePath;
  }
}
