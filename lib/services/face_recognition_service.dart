import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// ArcFace TFLite tabanlı yüz embedding servisi (Singleton) - Detaylı Debug Version
class FaceRecognitionService {
  /// Fotoğrafın bulanıklığını kontrol eder (DÜZELTİLMİŞ)
  Future<String?> checkBlur(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return 'Fotoğraf okunamadı.';

      double sum = 0;
      double sumSq = 0;
      int count = 0;

      for (int y = 1; y < image.height - 1; y++) {
        for (int x = 1; x < image.width - 1; x++) {
          final centerPixel = image.getPixel(x, y);
          final leftPixel = image.getPixel(x - 1, y);
          final rightPixel = image.getPixel(x + 1, y);
          final topPixel = image.getPixel(x, y - 1);
          final bottomPixel = image.getPixel(x, y + 1);

          // Doğru gri tonlama (luminance) hesaplama
          final center = (0.299 * centerPixel.r + 0.587 * centerPixel.g + 0.114 * centerPixel.b);
          final left = (0.299 * leftPixel.r + 0.587 * leftPixel.g + 0.114 * leftPixel.b);
          final right = (0.299 * rightPixel.r + 0.587 * rightPixel.g + 0.114 * rightPixel.b);
          final top = (0.299 * topPixel.r + 0.587 * topPixel.g + 0.114 * topPixel.b);
          final bottom = (0.299 * bottomPixel.r + 0.587 * bottomPixel.g + 0.114 * bottomPixel.b);

          final laplacian = (4 * center) - left - right - top - bottom;
          sum += laplacian;
          sumSq += laplacian * laplacian;
          count++;
        }
      }

      if (count == 0) return 'Görüntü çok küçük veya geçersiz.';

      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);

