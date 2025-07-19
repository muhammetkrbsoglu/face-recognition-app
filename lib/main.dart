import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:camera/camera.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:math';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_embedding_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_database_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/models/face_model.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/real_time_quality_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/real_time_face_detection_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/widgets/real_time_quality_overlay.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_mesh_detection_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/performance_metrics_service.dart';
import 'core/services/door_service.dart';
import 'core/error_handler.dart';
import 'package:flutter/services.dart';
import 'package:akilli_kapi_guvenlik_sistemi/widgets/enhanced_animations.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  ErrorHandler.info(
    'Uygulama başlatılıyor',
    category: ErrorCategory.system,
    tag: 'APP_START',
  );
  
  try {
    await Future.wait([
      FaceDatabaseService.database,
      RealTimeFaceDetectionService().initialize(),
      FaceMeshDetectionService().initialize(),
    ]);
    ErrorHandler.info(
      'Tüm temel servisler başarıyla başlatıldı',
      category: ErrorCategory.system,
      tag: 'SERVICES_READY',
    );
  } catch (e) {
     ErrorHandler.critical(
      'Kritik servisler başlatılamadı: $e',
      category: ErrorCategory.system,
      tag: 'CRITICAL_SERVICE_FAILURE',
      error: e,
    );
  }
  
  PerformanceMetricsService().startMonitoring();
  
  ErrorHandler.info(
    'Uygulama başlatma tamamlandı',
    category: ErrorCategory.system,
    tag: 'APP_READY',
  );
  
  runApp(const FaceRecognitionApp());
}

class FaceRecognitionApp extends StatelessWidget {
  const FaceRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Yüz Tanıma Kapı Açma Sistemi',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('tr', '')],
        locale: const Locale('tr'),
        home: const MainScaffold(),
      );
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late final FaceEmbeddingService _embeddingService;
  bool _modelLoaded = false;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    _embeddingService = FaceEmbeddingService();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      ErrorHandler.info(
        'Ana yüz tanıma modeli yükleniyor',
        category: ErrorCategory.model,
        tag: 'MAIN_MODEL_LOAD_START',
      );
      await _embeddingService.loadModel();
      if (!mounted) return;
      
      setState(() {
        _modelLoaded = true;
      });

      ErrorHandler.info(
        'Ana yüz tanıma modeli başarıyla yüklendi',
        category: ErrorCategory.model,
        tag: 'MAIN_MODEL_LOAD_SUCCESS',
      );
    } catch (e, stackTrace) {
      if (!mounted) return;
      
      final errorMessage = 'Model yüklenemedi: $e';
      
      ErrorHandler.error(
        'Ana yüz tanıma modeli yüklenemedi',
        category: ErrorCategory.model,
        tag: 'MAIN_MODEL_LOAD_FAILED',
        error: e,
        stackTrace: stackTrace,
      );
      
      setState(() {
        _modelError = errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_modelError != null) {
      return _buildErrorScaffold(_modelError!);
    }
    if (!_modelLoaded) {
      return _buildLoadingScaffold();
    }

    final pages = [
      HomePage(embeddingService: _embeddingService),
      AdminPage(embeddingService: _embeddingService),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Yüz Tanıma Kapı Açma Sistemi')),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Yönetici'),
        ],
      ),
    );
  }


  Scaffold _buildErrorScaffold(String error) => Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: Center(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 16))),
      );

  Scaffold _buildLoadingScaffold() => Scaffold(
        appBar: AppBar(title: const Text('Yükleniyor')),
        body: const Center(child: CircularProgressIndicator()),
      );
}

