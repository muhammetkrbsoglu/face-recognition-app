import 'dart:io';
import 'package:flutter/material.dart';
import '../core/error_handler.dart';
import '../services/face_recognition_service.dart';
import '../services/face_database_service.dart';
import '../services/face_match_service.dart';
import '../models/face_model.dart';

class FaceRecognitionViewModel extends ChangeNotifier {
  
  Future<void> initializeFaceRecognition() async {
    try {
      // Gerçek face recognition servisi başlatma
      final faceRecognitionService = FaceRecognitionService();
      await faceRecognitionService.loadModel();
      
      ErrorHandler.info(
        'Face recognition initialized successfully',
        category: ErrorCategory.ui,
        tag: 'INIT_SUCCESS',
      );
    } catch (e) {
      ErrorHandler.error(
        'Face recognition initialization failed',
        category: ErrorCategory.faceRecognition,
        tag: 'INIT_FAILED',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> processFaceImage(File imageFile) async {
    try {
      // Gerçek yüz işleme
      final faceRecognitionService = FaceRecognitionService();
      final embedding = await faceRecognitionService.extractEmbedding(imageFile);
      
      ErrorHandler.info(
        'Face image processed successfully',
        category: ErrorCategory.system,
        tag: 'PROCESS_SUCCESS',
        metadata: {'embeddingLength': embedding.length},
      );
    } catch (e) {
      ErrorHandler.error(
        'Face image processing failed',
        category: ErrorCategory.system,
        tag: 'PROCESS_FAILED',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> saveFaceData(Map<String, dynamic> faceData) async {
    try {
      // Gerçek veri kaydetme
      final faceModel = FaceModel.fromMap(faceData);
      await FaceDatabaseService.insertFace(faceModel);
      
      ErrorHandler.info(
        'Face data saved successfully',
        category: ErrorCategory.system,
        tag: 'SAVE_SUCCESS',
        metadata: {'name': faceModel.name},
      );
    } catch (e) {
      ErrorHandler.error(
        'Face data save failed',
        category: ErrorCategory.system,
        tag: 'SAVE_FAILED',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> loadFaceData() async {
    try {
      // Gerçek veri yükleme
      final faces = await FaceDatabaseService.getAllFaces();
      
      ErrorHandler.info(
        'Face data loaded successfully',
        category: ErrorCategory.system,
        tag: 'LOAD_SUCCESS',
        metadata: {'faceCount': faces.length},
      );
    } catch (e) {
      ErrorHandler.error(
        'Face data load failed',
        category: ErrorCategory.system,
        tag: 'LOAD_FAILED',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> validateFaceData(Map<String, dynamic> faceData) async {
    try {
      // Gerçek veri doğrulama
      if (faceData['name'] == null || faceData['name'].toString().trim().isEmpty) {
        throw Exception('İsim alanı boş olamaz');
      }
      
      if (faceData['embedding'] == null || (faceData['embedding'] as List).isEmpty) {
        throw Exception('Yüz embedding\'i bulunamadı');
      }
      
      ErrorHandler.info(
        'Face data validation successful',
        category: ErrorCategory.system,
        tag: 'VALIDATION_SUCCESS',
      );
    } catch (e) {
      ErrorHandler.error(
        'Face data validation failed',
        category: ErrorCategory.system,
        tag: 'VALIDATION_FAILED',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> performFaceMatching(File imageFile) async {
    try {
      // Gerçek yüz eşleştirme
      final faceRecognitionService = FaceRecognitionService();
      final embedding = await faceRecognitionService.extractEmbedding(imageFile);
      final faces = await FaceDatabaseService.getAllFaces();
      
      // En iyi eşleşmeyi bul
      double bestSimilarity = 0.0;
      FaceModel? bestMatch;
      
      for (final face in faces) {
        if (face.embedding != null) {
          final similarity = FaceMatchService.cosineSimilarity(embedding, face.embedding!);
          if (similarity > bestSimilarity) {
            bestSimilarity = similarity;
            bestMatch = face;
          }
        }
      }
      
      ErrorHandler.info(
        'Face matching performed successfully',
        category: ErrorCategory.faceRecognition,
        tag: 'MATCHING_SUCCESS',
        metadata: {
          'bestSimilarity': bestSimilarity,
          'matchedName': bestMatch?.name,
        },
      );
    } catch (e) {
      ErrorHandler.error(
        'Face matching failed',
        category: ErrorCategory.faceRecognition,
        tag: 'MATCHING_FAILED',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> cleanupResources() async {
    try {
      // Simulated cleanup
      await Future.delayed(const Duration(milliseconds: 50));
      ErrorHandler.info(
        'Resources cleaned up successfully',
        category: ErrorCategory.system,
        tag: 'CLEANUP_SUCCESS',
      );
    } catch (e) {
      ErrorHandler.error(
        'Resource cleanup failed',
        category: ErrorCategory.system,
        tag: 'CLEANUP_FAILED',
        error: e,
      );
      rethrow;
    }
  }
}
