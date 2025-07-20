import 'dart:async';

import 'package:system_info2/system_info2.dart';

/// Uygulamanın performans metriklerini (FPS, hafıza) izleyen servis.
class PerformanceMetricsService {
  Timer? _timer;
  final StreamController<String> _performanceStreamController =
      StreamController<String>.broadcast();

  /// Performans durumunu dinlemek için kullanılan stream.
  Stream<String> get performanceStream => _performanceStreamController.stream;

  /// Servisi başlatır ve periyodik olarak performans verilerini toplar.
  PerformanceMetricsService() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updatePerformanceMetrics();
    });
  }

  /// Anlık performans metriklerini günceller ve stream'e gönderir.
  void _updatePerformanceMetrics() {
    try {
      final int totalMem = SysInfo.getTotalPhysicalMemory();
      final int freeMem = SysInfo.getFreePhysicalMemory();
      final int usedMem = totalMem - freeMem;
      final double usedMemPercent = (usedMem / totalMem) * 100;

      final status =
          'RAM: ${usedMemPercent.toStringAsFixed(1)}% (${(usedMem / 1024).toStringAsFixed(0)}MB)';
      
      if (!_performanceStreamController.isClosed) {
        _performanceStreamController.add(status);
      }
    } catch (e) {
      // Hata durumunda stream'e bilgi gönderilebilir.
      if (!_performanceStreamController.isClosed) {
         _performanceStreamController.add('RAM: N/A');
      }
    }
  }

  /// Servisi sonlandırır ve kaynakları serbest bırakır.
  void dispose() {
    _timer?.cancel();
    _performanceStreamController.close();
  }
}
