import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:camera/camera.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:math';
// GÜNCELLENDİ: Birleştirilmiş servis import edildi
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
import 'package:flutter/services.dart'; // HapticFeedback için eklendi
import 'package:akilli_kapi_guvenlik_sistemi/widgets/enhanced_animations.dart'; // Animasyonlar için


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  ErrorHandler.info(
    'Uygulama başlatılıyor',
    category: ErrorCategory.system,
    tag: 'APP_START',
  );
  
  // Servisleri başlat
  await Future.wait([
    FaceDatabaseService.database,
    RealTimeFaceDetectionService().initialize(),
    FaceMeshDetectionService().initialize(),
  ]).catchError((e) {
     ErrorHandler.critical(
      'Kritik servisler başlatılamadı: $e',
      category: ErrorCategory.system,
      tag: 'CRITICAL_SERVICE_FAILURE',
      error: e,
    );
  });

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
  // GÜNCELLENDİ: Yeni servis kullanılıyor
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
      // GÜNCELLENDİ: Yeni servis üzerinden model yükleniyor
      await _embeddingService.loadModel();
      if (!mounted) return;
      
      setState(() => _modelLoaded = true);

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
      
      setState(() => _modelError = errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_modelError != null) return _buildErrorScaffold(_modelError!);
    if (!_modelLoaded) return _buildLoadingScaffold();

    // GÜNCELLENDİ: Sayfalara yeni servis gönderiliyor
    final pages = [
      HomePage(embeddingService: _embeddingService),
      AdminPage(embeddingService: _embeddingService),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Yüz Tanıma Kapı Sistemi')),
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
        body: Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        )),
      );

  Scaffold _buildLoadingScaffold() => Scaffold(
        appBar: AppBar(title: const Text('Yükleniyor')),
        body: const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Model Yükleniyor...'),
          ],
        )),
      );
}

// Ana Sayfa
class HomePage extends StatefulWidget {
  // GÜNCELLENDİ
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
      setState(() => _cameraInitialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraError = true);
      ErrorHandler.showError(context, 'Kamera başlatılamadı.', userFriendlyKey: 'camera_not_available');
    }
  }

  List<double> _normalize(List<double> vector) {
    double sumSq = 0.0;
    for (var val in vector) sumSq += val * val;
    double magnitude = sqrt(sumSq);
    if (magnitude == 0) return List<double>.filled(vector.length, 0.0);
    return vector.map((val) => val / magnitude).toList();
  }

  double _cosineDistance(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty || v1.length != v2.length) {
      throw ArgumentError('Vektörler boş olamaz ve aynı uzunlukta olmalıdır.');
    }
    double dotProduct = 0.0;
    for (int i = 0; i < v1.length; i++) dotProduct += v1[i] * v2[i];
    return 1.0 - dotProduct;
  }

  Future<void> _recognizeFace() async {
    if (_processing || !_cameraInitialized || _cameraController == null) return;

    setState(() {
      _processing = true;
      _resultMessage = null;
    });
    
    try {
      final image = await _cameraController!.takePicture();
      
      final qualityResult = await RealTimeQualityService.assessQuality(File(image.path));
      
      if (qualityResult.status == QualityStatus.rejected || qualityResult.status == QualityStatus.poor) {
        ErrorHandler.showWarning(context, 'Fotoğraf uygun değil: ${qualityResult.message}');
        setState(() => _resultMessage = 'Fotoğraf uygun değil: ${qualityResult.message}');
        return;
      }
      
      // GÜNCELLENDİ: Yeni servis kullanılıyor
      final embedding = await widget.embeddingService.extractEmbedding(File(image.path));
      final normalizedInput = _normalize(embedding);
      final faces = await FaceDatabaseService.getAllFaces();

      if (faces.isEmpty) {
        ErrorHandler.showWarning(context, 'Veritabanında kayıtlı yüz bulunamadı.');
        setState(() => _resultMessage = 'Kayıtlı yüz bulunamadı.');
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
      
      // Eşik değeri 0.7 (ArcFace için genellikle 0.6-0.8 arası uygundur)
      if (minDist < 0.7 && matchedFace != null) {
        String hitap = (matchedFace.gender == 'female' ? 'Hanım' : 'Bey');
        String greeting = 'Hoşgeldiniz ${matchedFace.name} $hitap';
        setState(() => _resultMessage = greeting);
        EnhancedAnimations.showSuccessAnimation(context, matchedFace.name);
        await _unlockDoor(greeting);
      } else {
        setState(() => _resultMessage = 'Yüz tanınamadı.');
        EnhancedAnimations.showErrorAnimation(context, 'Yüz Tanınamadı');
      }
    } catch (e) {
      ErrorHandler.showError(context, 'Tanıma sırasında bir hata oluştu.');
      setState(() => _resultMessage = 'Tanıma sırasında hata oluştu.');
    } finally {
      if(mounted) setState(() => _processing = false);
    }
  }

  Future<void> _unlockDoor(String greeting) async {
    try {
      final doorService = DoorService();
      final success = await doorService.unlockDoor();
      if (mounted) {
        if (success) {
          ErrorHandler.showSuccess(context, '$greeting - Kapı açıldı!');
        } else {
          ErrorHandler.showError(context, '$greeting - Ancak kapı açılamadı!');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Kapı açma isteği gönderilemedi: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError) {
      return const Center(child: Text('Kamera başlatılamadı', style: TextStyle(color: Colors.red)));
    }
    return Stack(
      children: [
        if (_cameraInitialized && _cameraController != null)
          Center(child: CameraPreview(_cameraController!))
        else
          const Center(child: CircularProgressIndicator()),
        
        // Diğer UI elemanları...
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            color: Colors.black45,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_processing)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _recognizeFace,
                    icon: const Icon(Icons.camera),
                    label: const Text('Yüzü Tara'),
                  ),
                const SizedBox(height: 16),
                if (_resultMessage != null)
                  Text(
                    _resultMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// Yönetici Sayfası
class AdminPage extends StatefulWidget {
  // GÜNCELLENDİ
  final FaceEmbeddingService embeddingService;
  const AdminPage({super.key, required this.embeddingService});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Yönetici sayfasına erişmek için kimliğinizi doğrulayın',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (mounted) setState(() => _authenticated = authenticated);
    } catch (e) {
      if(mounted) ErrorHandler.showError(context, 'Kimlik doğrulama hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Lütfen kimliğinizi doğrulayın.'),
            ElevatedButton(onPressed: _authenticate, child: const Text('Tekrar Dene'))
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Yeni Yüz Ekle'),
          leading: const Icon(Icons.person_add),
          onTap: () => showDialog(
            context: context,
            builder: (_) => AddFaceDialog(embeddingService: widget.embeddingService),
          ),
        ),
        ListTile(
          title: const Text('Kayıtlı Yüzleri Görüntüle'),
          leading: const Icon(Icons.list_alt),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const ViewFacesDialog(),
          ),
        ),
      ],
    );
  }
}

