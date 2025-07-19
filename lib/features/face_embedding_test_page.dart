import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/face_embedding_service.dart';

class FaceEmbeddingTestPage extends StatefulWidget {
  const FaceEmbeddingTestPage({super.key});

  @override
  State<FaceEmbeddingTestPage> createState() => _FaceEmbeddingTestPageState();
}

class _FaceEmbeddingTestPageState extends State<FaceEmbeddingTestPage> {
  File? _selectedImage;
  List<double>? _embedding;
  String? _error;
  bool _loading = false;
  late FaceEmbeddingService _service;

  @override
  void initState() {
    super.initState();
    _service = FaceEmbeddingService();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() { _loading = true; });
    try {
      await _service.loadModel();
    } catch (e) {
      setState(() { _error = 'Model yüklenemedi: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _pickImage() async {
    setState(() { _error = null; _embedding = null; });
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() { _selectedImage = File(picked.path); });
      await _runEmbedding(File(picked.path));
    } catch (e) {
      setState(() { _error = 'Fotoğraf seçilemedi: $e'; });
    }
  }

  Future<void> _runEmbedding(File image) async {
    setState(() { _loading = true; _embedding = null; _error = null; });
    try {
      final emb = await _service.extractEmbedding(image);
      setState(() { _embedding = emb; });
    } catch (e) {
      setState(() { _error = 'Embedding çıkarılamadı: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Embedding Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _pickImage,
              child: const Text('Galeriden Fotoğraf Seç'),
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              SizedBox(
                height: 200,
                child: Image.file(_selectedImage!, fit: BoxFit.contain),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_embedding != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Embedding (ilk 10):\n${_embedding!.take(10).map((e) => e.toStringAsFixed(4)).join(', ')}',
                  style: const TextStyle(fontSize: 16, color: Colors.green),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
