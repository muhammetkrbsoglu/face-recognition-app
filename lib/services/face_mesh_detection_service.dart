import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:flutter/material.dart';
import '../core/error_handler.dart';

/// Face mesh tespiti sonucu
class FaceMeshResult {
  final List<FaceMesh> meshes;
  final bool hasFaceMesh;
  final String message;
  final List<Point<int>> contourPoints;
  final double quality;
  final Map<String, dynamic> meshMetrics;

  FaceMeshResult({
    required this.meshes,
    required this.hasFaceMesh,
    required this.message,
    required this.contourPoints,
    required this.quality,
    required this.meshMetrics,
  });
}

/// Advanced face mesh detection servisi
class FaceMeshDetectionService {
  static final FaceMeshDetectionService _instance = FaceMeshDetectionService._internal();
  factory FaceMeshDetectionService() => _instance;
  FaceMeshDetectionService._internal();

  FaceMeshDetector? _faceMeshDetector;
  bool _isInitialized = false;

  /// Face mesh detector'ı başlat
  Future<void> initialize() async {
    try {
      // Face mesh detection geçici olarak devre dışı
      _isInitialized = false;
      ErrorHandler.info(
        'Face Mesh Detection Service disabled for now',
        category: ErrorCategory.faceRecognition,
        tag: 'FACE_MESH_INIT_SUCCESS',
      );
    } catch (e) {
      ErrorHandler.error(
        'Face Mesh Detection Service failed to initialize',
        category: ErrorCategory.faceRecognition,
        tag: 'FACE_MESH_INIT_FAILED',
        error: e,
      );
      rethrow;
    }
  }

  /// Face mesh tespiti yap
  Future<FaceMeshResult> detectFaceMesh(File imageFile) async {
    if (!_isInitialized || _faceMeshDetector == null) {
      return FaceMeshResult(
        meshes: [],
        hasFaceMesh: false,
        message: 'Face mesh detector not initialized',
        contourPoints: [],
        quality: 0.0,
        meshMetrics: {},
      );
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final meshes = await _faceMeshDetector!.processImage(inputImage);
      
      if (meshes.isEmpty) {
        return FaceMeshResult(
          meshes: [],
          hasFaceMesh: false,
          message: '🚫 Face mesh not detected',
          contourPoints: [],
          quality: 0.0,
          meshMetrics: {},
        );
      }

      // İlk mesh'i analiz et
      final primaryMesh = meshes.first;
      final quality = _calculateMeshQuality(primaryMesh);
      final contourPoints = _extractContourPoints(primaryMesh);
      final metrics = _calculateMeshMetrics(primaryMesh);

      return FaceMeshResult(
        meshes: meshes,
        hasFaceMesh: true,
        message: _generateQualityMessage(quality),
        contourPoints: contourPoints,
        quality: quality,
        meshMetrics: metrics,
      );

    } catch (e) {
      ErrorHandler.error(
        'Face mesh detection error',
        category: ErrorCategory.faceRecognition,
        tag: 'FACE_MESH_DETECTION_ERROR',
        error: e,
      );
      return FaceMeshResult(
        meshes: [],
        hasFaceMesh: false,
        message: 'Face mesh detection failed: $e',
        contourPoints: [],
        quality: 0.0,
        meshMetrics: {},
      );
    }
  }

  /// Mesh kalitesi hesapla
  double _calculateMeshQuality(FaceMesh mesh) {
    double quality = 0.0;
    int checks = 0;

    // 1. Contour coverage kontrolü
    if (mesh.contours.isNotEmpty) {
      quality += 40.0;
    }
    checks++;

    // 2. Triangle count kontrolü
    final triangleCount = mesh.triangles.length;
    if (triangleCount > 100) {
      quality += 30.0;
    } else if (triangleCount > 50) {
      quality += 20.0;
    } else if (triangleCount > 20) {
      quality += 10.0;
    }
    checks++;

    // 3. Bounding box kontrolü
    final boundingBox = mesh.boundingBox;
    final area = boundingBox.width * boundingBox.height;
    if (area > 10000) {
      quality += 30.0;
    } else if (area > 5000) {
      quality += 20.0;
    } else if (area > 2000) {
      quality += 10.0;
    }
    checks++;

    return quality / checks;
  }

  /// Contour points çıkart
  List<Point<int>> _extractContourPoints(FaceMesh mesh) {
    List<Point<int>> allPoints = [];
    
    for (final contour in mesh.contours.values) {
      if (contour != null && contour.isNotEmpty) {
        for (final point in contour) {
          allPoints.add(Point(point.x.round(), point.y.round()));
        }
      }
    }
    
    return allPoints;
  }

  /// Mesh metrikleri hesapla
  Map<String, dynamic> _calculateMeshMetrics(FaceMesh mesh) {
    return {
      'triangleCount': mesh.triangles.length,
      'contourTypes': mesh.contours.length,
      'boundingBoxArea': mesh.boundingBox.width * mesh.boundingBox.height,
      'centerPoint': {
        'x': mesh.boundingBox.left + mesh.boundingBox.width / 2,
        'y': mesh.boundingBox.top + mesh.boundingBox.height / 2,
      },
    };
  }

  /// Kalite mesajı oluştur
  String _generateQualityMessage(double quality) {
    if (quality >= 80.0) {
      return '✨ Excellent mesh quality detected';
    } else if (quality >= 60.0) {
      return '👍 Good mesh quality';
    } else if (quality >= 40.0) {
      return '⚠️ Fair mesh quality';
    } else {
      return '❌ Poor mesh quality';
    }
  }

  /// Servisi kapat
  void dispose() {
    _faceMeshDetector?.close();
    _faceMeshDetector = null;
    _isInitialized = false;
  }
}

/// Face mesh overlay painter
class FaceMeshPainter extends CustomPainter {
  final List<FaceMesh> meshes;
  final Size imageSize;
  final bool showTriangles;
  final bool showContours;

  FaceMeshPainter({
    required this.meshes,
    required this.imageSize,
    this.showTriangles = false,
    this.showContours = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final contourPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final mesh in meshes) {
      // Triangles çiz
      if (showTriangles) {
        for (final triangle in mesh.triangles) {
          _drawTriangle(canvas, triangle, paint, size);
        }
      }

      // Contours çiz
      if (showContours) {
        for (final contour in mesh.contours.values) {
          if (contour != null && contour.isNotEmpty) {
            final points = contour.map((p) => Point(p.x.round(), p.y.round())).toList();
            _drawContour(canvas, points, contourPaint, size);
          }
        }
      }
    }
  }

  void _drawTriangle(Canvas canvas, FaceMeshTriangle triangle, Paint paint, Size size) {
    final path = Path();
    
    if (triangle.points.length < 3) return;
    
    final p1 = _scalePoint(_convertFaceMeshPoint(triangle.points[0]), size);
    final p2 = _scalePoint(_convertFaceMeshPoint(triangle.points[1]), size);
    final p3 = _scalePoint(_convertFaceMeshPoint(triangle.points[2]), size);

    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawContour(Canvas canvas, List<Point<int>> points, Paint paint, Size size) {
    if (points.length < 2) return;

    final path = Path();
    final firstPoint = _scalePoint(points.first, size);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < points.length; i++) {
      final point = _scalePoint(points[i], size);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, paint);
  }

  Offset _scalePoint(Point<int> point, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    
    return Offset(
      point.x * scaleX,
      point.y * scaleY,
    );
  }

  Point<int> _convertFaceMeshPoint(FaceMeshPoint faceMeshPoint) {
    return Point(faceMeshPoint.x.round(), faceMeshPoint.y.round());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 