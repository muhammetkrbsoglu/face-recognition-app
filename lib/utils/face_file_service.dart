import 'dart:io';

import 'package:akilli_kapi_guvenlik_sistemi/core/error_handler.dart';
import 'package:akilli_kapi_guvenlik_sistemi/core/exceptions.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Yüz görüntülerini dosyaya kaydetme ve yönetme işlemlerini yapan servis.
class FaceFileService {
  /// Verilen bir `img.Image` nesnesini PNG olarak cihaza kaydeder.
  ///
  /// @param image Kaydedilecek `img.Image` nesnesi.
  /// @param name Dosya adını oluşturmak için kullanılacak kişi adı.
  /// @return Kaydedilen dosyanın tam yolunu döndürür.
  static Future<String> saveFaceImage(img.Image image, String name) async {
    try {
      // Görüntüyü PNG formatına encode et
      final png = img.encodePng(image);

      // Uygulamanın dokümanlar klasörünü al
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = p.join(directory.path, 'faces');

      // Eğer 'faces' klasörü yoksa oluştur
      final faceDir = Directory(imagePath);
      if (!await faceDir.exists()) {
        await faceDir.create(recursive: true);
      }

      // Benzersiz bir dosya adı oluştur
      final fileName = '${name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = p.join(imagePath, fileName);

      // Dosyayı diske yaz
      final file = File(filePath);
      await file.writeAsBytes(png);

      ErrorHandler.log('Yüz resmi kaydedildi: $filePath', level: LogLevel.info);
      return filePath;

    } catch (e, s) {
      ErrorHandler.log('Yüz resmi kaydedilemedi.', error: e, stackTrace: s, category: ErrorCategory.file);
      // HATA DÜZELTMESİ: Exception doğru parametre ile çağrıldı.
      throw FileSystemException(message: 'Yüz resmi dosyaya kaydedilirken bir hata oluştu.');
    }
  }
}
