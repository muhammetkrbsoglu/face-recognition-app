import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
      // Hata Düzeltmesi: Platforma göre doğru format seçildi
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _cameraController!.initialize();
    if (!mounted) return;

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
      // Önce stream'i durdurarak gereksiz işlem yapılmasını engelle
      _cameraController?.stopImageStream();
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
            cameraLensDirection: widget.cameraDescription.lensDirection,
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
  final CameraLensDirection cameraLensDirection;


  FacePainter({
    required this.faceResult, 
    required this.cameraPreviewSze,
    required this.cameraLensDirection,
    });

  @override
  void paint(Canvas canvas, Size size) {
    if (faceResult == null || faceResult!.faces.isEmpty) return;

    final face = faceResult!.faces.first;
    final imageSize = faceResult!.imageSize;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = _getFaceFrameColor(faceResult!.confidence);

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
    return oldDelegate.faceResult != faceResult ||
           oldDelegate.cameraPreviewSze != cameraPreviewSze ||
           oldDelegate.cameraLensDirection != cameraLensDirection;
  }

  Color _getFaceFrameColor(double confidence) {
    if (confidence > 0.9) {
      return Colors.greenAccent;
    } else if (confidence > 0.6) {
      return Colors.yellowAccent;
    } else {
      return Colors.redAccent;
    }
  }

  // Hata Düzeltmesi: Platforma ve kamera yönüne göre daha doğru ölçekleme
  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / (Platform.isIOS ? imageSize.width : imageSize.height);
    final double scaleY = widgetSize.height / (Platform.isIOS ? imageSize.height : imageSize.width);

    final bool isFrontCamera = cameraLensDirection == CameraLensDirection.front;

    // Android ve iOS'un görüntü akışını farklı işlemesinden kaynaklanan
    // koordinat sistemi farklılıklarını düzeltir.
    if (Platform.isAndroid) {
        final double left = isFrontCamera 
            ? widgetSize.width - (rect.left * scaleX) - (rect.width * scaleX)
            : rect.left * scaleX;
        return Rect.fromLTWH(
            left,
            rect.top * scaleY,
            rect.width * scaleX,
            rect.height * scaleY,
        );
    } 
    // iOS için ölçekleme genellikle daha basittir.
    else {
        return Rect.fromLTWH(
            rect.left * scaleX,
            rect.top * scaleY,
            rect.width * scaleX,
            rect.height * scaleY,
        );
    }
  }
}
