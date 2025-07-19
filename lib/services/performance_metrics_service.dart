import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:system_info2/system_info2.dart'; // Gerçek sistem verileri için eklendi
import '../core/error_handler.dart';

// Diğer enum ve sınıflar aynı kalacak...
enum PerformanceStatus {
  excellent,
  good,
  fair,
  poor,
  critical,
}

class PerformanceReport {
  final double currentFPS;
  final double averageFPS;
  final double currentMemoryMB;
  final double averageMemoryMB;
  final double currentProcessTime;
  final double averageProcessTime;
  final Map<String, OperationMetrics> operationMetrics;
  final PerformanceStatus status;
  final List<String> recommendations;
  final DateTime timestamp;

  PerformanceReport({
    required this.currentFPS,
    required this.averageFPS,
    required this.currentMemoryMB,
    required this.averageMemoryMB,
    required this.currentProcessTime,
    required this.averageProcessTime,
    required this.operationMetrics,
    required this.status,
    required this.recommendations,
    required this.timestamp,
  });
}

class OperationMetrics {
  final String operationName;
  final double averageTime;
  final double minTime;
  final double maxTime;
  final int callCount;
  final double successRate;

  OperationMetrics({
    required this.operationName,
    required this.averageTime,
    required this.minTime,
    required this.maxTime,
    required this.callCount,
    required this.successRate,
  });
}


class PerformanceMetricsService {
  static final PerformanceMetricsService _instance = PerformanceMetricsService._internal();
  factory PerformanceMetricsService() => _instance;
  PerformanceMetricsService._internal();

  final Queue<double> _fpsHistory = Queue<double>();
  final Queue<double> _memoryHistory = Queue<double>();
  final Queue<double> _processTimeHistory = Queue<double>();
  final Map<String, List<double>> _operationTimes = {};
  
  final Map<String, DateTime> _startTimes = {};
  Timer? _metricsTimer;
  
  static const int _maxHistorySize = 100;
  static const Duration _metricsInterval = Duration(seconds: 1);
  
  Function(PerformanceReport)? _onPerformanceReport;
  
  bool _isRunning = false;
  
  DateTime? _lastFrameTime;
  double? _lastProcessTime;

  void startMonitoring({Function(PerformanceReport)? onReport}) {
    if (_isRunning) return;
    
    _onPerformanceReport = onReport;
    _isRunning = true;
    
    _metricsTimer = Timer.periodic(_metricsInterval, (timer) {
      _collectMetrics();
    });
    
    ErrorHandler.info(
      'Performance monitoring started',
      category: ErrorCategory.performance,
      tag: 'MONITORING_STARTED',
    );
  }

  void stopMonitoring() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
    _isRunning = false;
    