// ------------------------------------------------------------
// Ana Sayfa
class HomePage extends StatefulWidget {
  final FaceEmbeddingService embeddingService;
  const HomePage({super.key, required this.embeddingService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _processing = false;
  String? _resultMessage;
  bool _cameraError = false;
  bool _canCapture = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      _cameraController = CameraController(
        frontCamera, 
        ResolutionPreset.medium,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
      });
      if (mounted) {
        ErrorHandler.showError(context, 'Kamera başlatılamadı.', userFriendlyKey: 'camera_not_available');
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
    if(!_cameraInitialized || _cameraController == null || _processing || !_canCapture) return;

    setState(() {
      _processing = true;
      _resultMessage = null;
    });
    try {
      final image = await _cameraController!.takePicture();
      
      final qualityResult = await RealTimeQualityService.assessQuality(File(image.path));
      
      if (qualityResult.status == QualityStatus.rejected || qualityResult.status == QualityStatus.poor) {
        if(mounted) ErrorHandler.showWarning(context, 'Fotoğraf uygun değil: ${qualityResult.message}');
        setState(() { _resultMessage = 'Fotoğraf uygun değil: ${qualityResult.message}'; });
        return;
      }
      
      if (qualityResult.status == QualityStatus.acceptable) {
        if(mounted) _showCustomSnackbar('⚠️ Kalite düşük: ${qualityResult.message}', isError: true);
      }
      
      final embedding = await widget.embeddingService.extractEmbedding(File(image.path));
      final normalizedInput = _normalize(embedding);
      final faces = await FaceDatabaseService.getAllFaces();

      if (faces.isEmpty) {
        if(mounted) ErrorHandler.showWarning(context, 'Kayıtlı yüz bulunamadı.');
        setState(() { _resultMessage = 'Kayıtlı yüz bulunamadı.'; });
        return;
      }

      double minDist = double.infinity;
      FaceModel? matchedFace;
      for (final face in faces) {
        if (face.embedding != null && face.embedding!.isNotEmpty) {
          final dist = _cosineDistance(normalizedInput, _normalize(face.embedding!));
          if (dist < minDist) {
            minDist = dist;
            matchedFace = face;
          }
        }
      }
      
      if (minDist < 0.7 && matchedFace != null) {
        _showSuccessAnimation(matchedFace.name, matchedFace.gender);
        String hitap = matchedFace.gender == 'female' ? 'Hanım' : 'Bey';
        String greeting = 'Hoşgeldiniz ${matchedFace.name} $hitap';
        setState(() { _resultMessage = greeting; });
        await _unlockDoor(greeting);
      } else {
        _showFailureAnimation();
        setState(() { _resultMessage = 'Yüz tanınamadı.'; });
      }
    } catch (e) {
      if(mounted) ErrorHandler.showError(context, 'Tanıma sırasında hata oluştu: $e');
      setState(() { _resultMessage = 'Tanıma sırasında hata oluştu.'; });
    } finally {
      if(mounted) setState(() { _processing = false; });
    }
  }
  
  Future<void> _unlockDoor(String greeting) async {
    try {
      final doorService = DoorService();
      final success = await doorService.unlockDoor();
      if (mounted) {
        if (success) {
          _showCustomSnackbar('$greeting - Kapı açıldı!', isError: false);
        } else {
          _showCustomSnackbar('$greeting - Ancak kapı açılamadı!', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackbar('Kapı açma isteği gönderilemedi!', isError: true);
      }
    }
  }


  void _showCustomSnackbar(String message, {bool isError = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.verified, color: isError ? Colors.red : Colors.green, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isError ? Colors.red.shade700 : Colors.green.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade50 : Colors.green.shade50,
        duration: Duration(milliseconds: isError ? 3000 : 1800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 8,
      ),
    );
  }

  void _showSuccessAnimation(String name, String? gender) {
    if(!mounted) return;
    EnhancedAnimations.showSuccessAnimation(context, name);
  }

  void _showFailureAnimation() {
    if(!mounted) return;
    EnhancedAnimations.showErrorAnimation(context, 'Yüz Tanınamadı');
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError) {
      return const Center(child: Text('Kamera başlatılamadı', style: TextStyle(color: Colors.red)));
    }
    return Stack(
      children: [
        if (_cameraInitialized && _cameraController != null)
          // DÜZELTME: Kamera önizlemesini ekranı kaplayacak ve doğru en-boy oranında gösterecek şekilde güncelledik.
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.size.width,
                height: _cameraController!.value.size.height,
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator()),
        
        // DÜZELTME: RealTimeQualityOverlay'i Stack'in içine, kameranın üzerine ekledik.
        if (_cameraInitialized && _cameraController != null)
          RealTimeQualityOverlay(
            cameraController: _cameraController!,
            isCapturing: _processing,
            onQualityChanged: (canCapture) {
              if (mounted) {
                setState(() {
                  _canCapture = canCapture;
                });
              }
            },
          ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _processing
                      ? Container(
                          key: const ValueKey('loading'),
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                            strokeWidth: 6,
                          ),
                        )
                      : ElevatedButton.icon(
                          key: const ValueKey('button'),
                          onPressed: _processing || !_cameraInitialized || !_canCapture ? null : _recognizeFace,
                          icon: const Icon(Icons.face_retouching_natural),
                          label: const Text(
                            'Yüzü Tara',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 56),
                            backgroundColor: _canCapture ? Colors.deepPurple : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                if (_resultMessage != null && !_processing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: _resultMessage!.contains('Hoşgeldiniz') ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _resultMessage!.contains('Hoşgeldiniz') ? Icons.verified : Icons.error_outline,
                          color: _resultMessage!.contains('Hoşgeldiniz') ? Colors.green : Colors.red,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _resultMessage!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _resultMessage!.contains('Hoşgeldiniz') ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Yönetici Sayfası
class AdminPage extends StatefulWidget {
  final FaceEmbeddingService embeddingService;
  const AdminPage({super.key, required this.embeddingService});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _authenticated = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      if (!await _auth.isDeviceSupported()) {
        _setError('Cihazınız biyometrik doğrulamayı desteklemiyor.');
        return;
      }
      final authenticated = await _auth.authenticate(
        localizedReason: 'Yönetici sayfasına erişmek için kimliğinizi doğrulayın',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (!mounted) return;
      if (authenticated) {
        setState(() {
          _authenticated = true;
          _errorMessage = null;
        });
      } else {
        _setError('Kimlik doğrulama başarısız.');
      }
    } catch (e) {
      _setError('Kimlik doğrulama sırasında hata oluştu: $e');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    _showSnackbar(message);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && !_authenticated) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (!_authenticated) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Yönetici Sayfası', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _showAddFaceDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: ListTile(
                  leading: Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.person_add_alt_1, color: Colors.deepPurple, size: 32),
                  ),
                  title: const Text('Yeni Yüz Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: const Text('Farklı pozlarda 5 fotoğraf çekilecek ve isim girilecek.'),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.deepPurple),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _showViewFacesDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: ListTile(
                  leading: Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.list_alt, color: Colors.deepPurple, size: 32),
                  ),
                  title: const Text('Kayıtlı Yüzleri Görüntüle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: const Text('Kayıtlı yüzleri listele, düzenle veya sil.'),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.deepPurple),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _showAddFaceDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddFaceDialog(embeddingService: widget.embeddingService),
    );
  }

  Future<void> _showViewFacesDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const ViewFacesDialog(),
    );
  }
}

// ------------------------------------------------------------
// Yeni Yüz Ekleme Dialog
class AddFaceDialog extends StatefulWidget {
  final FaceEmbeddingService embeddingService;
  const AddFaceDialog({super.key, required this.embeddingService});

