import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Fotoğraf kalitesinin durumunu belirten enum.
enum QualityStatus {
  excellent('Mükemmel'),
  good('İyi'),
  acceptable('Kabul Edilebilir'),
  poor('Zayıf'),
  rejected('Reddedildi');
  
  const QualityStatus(this.displayName);
  final String displayName;
}

/// Kalite analizinin sonucunu tutan sınıf.
class QualityResult {
  final QualityStatus status;
  final String message;
  final double score;

  QualityResult({required this.status, required this.message, required this.score});
}

/// Çekilen bir fotoğrafın kalitesini derinlemesine analiz eden statik servis.
class RealTimeQualityService {
  
  // Kalite kontrolü için eşik değerleri
  static const double _minImageWidth = 200.0;
  static const double _minImageHeight = 200.0;
  static const double _brightnessThresholdLow = 50.0;
  static const double _brightnessThresholdHigh = 210.0;
  static const double _blurVarianceThreshold = 100.0;
  static const double _contrastThreshold = 40.0;

  /// Verilen bir görüntü dosyasının kalitesini analiz eder.
  static Future<QualityResult> assessQuality(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return QualityResult(status: QualityStatus.rejected, message: 'Görüntü dosyası okunamadı.', score: 0);
    }
    
    // 1. Çözünürlük Kontrolü
    if (decodedImage.width < _minImageWidth || decodedImage.height < _minImageHeight) {
      return QualityResult(status: QualityStatus.rejected, message: 'Görüntü çözünürlüğü çok düşük.', score: 10);
    }

    // 2. Parlaklık ve Kontrast için piksel analizi
    List<double> brightnessValues = [];
    // Performans için her 5 pikselde bir örnekleme yapılır.
    for (int y = 0; y < decodedImage.height; y += 5) {
      for (int x = 0; x < decodedImage.width; x += 5) {
        final pixel = decodedImage.getPixel(x, y);
        brightnessValues.add(0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
      }
    }
    
    if (brightnessValues.isEmpty) {
       return QualityResult(status: QualityStatus.rejected, message: 'Piksel verisi analiz edilemedi.', score: 0);
    }

    final avgBrightness = brightnessValues.reduce((a, b) => a + b) / brightnessValues.length;
    
    // Kontrast (parlaklık standart sapması)
    double varianceSum = 0;
    for (var b in brightnessValues) {
      varianceSum += pow(b - avgBrightness, 2);
    }
    final contrast = sqrt(varianceSum / brightnessValues.length);

    // 3. Bulanıklık (Laplacian variance)
    double laplacianVariance = _calculateBlur(decodedImage);

    // 4. Genel Skorlama
    double totalScore = 0;
    String finalMessage = '';

    // Parlaklık skoru (35 Puan)
    if (avgBrightness < _brightnessThresholdLow) {
      finalMessage += 'Fotoğraf çok karanlık. ';
    } else if (avgBrightness > _brightnessThresholdHigh) {
      finalMessage += 'Fotoğraf çok parlak. ';
    } else {
      totalScore += 35;
    }
    
    // Bulanıklık skoru (40 Puan)
    if(laplacianVariance < _blurVarianceThreshold) {
      finalMessage += 'Fotoğraf bulanık. ';
    } else {
      totalScore += 40;
    }
    
    // Kontrast skoru (25 Puan)
    if (contrast < _contrastThreshold) {
      finalMessage += 'Kontrast düşük. ';
    } else {
      totalScore += 25;
    }

    // Skora göre durum belirleme
    QualityStatus status;
    if (totalScore >= 90) status = QualityStatus.excellent;
    else if (totalScore >= 75) status = QualityStatus.good;
    else if (totalScore >= 50) status = QualityStatus.acceptable;
    else if (totalScore >= 25) status = QualityStatus.poor;
    else status = QualityStatus.rejected;

    if (finalMessage.isEmpty) {
      finalMessage = "Kalite: ${status.displayName}";
    }
    
    return QualityResult(status: status, message: finalMessage.trim(), score: totalScore);
  }

  /// Görüntünün bulanıklık seviyesini Laplacian variance yöntemiyle hesaplar.
  static double _calculateBlur(img.Image image) {
    double sum = 0.0;
    double sumSq = 0.0;
    int count = 0;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final p = image.getPixel(x, y);
        // Gri tonlama (luminance)
        final center = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
        final top = (0.299*image.getPixel(x, y - 1).r + 0.587*image.getPixel(x, y - 1).g + 0.114*image.getPixel(x, y - 1).b);
        final bottom = (0.299*image.getPixel(x, y + 1).r + 0.587*image.getPixel(x, y + 1).g + 0.114*image.getPixel(x, y + 1).b);
        final left = (0.299*image.getPixel(x - 1, y).r + 0.587*image.getPixel(x - 1, y).g + 0.114*image.getPixel(x - 1, y).b);
        final right = (0.299*image.getPixel(x + 1, y).r + 0.587*image.getPixel(x + 1, y).g + 0.114*image.getPixel(x + 1, y).b);

        final laplacian = (4 * center) - top - bottom - left - right;
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }
    if (count == 0) return 0.0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance;
  }
}
