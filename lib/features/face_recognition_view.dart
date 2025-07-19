import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:math';
import '../services/face_recognition_service.dart';
import '../services/face_database_service.dart';
import '../services/real_time_quality_service.dart';
import '../widgets/real_time_quality_overlay.dart';
import '../models/face_model.dart';
import '../core/services/door_service.dart';
import '../services/performance_metrics_service.dart';
import '../widgets/enhanced_animations.dart';
import '../core/error_handler.dart';
import '../core/exceptions.dart';

class FaceRecognitionView extends StatefulWidget {
  const FaceRecognitionView({super.key});

  @override
  State<FaceRecognitionView> createState() => _FaceRecognitionViewState();
}

class _FaceRecognitionViewState extends State<FaceRecognitionView> {
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _processing = false;
  bool _canCapture = false;
  String? _resultMessage;
  final FaceRecognitionService _recognitionService = FaceRecognitionService();
  final DoorService _doorService = DoorService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'Kamera başlatılamadı',
        category: ErrorCategory.camera,
        tag: 'CAMERA_INIT_FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      
      if (mounted) {
        ErrorHandler.showError(
          context,
          'Kamera başlatılamadı: $e',
          category: ErrorCategory.camera,
          userFriendlyKey: 'camera_not_available',
        );
      }
    }
  }

  Future<void> _loadModel() async {
    try {
      await _recognitionService.loadModel();
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'Yüz tanıma modeli yüklenemedi',
        category: ErrorCategory.model,
        tag: 'MODEL_LOAD_FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model yüklenemedi: $e')),
        );
      }
    }
  }

  List<double> _normalize(List<double> vector) {
    double sumSq = 0.0;
    for (var val in vector) {
      sumSq += val * val;
    }
    double magnitude = sqrt(sumSq);
    if (magnitude == 0) return List<double>.filled(vector.length, 0.0);
    return vector.map((val) => val / magnitude).toList();
  }

  double _cosineDistance(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty || v1.length != v2.length) {
      throw ArgumentError('Vektörler boş olamaz ve aynı uzunlukta olmalıdır.');
    }
    double dotProduct = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
    }
    return 1.0 - dotProduct;
  }

    Future<void> _recognizeFace() async {
    if (!_canCapture || _processing) return;

    setState(() {
      _processing = true;
      _resultMessage = null;
    });

    // Performance tracking başlat
    final performanceService = PerformanceMetricsService();
    performanceService.startOperation('face_recognition');

    // Processing animasyonu göster
    EnhancedAnimations.showProcessingAnimation(context);

    try {
      final image = await _cameraController!.takePicture();

      // Quality assessment using face detection
      final qualityResult = await RealTimeQualityService.assessQuality(File(image.path));

      if (qualityResult.status == QualityStatus.rejected) {
        if (mounted) {
          Navigator.of(context).pop(); // Processing dialog'u kapat
          EnhancedAnimations.showErrorAnimation(context, 'Fotoğraf uygun değil: ${qualityResult.message}');
          setState(() { _resultMessage = 'Fotoğraf uygun değil: ${qualityResult.message}'; });
        }
        performanceService.endOperation('face_recognition', success: false);
        return;
      }

      // Face recognition
      final embedding = await _recognitionService.extractEmbedding(File(image.path));
      final normalizedInput = _normalize(embedding);
      final faces = await FaceDatabaseService.getAllFaces();

      if (faces.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop(); // Processing dialog'u kapat
          EnhancedAnimations.showErrorAnimation(context, 'Kayıtlı yüz bulunamadı.');
          setState(() { _resultMessage = 'Kayıtlı yüz bulunamadı.'; });
        }
        performanceService.endOperation('face_recognition', success: false);
        return;
      }

      double minDist = double.infinity;
      FaceModel? matchedFace;

      for (final face in faces) {
        if (face.embedding != null) {
          final dist = _cosineDistance(normalizedInput, _normalize(face.embedding!));
          if (dist < minDist) {
            minDist = dist;
            matchedFace = face;
          }
        }
      }

      // Eşik değeri 0.7 (ArcFace için genellikle 0.6-0.8 arası uygundur)
      if (minDist < 0.7 && matchedFace != null) {
        String hitap = matchedFace.gender == 'female' ? 'Hanım' : 'Bey';
        String greeting = 'Hoşgeldiniz ${matchedFace.name} $hitap';
        if (mounted) {
          setState(() { _resultMessage = greeting; });
          Navigator.of(context).pop(); // Processing dialog'u kapat
          EnhancedAnimations.showSuccessAnimation(context, matchedFace.name);
        }

        // Kapı açma
        final doorSuccess = await _doorService.unlockDoor();
        if (doorSuccess) {
          _showCustomSnackbar('✅ $greeting - Kapı açılıyor!', isError: false);
        } else {
          _showCustomSnackbar('✅ $greeting - Kapı açılamadı!', isError: true);
        }
        performanceService.endOperation('face_recognition', success: true);
              } else {
          if (mounted) {
            Navigator.of(context).pop(); // Processing dialog'u kapat
            EnhancedAnimations.showErrorAnimation(context, 'Yüz tanınamadı.');
            setState(() { _resultMessage = 'Yüz tanınamadı.'; });
          }
          performanceService.endOperation('face_recognition', success: false);
        }
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'Yüz tanıma sırasında hata oluştu',
        category: ErrorCategory.faceRecognition,
        tag: 'RECOGNITION_FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Processing dialog'u kapat
        
        // Hata türüne göre farklı mesajlar göster
        String userMessage;
        if (e is AppException) {
          userMessage = e.userFriendlyMessage ?? 'Yüz tanıma sırasında hata oluştu';
        } else {
          userMessage = 'Yüz tanıma sırasında beklenmeyen hata oluştu. Lütfen tekrar deneyin.';
        }
        
        EnhancedAnimations.showErrorAnimation(context, userMessage);
        setState(() { _resultMessage = userMessage; });
      }
      
      performanceService.endOperation('face_recognition', success: false);
    } finally {
      setState(() { _processing = false; });
    }
  }

  void _showCustomSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.verified,
              color: isError ? Colors.red : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yüz Tanıma'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _cameraInitialized
          ? Stack(
              children: [
                // Camera Preview
                AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
                
                // Real-time Quality Overlay
                RealTimeQualityOverlay(
                  cameraController: _cameraController!,
                  isCapturing: _processing,
                  onQualityChanged: (canCapture) {
                    setState(() {
                      _canCapture = canCapture;
                    });
                  },
                ),
                
                // Performance Dashboard
                // TODO: Add performance report when available
                // const PerformanceDashboard(report: performanceReport),
                
                // Recognition Button
                Positioned(
                  bottom: 50,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: _canCapture && !_processing ? _recognizeFace : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canCapture ? Colors.deepPurple : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _processing
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Icon(Icons.face_retouching_natural,
                            color: Colors.white, size: 28),
                    label: Text(
                      _processing ? 'Tanıma işlemi yapılıyor...' : 'Yüzü Tara ve Kapıyı Aç',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                // Result Message
                if (_resultMessage != null)
                  Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _resultMessage!,
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
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}