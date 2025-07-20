import 'dart:async';
import 'dart:io';

import 'package:akilli_kapi_guvenlik_sistemi/core/error_handler.dart';
import 'package:akilli_kapi_guvenlik_sistemi/core/exceptions.dart';
import 'package:http/http.dart' as http;

/// Kapı kilidi donanımıyla (Raspberry Pi, ESP8266 vb.) iletişim kuran servis.
class DoorService {
  // Bu IP adresini kendi donanımınızın IP adresi ile değiştirin.
  static const String _doorControllerIp = '192.168.1.100';
  static const int _timeoutSeconds = 5;

  /// Kapıyı açmak için donanıma bir HTTP isteği gönderir.
  static Future<void> openDoor() async {
    final uri = Uri.http(_doorControllerIp, '/open');
    ErrorHandler.log('Kapı açma isteği gönderiliyor: $uri',
        level: LogLevel.info, category: ErrorCategory.network);

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        ErrorHandler.log('Kapı başarıyla açıldı.',
            level: LogLevel.info, category: ErrorCategory.network);
        // Başarılı yanıtı işle
      } else {
        ErrorHandler.log(
            'Kapı kontrolcüsünden beklenmedik durum kodu: ${response.statusCode}',
            level: LogLevel.error,
            category: ErrorCategory.network);
        throw NetworkException(
            message: 'Kapı kontrolcüsü beklenmedik bir yanıt verdi.');
      }
    } on TimeoutException catch (e, s) {
      ErrorHandler.log('Kapı kontrolcüsüne bağlanırken zaman aşımı.',
          error: e, stackTrace: s, category: ErrorCategory.network);
      throw NetworkException(
          message:
              'Kapı kontrolcüsüne ulaşılamadı. Lütfen ağ bağlantısını kontrol edin.');
    } on SocketException catch (e, s) {
      ErrorHandler.log('Soket hatası: Kapı kontrolcüsüne bağlanılamadı.',
          error: e, stackTrace: s, category: ErrorCategory.network);
      throw NetworkException(
          message:
              'Kapı kontrolcüsüne bağlanılamadı. Cihazın açık ve ağa bağlı olduğundan emin olun.');
    } catch (e, s) {
      ErrorHandler.log('Kapı açma sırasında genel bir hata oluştu.',
          error: e, stackTrace: s, category: ErrorCategory.network);
      throw NetworkException(
          message: 'Kapıyı açarken bilinmeyen bir hata oluştu.');
    }
  }
}
