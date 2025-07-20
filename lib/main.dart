import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:akilli_kapi_guvenlik_sistemi/core/error_handler.dart';
import 'package:akilli_kapi_guvenlik_sistemi/core/services/door_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/features/face_embedding_test_page.dart';
import 'package:akilli_kapi_guvenlik_sistemi/features/profile_view.dart';
import 'package:akilli_kapi_guvenlik_sistemi/models/face_model.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_database_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_embedding_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_match_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/performance_metrics_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/real_time_quality_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/utils/face_file_service.dart';
import 'package:akilli_kapi_guvenlik_sistemi/widgets/enhanced_animations.dart';
import 'package:akilli_kapi_guvenlik_sistemi/widgets/real_time_quality_overlay.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _cameras = await availableCameras();
    // Servislerin başlatılması
    await ErrorHandler.initialize(logToFile: true);
    await FaceDatabaseService.instance.initialize();
    await FaceEmbeddingService.instance.initialize();
  } on CameraException catch (e, s) {
    ErrorHandler.log(
      'Kamera başlatılamadı. Uygulama için kritik bir hata.',
      error: e,
      stackTrace: s,
      level: LogLevel.critical,
      category: ErrorCategory.camera,
    );
  } catch (e, s) {
    ErrorHandler.log(
      'Uygulama başlatılırken genel bir hata oluştu.',
      error: e,
      stackTrace: s,
      level: LogLevel.critical,
      category: ErrorCategory.general,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yüz Tanıma Güvenlik Sistemi',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FaceDatabaseService _dbService = FaceDatabaseService.instance;
  final PerformanceMetricsService _performanceMetricsService =
      PerformanceMetricsService();
  final FaceMatchService _faceMatchService = FaceMatchService();
  final FaceEmbeddingService _faceEmbeddingService = FaceEmbeddingService.instance;

  List<FaceModel> _registeredFaces = [];
  String? _performanceStatus;
  CameraDescription? _frontCamera;

  @override
  void initState() {
    super.initState();
    _initializePerformanceMonitor();
    _findFrontCamera();
    _loadRegisteredFaces();
  }

  @override
  void dispose() {
    _performanceMetricsService.dispose();
    super.dispose();
  }

  void _findFrontCamera() {
     if (_cameras.isEmpty) {
      ErrorHandler.showError(context, 'Kamera bulunamadı.');
      return;
    }
    _frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first);
  }

  void _initializePerformanceMonitor() {
    _performanceMetricsService.performanceStream.listen((status) {
      if (mounted) {
        setState(() {
          _performanceStatus = status;
        });
      }
    });
  }

  Future<void> _loadRegisteredFaces() async {
    try {
      final faces = await _dbService.getAllFaces();
      setState(() {
        _registeredFaces = faces;
      });
    } catch (e, s) {
      ErrorHandler.log('Kayıtlı yüzler yüklenemedi',
          error: e, stackTrace: s, category: ErrorCategory.database);
      ErrorHandler.showError(context, 'Veritabanından yüzler okunamadı.');
    }
  }

  Future<void> _deleteFace(int id) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kaydı Sil'),
          content: const Text('Bu kişiyi silmek istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteFace(id);
        ErrorHandler.showSuccess(context, 'Kayıt başarıyla silindi.');
        _loadRegisteredFaces();
      } catch (e, s) {
        ErrorHandler.log('Yüz silinemedi',
            error: e, stackTrace: s, category: ErrorCategory.database);
        ErrorHandler.showError(context, 'Kayıt silinirken bir hata oluştu.');
      }
    }
  }

  Future<img.Image?> _cropFace(CameraImage image, Face face) async {
    try {
      final convertedImage = await _convertCameraImage(image);
      if (convertedImage == null) return null;

      final boundingBox = face.boundingBox;
      final x = boundingBox.left.toInt().clamp(0, convertedImage.width);
      final y = boundingBox.top.toInt().clamp(0, convertedImage.height);
      final w = boundingBox.width.toInt().clamp(0, convertedImage.width - x);
      final h = boundingBox.height.toInt().clamp(0, convertedImage.height - y);

      return img.copyCrop(convertedImage, x: x, y: y, width: w, height: h);
    } catch (e, s) {
      ErrorHandler.log('Yüz kırpma hatası',
          error: e, stackTrace: s, category: ErrorCategory.imageProcessing);
      return null;
    }
  }

  Future<img.Image?> _convertCameraImage(CameraImage image) async {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        // HATA DÜZELTMESİ: ycrcb -> luminance
        // YUV formatının ilk düzlemi (Y plane) parlaklık (luminance) bilgisini içerir
        // ve bu, yüz tanıma için yeterli olan bir grayscale görüntü sağlar.
        return img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order: img.ChannelOrder.luminance,
        );
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      }
      ErrorHandler.log('Desteklenmeyen görüntü formatı: ${image.format.group}');
      return null;
    } catch (e, s) {
      ErrorHandler.log('CameraImage dönüştürme hatası',
          error: e, stackTrace: s, category: ErrorCategory.imageProcessing);
      return null;
    }
  }

  Future<void> _registerFace(
      String name, String gender, CameraImage image, Face face) async {
    try {
      final stopwatch = Stopwatch()..start();

      final croppedFace = await _cropFace(image, face);
      if (croppedFace == null) {
        ErrorHandler.showError(context, 'Yüz kırpılamadı.');
        return;
      }

      final qualityResult =
          RealTimeQualityService.analyzeImageQuality(croppedFace);
      log('Kayıt için son kalite kontrolü: ${qualityResult.status}, Skor: ${qualityResult.score}');
      if (qualityResult.status == ImageQualityStatus.Poor) {
        ErrorHandler.showError(context,
            'Düşük görüntü kalitesi nedeniyle kayıt yapılamadı. Lütfen daha aydınlık bir ortamda tekrar deneyin.');
        return;
      }

      final embeddings =
          await _faceEmbeddingService.getEmbeddingsFromImage(croppedFace);
      if (embeddings == null) {
        ErrorHandler.showError(context, 'Yüz vektörleri oluşturulamadı.');
        return;
      }

      final faceImagePath =
          await FaceFileService.saveFaceImage(croppedFace, name);

      final newFace = FaceModel(
        name: name,
        gender: gender,
        imagePath: faceImagePath,
        embeddings: embeddings,
      );

      await _dbService.insertFace(newFace);
      stopwatch.stop();
      ErrorHandler.showSuccess(context,
          '$name başarıyla kaydedildi! (${stopwatch.elapsedMilliseconds}ms)');
      _loadRegisteredFaces();
    } catch (e, s) {
      ErrorHandler.log('Yüz kayıt hatası',
          error: e, stackTrace: s, category: ErrorCategory.database);
      ErrorHandler.showError(
          context, 'Kayıt sırasında bir hata oluştu: ${e.toString()}');
    }
  }

  Future<void> _recognizeFace(CameraImage image, Face face) async {
    Navigator.of(context).pop(); // Tarayıcıyı kapat
    final stopwatch = Stopwatch()..start();

    try {
      final croppedFace = await _cropFace(image, face);
      if (croppedFace == null) {
        ErrorHandler.showError(context, 'Tanınacak yüz işlenemedi.');
        return;
      }

      final liveEmbeddings =
          await _faceEmbeddingService.getEmbeddingsFromImage(croppedFace);
      if (liveEmbeddings == null) {
        ErrorHandler.showError(context, 'Anlık yüz vektörleri alınamadı.');
        return;
      }

      if (_registeredFaces.isEmpty) {
        ErrorHandler.showError(context, 'Veritabanında kayıtlı yüz yok.');
        return;
      }

      final matchResult =
          _faceMatchService.findBestMatch(liveEmbeddings, _registeredFaces);

      stopwatch.stop();
      log('Tanıma süresi: ${stopwatch.elapsedMilliseconds}ms');

      if (matchResult.bestMatch != null && matchResult.confidence > 0.85) {
        // Eşleşme bulundu
        _showMatchResultDialog(matchResult.bestMatch!, matchResult.confidence);
      } else {
        // Eşleşme bulunamadı
        _showMatchResultDialog(null, 0);
      }
    } catch (e, s) {
      ErrorHandler.log('Yüz tanıma hatası',
          error: e, stackTrace: s, category: ErrorCategory.faceRecognition);
      ErrorHandler.showError(context, 'Tanıma sırasında bir hata oluştu.');
    }
  }

  void _showMatchResultDialog(FaceModel? matchedFace, double confidence) {
    showDialog(
      context: context,
      builder: (context) {
        final bool isMatch = matchedFace != null;
        return AlertDialog(
          title: Text(isMatch ? 'Yüz Tanındı' : 'Yüz Tanınamadı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMatch)
                ProfilePicture(
                    imagePath: matchedFace.imagePath, radius: 50)
              else
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                isMatch
                    ? 'Hoşgeldin, ${matchedFace.name}!'
                    : 'Sistemde kayıtlı bir eşleşme bulunamadı.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              if (isMatch)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Benzerlik: ${(confidence * 100).toStringAsFixed(2)}%',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
          actions: [
            if (isMatch)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await DoorService.openDoor();
                    ErrorHandler.showSuccess(context, 'Kapı kilidi açıldı!');
                  } catch (e) {
                    ErrorHandler.showError(context,
                        'Kapı kilidiyle iletişim kurulamadı: ${e.toString()}');
                  }
                },
                child: const Text('Kapıyı Aç'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  void _showFaceScanner() {
    if (_frontCamera == null) {
      ErrorHandler.showError(context, 'Ön kamera bulunamadı veya hazır değil.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
          ),
          child: RealTimeQualityOverlay(
            cameraDescription: _frontCamera!,
            onFaceVerified: (image, face) {
              _recognizeFace(image, face);
            },
          ),
        ),
      ),
    );
  }

  void _showFaceRegistrationScanner() {
    if (_frontCamera == null) {
      ErrorHandler.showError(context, 'Ön kamera bulunamadı veya hazır değil.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
          ),
          child: RealTimeQualityOverlay(
            cameraDescription: _frontCamera!,
            onFaceVerified: (image, face) {
              Navigator.of(context).pop(); // Tarayıcıyı kapat
              _showRegistrationDialog(image, face);
            },
          ),
        ),
      ),
    );
  }

  void _showRegistrationDialog(CameraImage image, Face face) {
    final nameController = TextEditingController();
    String selectedGender = 'Erkek';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Yeni Kişi Kaydet'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'İsim Soyisim'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir isim girin.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: 'Cinsiyet'),
                      items: ['Erkek', 'Kadın']
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedGender = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop();
                      _registerFace(nameController.text, selectedGender, image, face);
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetim Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.biotech),
            tooltip: 'Embedding Test',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const FaceEmbeddingTestPage(),
              ));
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                _performanceStatus ?? '...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _registeredFaces.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sistemde kayıtlı kimse bulunmuyor.',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showFaceRegistrationScanner,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('İlk Kişiyi Ekle'),
                  )
                ],
              ),
            )
          : ListView.builder(
              itemCount: _registeredFaces.length,
              itemBuilder: (context, index) {
                final face = _registeredFaces[index];
                return SlideInAnimation(
                  delay: Duration(milliseconds: 100 * (index % 10)),
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: ProfilePicture(imagePath: face.imagePath),
                      title: Text(face.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(face.gender),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteFace(face.id!),
                      ),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ProfileView(profile: face),
                        ));
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFaceScanner,
        label: const Text('Kapıyı Aç'),
        icon: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Yeni Kişi Ekle',
              onPressed: _showFaceRegistrationScanner,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Listeyi Yenile',
              onPressed: _loadRegisteredFaces,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePicture extends StatelessWidget {
  final String imagePath;
  final double radius;

  const ProfilePicture({super.key, required this.imagePath, this.radius = 30});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: FileImage(File(imagePath)),
      onBackgroundImageError: (exception, stackTrace) {
        ErrorHandler.log('Profil resmi yüklenemedi: $imagePath',
            error: exception, stackTrace: stackTrace);
      },
    );
  }
}