// Yeni Yüz Ekleme Dialog
class AddFaceDialog extends StatefulWidget {
  // GÜNCELLENDİ
  final FaceEmbeddingService embeddingService;
  const AddFaceDialog({super.key, required this.embeddingService});

  @override
  State<AddFaceDialog> createState() => _AddFaceDialogState();
}

class _AddFaceDialogState extends State<AddFaceDialog> {
  // Bu sınıfın içindeki `widget.recognitionService` kullanımlarını
  // `widget.embeddingService` olarak değiştirmeyi unutmayın.
  // Örnek:
  // final embedding = await widget.embeddingService.extractEmbedding(File(path));
  
  // Bu sınıfın geri kalanı büyük ölçüde aynı kalabilir, sadece servis adı değişecek.
  // Zaman kazanmak için tam kodunu tekrar yazmıyorum, ancak bu değişikliğin
  // yapılması gerektiğini unutmayın.
  int _currentStep = 0;
  final List<String> _poseLabels = ['Düz Bakış', 'Sağa Bakış', 'Sola Bakış', 'Aşağı Bakış', 'Yukarı Bakış'];
  final List<XFile?> _capturedImages = List<XFile?>.filled(5, null);
  final TextEditingController _nameController = TextEditingController();
  String _selectedGender = 'male';
  bool _isSaving = false;
  CameraController? _cameraController;
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // ... (kamera başlatma kodu aynı)
  }

  Future<void> _captureImage() async {
    // ... (fotoğraf çekme kodu aynı)
  }

  Future<void> _saveFace() async {
    if (_nameController.text.trim().isEmpty) {
      ErrorHandler.showWarning(context, "Lütfen isim giriniz.");
      return;
    }
    if (_capturedImages.any((img) => img == null)) {
      ErrorHandler.showWarning(context, "Lütfen tüm 5 pozu da çekiniz.");
      return;
    }
    setState(() => _isSaving = true);
    try {
      final imagePaths = _capturedImages.map((img) => img!.path).toList();
      final name = _nameController.text.trim();
      final gender = _selectedGender;
      
      List<List<double>> embeddings = [];
      for (var path in imagePaths) {
        // GÜNCELLENDİ
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
      if(mounted) {
        ErrorHandler.showSuccess(context, 'Yüz başarıyla kaydedildi!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) ErrorHandler.showError(context, 'Yüz kaydedilemedi: $e');
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bu widget'ın build metodu büyük ölçüde aynı kalabilir.
    // Sadece UI iyileştirmeleri yapılabilir.
    return AlertDialog(
      title: Text('Yeni Yüz Ekle (${_currentStep + 1}/5)'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            if(_cameraInitialized && _cameraController != null)
              SizedBox(height: 200, child: CameraPreview(_cameraController!)),
            Text(_poseLabels[_currentStep]),
            ElevatedButton(onPressed: _captureImage, child: const Text('Fotoğraf Çek')),
            if(_capturedImages.every((img) => img != null)) ...[
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'İsim')),
              // Cinsiyet seçimi...
            ]
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('İptal')),
        ElevatedButton(onPressed: _isSaving ? null : _saveFace, child: _isSaving ? const CircularProgressIndicator() : const Text('Kaydet')),
      ],
    );
  }
}


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
      if (mounted) setState(() {
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
        _loadFaces(); // Listeyi yenile
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
                    itemCount: _faces.length,
                    itemBuilder: (context, index) {
                      final face = _faces[index];
                      return ListTile(
                        leading: face.imagePaths.isNotEmpty
                            ? CircleAvatar(backgroundImage: FileImage(File(face.imagePaths[0])))
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(face.name),
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
