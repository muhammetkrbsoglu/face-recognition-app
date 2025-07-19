import 'package:http/http.dart' as http;
import '../error_handler.dart';

class DoorService {
  static String esp8266Ip = 'http://192.168.218.38'; // Varsayılan IP

  DoorService() {
    ErrorHandler.debug(
      'DoorService oluşturuldu',
      category: ErrorCategory.system,
      tag: 'SERVICE_INIT',
      metadata: {'esp8266Ip': esp8266Ip},
    );
  }

  Future<void> discoverEsp8266() async {
    // Geçici olarak sabit bir IP adresi kullanılıyor
    esp8266Ip = 'http://192.168.218.38';
    ErrorHandler.debug(
      'ESP8266 IP adresi ayarlandı',
      category: ErrorCategory.network,
      tag: 'IP_DISCOVERY',
      metadata: {'esp8266Ip': esp8266Ip},
    );
  }

  Future<bool> testConnection() async {
    try {
      ErrorHandler.debug(
        'ESP8266 bağlantı testi başlatıldı',
        category: ErrorCategory.network,
        tag: 'CONNECTION_TEST_START',
        metadata: {'esp8266Ip': esp8266Ip},
      );
      
      final response = await http.get(Uri.parse('$esp8266Ip/test'));
      
      if (response.statusCode == 200) {
        ErrorHandler.info(
          'ESP8266 bağlantı testi başarılı',
          category: ErrorCategory.network,
          tag: 'CONNECTION_TEST_SUCCESS',
          metadata: {
            'statusCode': response.statusCode,
            'responseTime': DateTime.now().toIso8601String(),
          },
        );
        return true;
      } else {
        ErrorHandler.warning(
          'ESP8266 bağlantı testi başarısız',
          category: ErrorCategory.network,
          tag: 'CONNECTION_TEST_FAILED',
          metadata: {'statusCode': response.statusCode},
        );
        return false;
      }
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'ESP8266 bağlantı testi sırasında hata',
        category: ErrorCategory.network,
        tag: 'CONNECTION_TEST_ERROR',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> unlockDoor() async {
    ErrorHandler.info(
      'Kapı açma isteği başlatıldı',
      category: ErrorCategory.system,
      tag: 'DOOR_UNLOCK_REQUEST',
      metadata: {'esp8266Ip': esp8266Ip},
    );
    
    try {
      final startTime = DateTime.now();
      final response = await http.get(Uri.parse('$esp8266Ip/unlock'));
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      ErrorHandler.debug(
        'HTTP isteği tamamlandı',
        category: ErrorCategory.network,
        tag: 'HTTP_REQUEST_COMPLETE',
        metadata: {
          'duration': duration.inMilliseconds,
          'statusCode': response.statusCode,
          'responseBody': response.body,
        },
      );

      if (response.statusCode == 200) {
        ErrorHandler.info(
          'Kapı açma isteği başarılı',
          category: ErrorCategory.system,
          tag: 'DOOR_UNLOCK_SUCCESS',
          metadata: {
            'statusCode': response.statusCode,
            'responseTime': duration.inMilliseconds,
          },
        );
        return true;
      } else {
        ErrorHandler.warning(
          'Kapı açma isteği başarısız',
          category: ErrorCategory.system,
          tag: 'DOOR_UNLOCK_FAILED',
          metadata: {'statusCode': response.statusCode},
        );
        return false;
      }
    } catch (e, stackTrace) {
      ErrorHandler.error(
        'Kapı açma isteği sırasında hata',
        category: ErrorCategory.system,
        tag: 'DOOR_UNLOCK_ERROR',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
