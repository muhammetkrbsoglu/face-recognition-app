import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/real_time_face_detection_service.dart';

/// Gerçek zamanlı kalite geri bildirim overlay widget'i
class RealTimeQualityOverlay extends StatefulWidget {
  final CameraController cameraController;
  final Function(bool canCapture) onQualityChanged;
  final bool isCapturing;

  const RealTimeQualityOverlay({
    super.key,
    required this.cameraController,
    required this.onQualityChanged,
    this.isCapturing = false,
  });

  @override
  State<RealTimeQualityOverlay> createState() => _RealTimeQualityOverlayState();
}

class _RealTimeQualityOverlayState extends State<RealTimeQualityOverlay> with TickerProviderStateMixin {
  FaceDetectionResult? _currentFaceResult;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  
  final RealTimeFaceDetectionService _faceDetectionService = RealTimeFaceDetectionService();
  bool _isServiceInitialized = false;
  bool _processingImage = false;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeFaceDetection();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeFaceDetection() async {
    try {
      await _faceDetectionService.initialize();
      _isServiceInitialized = true;
      _startFaceDetection();
    } catch (e) {
      debugPrint('Face detection initialization failed: $e');
      // Fallback: Basit quality check kullan
      _startFallbackQualityCheck();
    }
  }

  void _startFallbackQualityCheck() {
    // Fallback mechanism: Simple quality check without face detection
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Basit fallback: Kabul edilebilir kalite olarak işaretle
      final fallbackResult = FaceDetectionResult(
        faces: [],
        hasQualityFace: true, // Fallback olarak kabul et
        message: '📸 Kamera hazır - Fotoğraf çekebilirsiniz',
        confidence: 70.0,
      );
      
      setState(() {
        _currentFaceResult = fallbackResult;
      });
      
      widget.onQualityChanged(true);
    });
  }

  void _startFaceDetection() {
    if (!_isServiceInitialized) return;
    
    widget.cameraController.startImageStream((CameraImage image) {
      if (!mounted || _processingImage) return;
      
      // Sadece işlem yapılmadığında yeni frame'i işle
      _processingImage = true;
      _processCameraImage(image).then((_) {
        _processingImage = false;
      });
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final result = await _faceDetectionService.detectFaces(image);
      
      if (mounted) {
        setState(() {
          _currentFaceResult = result;
        });

        // Callback çağır
        widget.onQualityChanged(result.hasQualityFace);

        // Kalite değiştiğinde animasyon tetikle
        if (result.hasQualityFace) {
          _bounceController.forward().then((_) => _bounceController.reverse());
        }
      }
    } catch (e) {
      debugPrint('Face detection processing error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    
    // Camera stream'i durdur
    try {
      widget.cameraController.stopImageStream();
    } catch (e) {
      debugPrint('Camera stream stop error: $e');
    }
    
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentFaceResult == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Yüz çerçevesi (gerçek koordinatlarda)
        _buildRealFaceFrame(),
        
        // Kalite göstergesi
        _buildQualityIndicator(),
        
        // Rehber çizgiler
        _buildGuideLines(),
        
        // Mesaj paneli
        _buildMessagePanel(),
        
        // Kalite skoru
        _buildQualityScore(),
      ],
    );
  }

  Widget _buildRealFaceFrame() {
    final color = _faceDetectionService.getFaceFrameColor(_currentFaceResult!.confidence);
    
    return Stack(
      children: [
        // Eğer yüz tespit edilmişse gerçek koordinatlarda çerçeve
        if (_currentFaceResult!.primaryFaceRect != null)
          Positioned(
            left: _currentFaceResult!.primaryFaceRect!.left,
            top: _currentFaceResult!.primaryFaceRect!.top,
            width: _currentFaceResult!.primaryFaceRect!.width,
            height: _currentFaceResult!.primaryFaceRect!.height,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        // Köşe işaretleri
                        ...List.generate(4, (index) {
                          final positions = [
                            const Alignment(-0.9, -0.9), // Sol üst
                            const Alignment(0.9, -0.9),  // Sağ üst
                            const Alignment(-0.9, 0.9),  // Sol alt
                            const Alignment(0.9, 0.9),   // Sağ alt
                          ];
                          
                          return Align(
                            alignment: positions[index],
                            child: Container(
                              width: 15,
                              height: 15,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else
          // Yüz tespit edilmemişse merkezi çerçeve
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 280,
                    height: 350,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(140),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQualityIndicator() {
    final color = _faceDetectionService.getFaceFrameColor(_currentFaceResult!.confidence);
    
    return Positioned(
      top: 50,
      right: 20,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getStatusIcon(_currentFaceResult!.hasQualityFace),
                  const SizedBox(width: 8),
                  Text(
                    '${_currentFaceResult!.confidence.toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuideLines() {
    return Stack(
      children: [
        // Dikey orta çizgi
        Positioned(
          left: MediaQuery.of(context).size.width / 2 - 1,
          top: 0,
          bottom: 0,
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        
        // Yatay orta çizgi
        Positioned(
          top: MediaQuery.of(context).size.height / 2 - 1,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagePanel() {
    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _faceDetectionService.getFaceFrameColor(_currentFaceResult!.confidence),
            width: 2,
          ),
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
    );
  }

  Widget _buildQualityScore() {
    return Positioned(
      top: 50,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kalite Skoru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 60,
                  height: 6,
                  child: LinearProgressIndicator(
                    value: _currentFaceResult!.confidence / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _faceDetectionService.getFaceFrameColor(_currentFaceResult!.confidence),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Icon _getStatusIcon(bool hasQualityFace) {
    if (hasQualityFace) {
      return const Icon(Icons.check_circle, color: Colors.white, size: 20);
    } else {
      return const Icon(Icons.warning, color: Colors.white, size: 20);
    }
  }
} 