import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/real_time_face_detection_service.dart';

/// Kamera önizlemesi üzerine yüz çerçevesi ve kalite mesajları çizen widget.
class RealTimeQualityOverlay extends StatefulWidget {
  final CameraDescription cameraDescription;
  final Function(CameraImage image, Face face) onFaceVerified;

  const RealTimeQualityOverlay({
    super.key,
    required this.cameraDescription,
    required this.onFaceVerified,
  });

  @override
  State<RealTimeQualityOverlay> createState() => _RealTimeQualityOverlayState();
}

class _RealTimeQualityOverlayState extends State<RealTimeQualityOverlay> {
  CameraController? _cameraController;
  final RealTimeFaceDetectionService _faceDetectionService =
      RealTimeFaceDetectionService();
  StreamSubscription<FaceDetectionResult>? _detectionSubscription;
  FaceDetectionResult? _currentFaceResult;
  CameraImage? _lastImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _cameraController!.initialize();
    if (!mounted) return;

    // Hata düzeltmesi: Servis'e controller'ı burada iletiyoruz.
    await _faceDetectionService.initialize(_cameraController!);

    setState(() {});

    _detectionSubscription =
        _faceDetectionService.detectionStream.listen((result) {
      if (mounted) {
        setState(() {
          _currentFaceResult = result;
        });
      }
    });

    _cameraController!.startImageStream((image) {
      _lastImage = image;
      // Hata düzeltmesi: detectFaces -> processImage
      _faceDetectionService.processImage(image, widget.cameraDescription);
    });
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _detectionSubscription?.cancel();
    _faceDetectionService.dispose();
    super.dispose();
  }

  void _onVerifyButtonPressed() {
    if (_lastImage != null &&
        _currentFaceResult != null &&
        _currentFaceResult!.faces.isNotEmpty) {
      widget.onFaceVerified(_lastImage!, _currentFaceResult!.faces.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        CustomPaint(
          painter: FacePainter(
            faceResult: _currentFaceResult,
            cameraPreviewSze: _cameraController!.value.previewSize!,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.black.withOpacity(0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentFaceResult?.message ?? "Kamera başlatılıyor...",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  // Butonun aktif/pasif durumu kaliteye göre belirleniyor.
                  onPressed: (_currentFaceResult?.qualityMet ?? false)
                      ? _onVerifyButtonPressed
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_currentFaceResult?.qualityMet ?? false)
                        ? Colors.green
                        : Colors.grey,
                  ),
                  child: const Text("Yüzü Doğrula"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Yüz çerçevesini ve konturlarını çizen `CustomPainter`.
class FacePainter extends CustomPainter {
  final FaceDetectionResult? faceResult;
  final Size cameraPreviewSze;

  FacePainter({required this.faceResult, required this.cameraPreviewSze});

  @override
  void paint(Canvas canvas, Size size) {
    if (faceResult == null || faceResult!.faces.isEmpty) return;

    final face = faceResult!.faces.first;
    final imageSize = faceResult!.imageSize;

    // Hata düzeltmesi: Çerçeve rengi burada hesaplanıyor.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = _getFaceFrameColor(faceResult!.confidence);

    // Koordinatları önizleme boyutuna göre ölçekle.
    final scaledRect = _scaleRect(
      rect: face.boundingBox,
      imageSize: imageSize,
      widgetSize: size,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(12)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.faceResult != faceResult;
  }

  // Hata düzeltmesi: Renk belirleme mantığı buraya taşındı.
  Color _getFaceFrameColor(double confidence) {
    if (confidence > 0.9) {
      return Colors.greenAccent;
    } else if (confidence > 0.6) {
      return Colors.yellowAccent;
    } else {
      return Colors.redAccent;
    }
  }

  // Koordinatları ölçeklendirme fonksiyonu.
  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    final scaleX = widgetSize.width / imageSize.height;
    final scaleY = widgetSize.height / imageSize.width;

    final scaledLeft = widgetSize.width - (rect.left * scaleX) - (rect.width * scaleX);
    final scaledTop = rect.top * scaleY;
    final scaledWidth = rect.width * scaleX;
    final scaledHeight = rect.height * scaleY;

    return Rect.fromLTWH(scaledLeft, scaledTop, scaledWidth, scaledHeight);
  }
}
