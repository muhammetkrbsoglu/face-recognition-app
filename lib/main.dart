import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:camera/camera.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:math';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_embedding_service.dart'; // DEĞİŞTİRİLDİ
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
  
  // Kritik servisleri eş zamanlı başlat
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
  // DEĞİŞTİRİLDİ: FaceEmbeddingService kullanılıyor
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
      // DEĞİŞTİRİLDİ: Yeni servis üzerinden model yükleniyor
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
    if (_modelError != null) return _buildErrorScaffold(_modelError!);
    if (!_modelLoaded) return _buildLoadingScaffold();

    // DEĞİŞTİRİLDİ: Sayfalara yeni servis (embeddingService) gönderiliyor
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
  // DEĞİŞTİRİLDİ
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
      debugPrint('Kamera başlatılamadı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamera başlatılamadı')));
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
    if(!_cameraInitialized || _cameraController == null || _processing) return;

    setState(() {
      _processing = true;
      _resultMessage = null;
    });
    try {
      final image = await _cameraController!.takePicture();
      
      final qualityResult = await RealTimeQualityService.assessQuality(File(image.path));
      
      if (qualityResult.status == QualityStatus.rejected || qualityResult.status == QualityStatus.poor) {
        _showCustomSnackbar('Fotoğraf uygun değil: ${qualityResult.message}', isError: true);
        setState(() { _resultMessage = 'Fotoğraf uygun değil: ${qualityResult.message}'; });
        return;
      }
      
      if (qualityResult.status == QualityStatus.acceptable) {
        _showCustomSnackbar('⚠️ Kalite düşük: ${qualityResult.message}', isError: true);
      }
      
      // DEĞİŞTİRİLDİ
      final embedding = await widget.embeddingService.extractEmbedding(File(image.path));
      final normalizedInput = _normalize(embedding);
      final faces = await FaceDatabaseService.getAllFaces();

      if (faces.isEmpty) {
        _showCustomSnackbar('Kayıtlı yüz bulunamadı.', isError: true);
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
      debugPrint('Tanıma hatası: $e');
      _showCustomSnackbar('Tanıma sırasında hata oluştu: $e', isError: true);
      setState(() { _resultMessage = 'Tanıma sırasında hata oluştu: $e'; });
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
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
  }

  void _showSuccessAnimation(String name, String? gender) {
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
  }

  void _showFailureAnimation() {
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
  }

  @override
  Widget build(BuildContext context) {
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
    // Önemli olan yukarıdaki mantıksal değişikliklerdi.
    // UI kodunu olduğu gibi bırakıyorum.
    if (_cameraError) {
      return const Center(child: Text('Kamera başlatılamadı', style: TextStyle(color: Colors.red)));
    }
    return Stack(
      children: [
        if (_cameraInitialized && _cameraController != null)
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.7,
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator()),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
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
                          onPressed: _processing || !_cameraInitialized ? null : _recognizeFace,
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
                            backgroundColor: Colors.deepPurple,
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
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
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
  // DEĞİŞTİRİLDİ
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
      builder: (context) => AddFaceDialog(embeddingService: widget.embeddingService), // DEĞİŞTİRİLDİ
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
  // DEĞİŞTİRİLDİ
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
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
  }

  Future<void> _saveFace() async {
    if (_nameController.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen isim giriniz')),
        );
      }
      return;
    }
    if (_capturedImages.any((img) => img == null)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm pozların fotoğrafını çekiniz')),
        );
      }
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final imagePaths = _capturedImages.map((img) => img!.path).toList();
      final name = _nameController.text.trim();
      final gender = _selectedGender;
      
      List<List<double>> embeddings = [];
      for (var path in imagePaths) {
        // DEĞİŞTİRİLDİ
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yüz başarıyla kaydedildi! Artık bu yüz tanınabilir.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Yüz kaydetme hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yüz kaydedilemedi: $e')),
        );
      }
    } finally {
      if(mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
    // UI kodunu olduğu gibi bırakıyorum.
    final isimGiriliyor = _capturedImages.every((img) => img != null);
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight * 0.98,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _cameraError
                ? const Center(child: Text('Kamera başlatılamadı', style: TextStyle(color: Colors.red)))
                : Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 110),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 32, left: 16, right: 16, bottom: 8),
                                child: Column(
                                  children: [
                                    Text(
                                      !isimGiriliyor
                                          ? 'Yüz Ekleme - ${_poseLabels[_currentStep]}'
                                          : 'Kayıt Tamamlanmak Üzere',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    if (!isimGiriliyor)
                                      LinearProgressIndicator(
                                        value: (_currentStep + 1) / 5,
                                        minHeight: 6,
                                        backgroundColor: Colors.deepPurple.shade50,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              !isimGiriliyor
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (_cameraInitialized && _cameraController != null)
                                          Container(
                                            width: constraints.maxWidth,
                                            height: constraints.maxHeight * 0.58,
                                            margin: const EdgeInsets.symmetric(horizontal: 16),
                                            child: AspectRatio(
                                              aspectRatio: _cameraController!.value.aspectRatio,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: Stack(
                                                  children: [
                                                    CameraPreview(_cameraController!),
                                                    RealTimeQualityOverlay(
                                                      cameraController: _cameraController!,
                                                      isCapturing: _isCapturing,
                                                      onQualityChanged: (canCapture) {
                                                        if(mounted) setState(() => _canCapture = canCapture);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          const Center(child: CircularProgressIndicator()),
                                        if (_capturedImages[_currentStep] != null)
                                          Container(
                                            margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.deepPurple, width: 2),
                                            ),
                                            child: Image.file(
                                              File(_capturedImages[_currentStep]!.path),
                                              fit: BoxFit.cover,
                                              height: 120,
                                            ),
                                          ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _canCapture ? Colors.deepPurple : Colors.grey,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                            elevation: 4,
                                          ),
                                          onPressed: _cameraInitialized && _capturedImages[_currentStep] == null && _canCapture && !_isCapturing ? _captureImage : null,
                                          icon: _isCapturing 
                                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                              : const Icon(Icons.camera_alt, size: 28, color: Colors.white),
                                          label: Text(
                                            _isCapturing 
                                                ? 'Fotoğraf Çekiliyor...'
                                                : '${_poseLabels[_currentStep]} Fotoğrafı Çek',
                                            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(height: 32),
                                          const Text('Lütfen isim giriniz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 24),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(18),
                                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                                            ),
                                            child: TextField(
                                              controller: _nameController,
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                hintText: 'İsim Giriniz',
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                              ),
                                              style: const TextStyle(fontSize: 20),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Radio<String>(
                                                value: 'male',
                                                groupValue: _selectedGender,
                                                onChanged: (val) {
                                                  if(val != null) setState(() => _selectedGender = val);
                                                },
                                              ),
                                              const Text('Erkek'),
                                              SizedBox(width: 24),
                                              Radio<String>(
                                                value: 'female',
                                                groupValue: _selectedGender,
                                                onChanged: (val) {
                                                  if(val != null) setState(() => _selectedGender = val);
                                                },
                                              ),
                                              const Text('Kadın'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${_currentStep + 1}/5 poz tamamlandı', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Vazgeç', style: TextStyle(color: Colors.red, fontSize: 16)),
                                  ),
                                  if (isimGiriliyor)
                                    SizedBox(
                                      width: 140,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        onPressed: _isSaving ? null : _saveFace,
                                        child: _isSaving
                                            ? const CircularProgressIndicator(color: Colors.white)
                                            : const Text(
                                                'Kaydet',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5,
                                                  shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                                                ),
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
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
      debugPrint('Yüzler yüklenemedi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yüzler yüklenemedi')));
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteFace(FaceModel face) async {
    try {
      await FaceDatabaseService.deleteFace(face);
      if (!mounted) return;
      setState(() {
        _faces.remove(face);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yüz silindi')));
    } catch (e) {
      debugPrint('Yüz silinemedi: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yüz silinemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Bu metodun içeriği aynı kalabilir, doğru çalışıyor)
    // UI kodunu olduğu gibi bırakıyorum.
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
              child: Text('Kayıtlı Yüzler', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_loading && _faces.isEmpty)
              const Expanded(child: Center(child: Text('Kayıtlı yüz bulunamadı.'))),
            if (!_loading && _faces.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _faces.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final face = _faces[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: face.imagePaths.isNotEmpty
                            ? CircleAvatar(
                                radius: 28,
                                backgroundImage: FileImage(File(face.imagePaths[0])),
                              )
                            : CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.deepPurple.shade100,
                                child: const Icon(Icons.person, color: Colors.deepPurple, size: 32),
                              ),
                        title: Text(face.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                          tooltip: 'Sil',
                          splashRadius: 24,
                          onPressed: () => _deleteFace(face),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
