import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/real_time_face_detection_service.dart';

class RealTimeQualityOverlay extends StatefulWidget {
  final CameraController cameraController;
  final CameraDescription cameraDescription;
  final Function(bool canCapture) onQualityChanged;
  final bool isCapturing;

  const RealTimeQualityOverlay({
    super.key,
    required this.cameraController,
    required this.cameraDescription,
    required this.onQualityChanged,
    this.isCapturing = false,
  });

  @override
  State<RealTimeQualityOverlay> createState() => _RealTimeQualityOverlayState();
}

class _RealTimeQualityOverlayState extends State<RealTimeQualityOverlay> {
  FaceDetectionResult? _currentFaceResult;
  final RealTimeFaceDetectionService _faceDetectionService = RealTimeFaceDetectionService();
  bool _isServiceInitialized = false;
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetection();
  }

  Future<void> _initializeFaceDetection() async {
    try {
      await _faceDetectionService.initialize();
      if(mounted) {
        setState(() {
          _isServiceInitialized = true;
        });
        _startFaceDetection();
      }
    } catch (e) {
      debugPrint('Face detection initialization failed: $e');
    }
  }

  void _startFaceDetection() {
    if (!_isServiceInitialized) return;
    
    if (widget.cameraController.value.isStreamingImages) return;

    widget.cameraController.startImageStream((CameraImage image) {
      if (!mounted || _isProcessingImage) return;
      
      _isProcessingImage = true;
      _processCameraImage(image).whenComplete(() {
        if (mounted) {
          _isProcessingImage = false;
        }
      });
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final result = await _faceDetectionService.detectFaces(image, widget.cameraDescription);
      
      if (mounted && result != null) {
        setState(() {
          _currentFaceResult = result;
        });
        widget.onQualityChanged(result.hasQualityFace);
      }
    } catch (e) {
      debugPrint('Face detection processing error: $e');
    }
  }

  @override
  void dispose() {
    try {
      if (widget.cameraController.value.isStreamingImages) {
        widget.cameraController.stopImageStream();
      }
    } catch (e) {
      debugPrint('Error stopping image stream in overlay: $e');
    }
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentFaceResult == null) {
      return const Center(
        child: Text("Yüz aranıyor...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
      );
    }

    return Stack(
      children: [
        if (_currentFaceResult!.primaryFaceRect != null)
          CustomPaint(
            size: Size.infinite,
            painter: FaceBoxPainter(
              rect: _currentFaceResult!.primaryFaceRect!,
              imageSize: _currentFaceResult!.imageSize,
              cameraLensDirection: widget.cameraDescription.lensDirection,
              color: _faceDetectionService.getFaceFrameColor(_currentFaceResult!.confidence)
            ),
          ),
        
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentFaceResult!.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class FaceBoxPainter extends CustomPainter {
  final Rect rect;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;
  final Color color;

  FaceBoxPainter({required this.rect, required this.imageSize, required this.cameraLensDirection, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final left = cameraLensDirection == CameraLensDirection.front
        ? size.width - (rect.left * scaleX) - (rect.width * scaleX)
        : rect.left * scaleX;
    
    final scaledRect = Rect.fromLTWH(
      left,
      rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(12)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