  @override
  State<AddFaceDialog> createState() => _AddFaceDialogState();
}

class _AddFaceDialogState extends State<AddFaceDialog> {
  int _currentStep = 0;
  final List<String> _poseLabels = ['Düz Bakış', 'Sağa Bakış', 'Sola Bakış', 'Aşağı Bakış', 'Yukarı Bakış'];
  final List<XFile?> _capturedImages = List<XFile?>.filled(5, null);
  final TextEditingController _nameController = TextEditingController();
  String _selectedGender = 'male';
  bool _isSaving = false;
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _cameraError = false;
  
  bool _canCapture = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      _cameraController = CameraController(
        frontCamera, 
        ResolutionPreset.medium,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
      });
      if(mounted) ErrorHandler.showError(context, 'Kamera başlatılamadı.');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (!_cameraInitialized || _cameraController == null || _isCapturing || !_canCapture) return;
    
    setState(() {
      _isCapturing = true;
    });
    
    try {
      final image = await _cameraController!.takePicture();
      
      final qualityResult = await RealTimeQualityService.assessQuality(File(image.path));
      
      if (qualityResult.status == QualityStatus.rejected ||
          qualityResult.status == QualityStatus.poor) {
        if (mounted) ErrorHandler.showWarning(context, 'Fotoğraf kalitesi uygun değil: ${qualityResult.message}');
        return;
      }
      
      if (qualityResult.status == QualityStatus.acceptable) {
        if (mounted) ErrorHandler.showInfo(context, 'Fotoğraf kabul edilebilir kalitede: ${qualityResult.message}');
      }
      
      if (!mounted) return;
      setState(() {
        _capturedImages[_currentStep] = image;
      });
      
      if (mounted) ErrorHandler.showSuccess(context, '✅ ${_poseLabels[_currentStep]} fotoğrafı çekildi!');
      
      if (_currentStep < 4) {
        setState(() {
          _currentStep++;
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Fotoğraf çekilemedi: $e');
    } finally {
      if(mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _saveFace() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) ErrorHandler.showWarning(context, 'Lütfen isim giriniz');
      return;
    }
    if (_capturedImages.any((img) => img == null)) {
      if (mounted) ErrorHandler.showWarning(context, 'Lütfen tüm pozların fotoğrafını çekiniz');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final imagePaths = _capturedImages.map((img) => img!.path).toList();
      final name = _nameController.text.trim();
      final gender = _selectedGender;
      
      List<List<double>> embeddings = [];
      for (var path in imagePaths) {
        final embedding = await widget.embeddingService.extractEmbedding(File(path));
        embeddings.add(embedding);
      }
      
      List<double> averageEmbedding = List.filled(embeddings[0].length, 0);
      for (var e in embeddings) {
        for (int i = 0; i < e.length; i++) {
          averageEmbedding[i] += e[i];
        }
      }
      for (int i = 0; i < averageEmbedding.length; i++) {
        averageEmbedding[i] /= embeddings.length;
      }
      
      final face = FaceModel(
        name: name,
        gender: gender,
        imagePaths: imagePaths,
        embedding: averageEmbedding,
      );
      
      await FaceDatabaseService.insertFace(face);
      if (mounted) {
        ErrorHandler.showSuccess(context, 'Yüz başarıyla kaydedildi!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Yüz kaydedilemedi: $e');
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNameEntryStep = _capturedImages.every((img) => img != null);
    
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNameEntryStep ? 'Bilgileri Girin' : 'Yüz Ekle (${_currentStep + 1}/5)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (!isNameEntryStep) ...[
                if (_cameraInitialized && _cameraController != null)
                  // DÜZELTME: Kamera önizlemesini doğru en-boy oranında ve üzerinde overlay olacak şekilde güncelledik.
                  SizedBox(
                    height: 320,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: _cameraController!.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_cameraController!),
                            RealTimeQualityOverlay(
                              cameraController: _cameraController!,
                              isCapturing: _isCapturing,
                              onQualityChanged: (canCapture) {
                                if (mounted) {
                                  setState(() {
                                    _canCapture = canCapture;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
                const SizedBox(height: 8),
                Text(_poseLabels[_currentStep]),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isCapturing || !_canCapture ? null : _captureImage,
                  icon: _isCapturing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
                  label: const Text('Fotoğraf Çek'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canCapture ? Colors.deepPurple : Colors.grey,
                  ),
                ),
              ] else ...[
                const Text('Kayıtlı kişinin adını ve cinsiyetini girin.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'İsim',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Cinsiyet:'),
                    Radio<String>(
                      value: 'male',
                      groupValue: _selectedGender,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGender = val);
                      },
                    ),
                    const Text('Erkek'),
                    Radio<String>(
                      value: 'female',
                      groupValue: _selectedGender,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGender = val);
                      },
                    ),
                    const Text('Kadın'),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  if (isNameEntryStep)
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveFace,
                      child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Kayıtlı Yüzleri Görüntüle Dialog
class ViewFacesDialog extends StatefulWidget {
  const ViewFacesDialog({super.key});

  @override
  State<ViewFacesDialog> createState() => _ViewFacesDialogState();
}

class _ViewFacesDialogState extends State<ViewFacesDialog> {
  List<FaceModel> _faces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    try {
      final faces = await FaceDatabaseService.getAllFaces();
      if (!mounted) return;
      setState(() {
        _faces = faces;
        _loading = false;
      });
    } catch (e) {
      if(mounted) ErrorHandler.showError(context, 'Yüzler yüklenemedi: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteFace(FaceModel face) async {
    try {
      await FaceDatabaseService.deleteFace(face);
      if (mounted) {
        ErrorHandler.showSuccess(context, '${face.name} silindi.');
        _loadFaces();
      }
    } catch (e) {
      if(mounted) ErrorHandler.showError(context, 'Yüz silinemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kayıtlı Yüzler'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _faces.isEmpty
                ? const Center(child: Text('Kayıtlı yüz bulunamadı.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _faces.length,
                    itemBuilder: (context, index) {
                      final face = _faces[index];
                      return ListTile(
                        leading: face.imagePaths.isNotEmpty
                            ? CircleAvatar(backgroundImage: FileImage(File(face.imagePaths[0])))
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(face.name),
                        subtitle: Text(face.gender == 'male' ? 'Erkek' : 'Kadın'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteFace(face),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
