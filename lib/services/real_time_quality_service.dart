import 'package:image/image.dart' as img;

/// Görüntü kalitesinin durumunu belirten enum.
enum ImageQualityStatus {
  Excellent,
  Good,
  Poor,
}

/// Görüntü kalitesi analizinin sonucunu tutan model.
class ImageQualityResult {
  final ImageQualityStatus status;
  final double score;
  final String message;

  ImageQualityResult(
      {required this.status, required this.score, required this.message});
}

/// Bir görüntünün kalitesini (parlaklık, bulanıklık vb.) analiz eden statik servis.
class RealTimeQualityService {
  // Eşik değerleri
  static const double _brightnessThreshold = 80.0;
  static const double _blurThreshold = 100.0; // Laplacian varyans için eşik

  /// Verilen bir görüntünün kalitesini analiz eder.
  static ImageQualityResult analyzeImageQuality(img.Image image) {
    double qualityScore = 1.0;
    String message = "Kalite mükemmel";

    // 1. Parlaklık Analizi
    final double brightness = _calculateAverageBrightness(image);
    if (brightness < _brightnessThreshold) {
      qualityScore -= 0.4;
      message = "Görüntü çok karanlık.";
    }

    // 2. Bulanıklık Analizi (Laplacian Varyansı)
    final double blurriness = _calculateBlurriness(image);
    if (blurriness < _blurThreshold) {
      qualityScore -= 0.5;
      message = "Görüntü bulanık.";
    }

    // Sonuç
    ImageQualityStatus status;
    if (qualityScore > 0.8) {
      status = ImageQualityStatus.Excellent;
      message = "Görüntü kalitesi çok iyi.";
    } else if (qualityScore > 0.5) {
      status = ImageQualityStatus.Good;
    } else {
      status = ImageQualityStatus.Poor;
    }

    return ImageQualityResult(
      status: status,
      score: qualityScore.clamp(0.0, 1.0),
      message: message,
    );
  }

  /// Görüntünün ortalama parlaklığını hesaplar.
  static double _calculateAverageBrightness(img.Image image) {
    double totalLuminance = 0;
    for (final pixel in image) {
      totalLuminance += pixel.luminance;
    }
    return totalLuminance / (image.width * image.height);
  }

  /// Görüntünün bulanıklık seviyesini Laplacian operatörü ile hesaplar.
  /// Yüksek varyans, daha net bir görüntü anlamına gelir.
  static double _calculateBlurriness(img.Image image) {
    final grayImage = img.grayscale(image);
    double mean = 0.0;
    double variance = 0.0;
    final laplacianKernel = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0]
    ];

    final List<double> laplacianValues = [];

    for (int y = 1; y < grayImage.height - 1; y++) {
      for (int x = 1; x < grayImage.width - 1; x++) {
        double sum = 0;
        for (int i = -1; i <= 1; i++) {
          for (int j = -1; j <= 1; j++) {
            final pixel = grayImage.getPixel(x + j, y + i);
            sum += pixel.r * laplacianKernel[i + 1][j + 1];
          }
        }
        laplacianValues.add(sum);
        mean += sum;
      }
    }

    if (laplacianValues.isEmpty) return 0.0;
    
    mean /= laplacianValues.length;

    for (final value in laplacianValues) {
      variance += (value - mean) * (value - mean);
    }

    return variance / laplacianValues.length;
  }
}