      if (variance < 150) {
        return 'Fotoğraf çok bulanık. Telefonu sabit tutun.';
      }
      return null;
    } catch (e) {
      _debugLog('Bulanıklık kontrolü hatası: $e');
      return 'Bulanıklık kontrolü hatası: $e';
    }
  }

  /// Fotoğrafın ortalama parlaklığını kontrol eder (DÜZELTİLMİŞ)
  Future<String?> checkBrightness(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return 'Resim işlenemedi';

    int totalLuminance = 0;
    int sampleCount = 0;

    // Her 5 pikselde bir sampling yaparak daha iyi sonuç alıyoruz
    for (int y = 0; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
        totalLuminance += luminance;
        sampleCount++;
      }
    }

    if (sampleCount == 0) return 'Görüntü çok küçük veya geçersiz.';

    final avgLuminance = totalLuminance ~/ sampleCount;

    if (avgLuminance < 60) return 'Resim çok karanlık. Daha iyi ışıklı bir yere geçin.';
    if (avgLuminance > 200) return 'Resim çok parlak. Işığı azaltın veya gölgeli bir yere geçin.';

    return null; // Parlaklık uygun
  }

  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  Interpreter? _interpreter;
  bool _modelLoaded = false;

  bool get isModelLoaded => _modelLoaded;

  void _debugLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('[$timestamp] [FaceRecognition] $message');
  }

  void _printTensorInfo(String name, Tensor tensor) {
    _debugLog('=== $name Tensor Bilgileri ===');
    _debugLog('Shape: ${tensor.shape}');
    _debugLog('Type: ${tensor.type}');
    _debugLog('Data Type: ${tensor.data.runtimeType}');
    if (tensor.shape.isNotEmpty) {
      final totalElements = tensor.shape.reduce((a, b) => a * b);
      _debugLog('Toplam Element Sayısı: $totalElements');
    }
    _debugLog('==========================================');
  }

  List<double> _normalize(List<double> embedding) {
    final norm = sqrt(embedding.map((x) => x * x).reduce((a, b) => a + b));
    return embedding.map((x) => x / norm).toList();
  }

  Future<void> loadModel() async {
    if (_modelLoaded) {
      _debugLog('Model zaten yüklü, tekrar yükleme atlanıyor');
      return;
    }

    try {
      _debugLog('Model yükleme başlıyor...');
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/arcface_512d.tflite',
        options: options,
      );

      _debugLog('Model başarıyla yüklendi!');
      _modelLoaded = true;

      _debugLog('=== MODEL GENEL BİLGİLERİ ===');
      _debugLog('Input Tensor Sayısı: ${_interpreter!.getInputTensors().length}');
      _debugLog('Output Tensor Sayısı: ${_interpreter!.getOutputTensors().length}');

      for (int i = 0; i < _interpreter!.getInputTensors().length; i++) {
        _printTensorInfo('INPUT-$i', _interpreter!.getInputTensor(i));
      }
      for (int i = 0; i < _interpreter!.getOutputTensors().length; i++) {
        _printTensorInfo('OUTPUT-$i', _interpreter!.getOutputTensor(i));
      }
    } catch (e) {
      _debugLog('HATA: Model yüklenirken hata oluştu: $e');
      _debugLog('Stack Trace: ${StackTrace.current}');
      throw Exception('Model yüklenirken hata oluştu (ArcFace): $e');
    }
  }

  img.Image _preprocessImage(File imageFile) {
    _debugLog('=== GÖRÜNTÜ ÖN İŞLEME BAŞLIYOR ===');
    try {
      final imageBytes = imageFile.readAsBytesSync();
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Görüntü decode edilemedi');
      }
      final resized = img.copyResize(originalImage, width: 112, height: 112);
      return resized;
    } catch (e) {
      _debugLog('HATA: Görüntü işleme hatası: $e');
      throw Exception('Görüntü işleme hatası: $e');
    }
  }

  Float32List _imageToTensorRGB(img.Image image, List<int> expectedShape, bool isChannelFirst) {
    final expectedSize = expectedShape.reduce((a, b) => a * b);
    final inputData = Float32List(expectedSize);

    if (isChannelFirst) {
      int rIndex = 0;
      int gIndex = 112 * 112;
      int bIndex = 2 * 112 * 112;
      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          final pixel = image.getPixel(x, y);
          final r = (pixel.r.toDouble() - 127.5) / 127.5; // DÜZELTİLDİ
          final g = (pixel.g.toDouble() - 127.5) / 127.5; // DÜZELTİLDİ
          final b = (pixel.b.toDouble() - 127.5) / 127.5; // DÜZELTİLDİ
          inputData[rIndex++] = r;
          inputData[gIndex++] = g;
          inputData[bIndex++] = b;
        }
      }
    } else {
      int index = 0;
      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          final pixel = image.getPixel(x, y);
          inputData[index++] = (pixel.r.toDouble() - 127.5) / 127.5; // DÜZELTİLDİ
          inputData[index++] = (pixel.g.toDouble() - 127.5) / 127.5; // DÜZELTİLDİ
          inputData[index++] = (pixel.b.toDouble() - 127.5) / 127.5; // DÜZELTİLDİ
        }
      }
    }

    return inputData;
  }

  Future<List<double>> extractEmbedding(File imageFile) async {
    _debugLog('=== EMBEDDING ÇIKARMA BAŞLIYOR ===');
    if (!_modelLoaded || _interpreter == null) {
      throw Exception('Model yüklenmedi. Lütfen önce modeli yükleyin.');
    }

    try {
      final resized = _preprocessImage(imageFile);
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;

      bool isChannelFirst = inputShape.length == 4 && inputShape[1] == 3;

      final inputData = _imageToTensorRGB(resized, inputShape, isChannelFirst);

      // Çıktı için bellekte yer ayırma şekli düzeltildi
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputBuffer = List.generate(outputShape[0], (i) => List<double>.filled(outputShape[1], 0.0));

      _interpreter!.run(inputData.buffer.asUint8List(), outputBuffer);

      final rawEmbedding = outputBuffer[0].cast<double>();
      final embedding = _normalize(rawEmbedding);

      return embedding;
    } catch (e, stackTrace) {
      _debugLog('HATA: Embedding çıkarılırken hata oluştu: $e');
      _debugLog('Stack Trace: $stackTrace');
      throw Exception('Embedding çıkarılırken hata oluştu: $e');
    }
  }

  /// Yüz kalite kontrolü (DÜZELTİLMİŞ)
  Future<String?> checkFaceQuality(File imageFile) async {
    final imgBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imgBytes);

    if (decodedImage == null) return 'Görüntü okunamadı';

    // Yüz boyutu kontrolü (minimum görüntü boyutu)
    if (decodedImage.width < 200 || decodedImage.height < 200) {
      return 'Yüz çok küçük. Telefonu yüzünüze yaklaştırın.';
    }

    List<double> brightnessValues = [];
    
    // Her 5 pikselde bir sampling yaparak performansı artırıyoruz
    for (int y = 0; y < decodedImage.height; y += 5) {
      for (int x = 0; x < decodedImage.width; x += 5) {
        final pixel = decodedImage.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        brightnessValues.add(luminance);
      }
    }
    
    if (brightnessValues.isEmpty) return 'Görüntü piksel verisi bulunamadı.';

    double avgBrightness = brightnessValues.reduce((a, b) => a + b) / brightnessValues.length;

    if (avgBrightness < 60) return 'Görüntü çok karanlık. Daha iyi ışıklı bir yere geçin.';
    if (avgBrightness > 200) return 'Görüntü çok parlak. Işığı azaltın veya gölgeli bir yere geçin.';

    // Kontrast kontrolü (parlaklık varyansı)
    double variance = 0;
    for (int i = 0; i < brightnessValues.length; i++) {
      variance += pow(brightnessValues[i] - avgBrightness, 2);
    }
    variance /= brightnessValues.length;

    if (variance < 30) return 'Görüntü kontrastı düşük. Daha kontrastlı bir arka plan seçin.';

    return null; // Kalite problemi yok
  }

  void dispose() {
    _debugLog('Servis temizleniyor...');
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
    _debugLog('Servis temizlendi');
  }
}