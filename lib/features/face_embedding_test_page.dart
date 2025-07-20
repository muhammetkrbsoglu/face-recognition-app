import 'dart:typed_data';

import 'package:akilli_kapi_guvenlik_sistemi/core/error_handler.dart';
import 'package:akilli_kapi_guvenlik_sistemi/services/face_embedding_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

class FaceEmbeddingTestPage extends StatefulWidget {
  const FaceEmbeddingTestPage({super.key});

  @override
  State<FaceEmbeddingTestPage> createState() => _FaceEmbeddingTestPageState();
}

class _FaceEmbeddingTestPageState extends State<FaceEmbeddingTestPage> {
  final FaceEmbeddingService _service = FaceEmbeddingService.instance;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Float32List? _embedding;
  bool _isProcessing = false;

  Future<void> _pickAndProcessImage() async {
    setState(() {
      _isProcessing = true;
      _imageFile = null;
      _embedding = null;
    });

    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final file = File(pickedFile.path);
      final imageBytes = await file.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        ErrorHandler.showError(context, 'Geçersiz resim formatı.');
        setState(() => _isProcessing = false);
        return;
      }

      final emb = await _service.getEmbeddingsFromImage(image);

      setState(() {
        _imageFile = file;
        _embedding = emb;
        _isProcessing = false;
      });
    } catch (e, s) {
      ErrorHandler.log('Test sayfasında embedding hatası',
          error: e, stackTrace: s, category: ErrorCategory.faceRecognition);
      ErrorHandler.showError(
          context, 'Embedding çıkarılırken bir hata oluştu: $e');
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Embedding Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_isProcessing)
                const CircularProgressIndicator()
              else if (_imageFile != null)
                Image.file(_imageFile!, height: 200)
              else
                const Text('Test için bir resim seçin.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isProcessing ? null : _pickAndProcessImage,
                child: const Text('Galeriden Resim Seç'),
              ),
              const SizedBox(height: 20),
              if (_embedding != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Embedding Vektörü:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _embedding.toString(),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