    ErrorHandler.info(
      'Performance monitoring stopped',
      category: ErrorCategory.performance,
      tag: 'MONITORING_STOPPED',
    );
  }

  void startOperation(String operationName) {
    _startTimes[operationName] = DateTime.now();
  }

  void endOperation(String operationName, {bool success = true}) {
    final startTime = _startTimes[operationName];
    if (startTime == null) return;
    
    final duration = DateTime.now().difference(startTime).inMicroseconds / 1000.0;
    
    if (!_operationTimes.containsKey(operationName)) {
      _operationTimes[operationName] = [];
    }
    
    _operationTimes[operationName]!.add(duration);
    
    if (_operationTimes[operationName]!.length > _maxHistorySize) {
      _operationTimes[operationName]!.removeAt(0);
    }
    
    _startTimes.remove(operationName);
  }

  void _collectMetrics() {
    try {
      final currentFPS = _calculateCurrentFPS();
      _fpsHistory.add(currentFPS);
      
      // GÜNCELLENDİ: Gerçek hafıza kullanımı
      final currentMemory = _getCurrentMemoryUsage();
      _memoryHistory.add(currentMemory);
      
      final currentProcessTime = _calculateProcessTime();
      _processTimeHistory.add(currentProcessTime);
      
      _limitHistorySize();
      
      final report = _generateReport();
      
      _onPerformanceReport?.call(report);
      
    } catch (e) {
      ErrorHandler.error(
        'Performance metrics collection error',
        category: ErrorCategory.performance,
        tag: 'METRICS_COLLECTION_ERROR',
        error: e,
      );
    }
  }

  double _calculateCurrentFPS() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!).inMicroseconds / 1000000.0;
      if (frameDuration > 0) {
        return 1.0 / frameDuration;
      }
    }
    _lastFrameTime = now;
    return 60.0;
  }

  /// GÜNCELLENDİ: Gerçek hafıza kullanımını MB cinsinden döndürür.
  double _getCurrentMemoryUsage() {
    try {
      final int totalRam = SysInfo.getTotalPhysicalMemory();
      final int freeRam = SysInfo.getFreePhysicalMemory();
      final usedRam = totalRam - freeRam;
      // Bayt'ı Megabayt'a çevir
      return usedRam / (1024 * 1024);
    } catch (e) {
      ErrorHandler.warning(
        'Memory usage calculation failed',
        category: ErrorCategory.performance,
        tag: 'MEMORY_CALCULATION_ERROR',
        metadata: {'error': e.toString()},
      );
      return 0.0;
    }
  }

  double _calculateProcessTime() {
    if (_lastProcessTime != null) {
      return _lastProcessTime!;
    }
    return 16.0;
  }

  void _limitHistorySize() {
    while (_fpsHistory.length > _maxHistorySize) _fpsHistory.removeFirst();
    while (_memoryHistory.length > _maxHistorySize) _memoryHistory.removeFirst();
    while (_processTimeHistory.length > _maxHistorySize) _processTimeHistory.removeFirst();
  }

  PerformanceReport _generateReport() {
    final currentFPS = _fpsHistory.isNotEmpty ? _fpsHistory.last : 0.0;
    final averageFPS = _fpsHistory.isNotEmpty ? _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length : 0.0;
    
    final currentMemory = _memoryHistory.isNotEmpty ? _memoryHistory.last : 0.0;
    final averageMemory = _memoryHistory.isNotEmpty ? _memoryHistory.reduce((a, b) => a + b) / _memoryHistory.length : 0.0;
    
    final currentProcessTime = _processTimeHistory.isNotEmpty ? _processTimeHistory.last : 0.0;
    final averageProcessTime = _processTimeHistory.isNotEmpty ? _processTimeHistory.reduce((a, b) => a + b) / _processTimeHistory.length : 0.0;
    
    final operationMetrics = _calculateOperationMetrics();
    final status = _calculatePerformanceStatus(currentFPS, currentMemory, currentProcessTime);
    final recommendations = _generateRecommendations(status, currentFPS, currentMemory, currentProcessTime);
    
    return PerformanceReport(
      currentFPS: currentFPS,
      averageFPS: averageFPS,
      currentMemoryMB: currentMemory,
      averageMemoryMB: averageMemory,
      currentProcessTime: currentProcessTime,
      averageProcessTime: averageProcessTime,
      operationMetrics: operationMetrics,
      status: status,
      recommendations: recommendations,
      timestamp: DateTime.now(),
    );
  }

  Map<String, OperationMetrics> _calculateOperationMetrics() {
    final metrics = <String, OperationMetrics>{};
    _operationTimes.forEach((key, times) {
      if (times.isEmpty) return;
      final averageTime = times.reduce((a, b) => a + b) / times.length;
      final minTime = times.reduce(min);
      final maxTime = times.reduce(max);
      metrics[key] = OperationMetrics(
        operationName: key,
        averageTime: averageTime,
        minTime: minTime,
        maxTime: maxTime,
        callCount: times.length,
        successRate: 1.0, // Basit başarı oranı
      );
    });
    return metrics;
  }
  
  PerformanceStatus _calculatePerformanceStatus(double fps, double memory, double processTime) {
    int score = 0;
    if (fps >= 55) score += 3;
    else if (fps >= 45) score += 2;
    else if (fps >= 30) score += 1;
    
    if (memory <= 150) score += 3;
    else if (memory <= 250) score += 2;
    else if (memory <= 400) score += 1;
    
    if (processTime <= 16) score += 3;
    else if (processTime <= 33) score += 2;
    else if (processTime <= 50) score += 1;
    
    if (score >= 8) return PerformanceStatus.excellent;
    if (score >= 6) return PerformanceStatus.good;
    if (score >= 4) return PerformanceStatus.fair;
    if (score >= 2) return PerformanceStatus.poor;
    return PerformanceStatus.critical;
  }

  List<String> _generateRecommendations(PerformanceStatus status, double fps, double memory, double processTime) {
    final recommendations = <String>[];
    if (fps < 45) recommendations.add('FPS düşük: Animasyonları optimize edin.');
    if (memory > 250) recommendations.add('Hafıza yüksek: Gereksiz nesneleri temizleyin.');
    if (processTime > 33) recommendations.add('İşlem süresi yüksek: Ağır işlemleri arka plana alın.');
    if (status == PerformanceStatus.critical) recommendations.add('Kritik performans sorunu: Uygulamayı yeniden başlatın.');
    return recommendations;
  }

  // ... (PerformanceDashboard widget'ı aynı kalabilir)
}

// PerformanceDashboard widget'ı (değişiklik yok)
class PerformanceDashboard extends StatelessWidget {
  final PerformanceReport report;
  final VoidCallback? onClose;

  const PerformanceDashboard({
    super.key,
    required this.report,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Performance Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetricRow('FPS', report.currentFPS.toStringAsFixed(1), _getFPSColor(report.currentFPS)),
          _buildMetricRow('Memory', '${report.currentMemoryMB.toStringAsFixed(1)} MB', _getMemoryColor(report.currentMemoryMB)),
          _buildMetricRow('Process Time', '${report.currentProcessTime.toStringAsFixed(1)} ms', _getProcessTimeColor(report.currentProcessTime)),
          _buildMetricRow('Status', report.status.name.toUpperCase(), _getStatusColor(report.status)),
          if (report.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Recommendations:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...report.recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $rec',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getFPSColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 45) return Colors.yellow;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  Color _getMemoryColor(double memory) {
    if (memory <= 150) return Colors.green;
    if (memory <= 250) return Colors.yellow;
    if (memory <= 400) return Colors.orange;
    return Colors.red;
  }

  Color _getProcessTimeColor(double processTime) {
    if (processTime <= 16) return Colors.green;
    if (processTime <= 33) return Colors.yellow;
    if (processTime <= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getStatusColor(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.excellent:
        return Colors.green;
      case PerformanceStatus.good:
        return Colors.lightGreen;
      case PerformanceStatus.fair:
        return Colors.yellow;
      case PerformanceStatus.poor:
        return Colors.orange;
      case PerformanceStatus.critical:
        return Colors.red;
    }
  }
}
