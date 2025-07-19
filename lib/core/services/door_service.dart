import 'dart:async';
import 'package:http/http.dart' as http;
import '../error_handler.dart';
import '../exceptions.dart';

/// ESP8266 ile iletişim kurarak kapı kilidini yöneten servis.
class DoorService {
  // ESP8266'nın IP adresi merkezi bir yerden yönetilir.
  // Bu adres, cihazın bağlı olduğu ağa göre değişebilir.
  static const String _esp8266Ip = '192.168.122.38';
  static const String _unlockEndpoint = '/unlock';
  static final Uri _unlockUri = Uri.http(_esp8266Ip, _unlockEndpoint);
  
  // Ağ istekleri için zaman aşımı süresi.
  static const Duration _requestTimeout = Duration(seconds: 5);

  /// ESP8266'ya kapıyı açması için bir HTTP GET isteği gönderir.
  Future<bool> unlockDoor() async {
    ErrorHandler.info(
      'Kapı açma isteği gönderiliyor...',
      category: ErrorCategory.network,
      tag: 'DOOR_UNLOCK_START',
      metadata: {'uri': _unlockUri.toString()}
    );

    try {
      // Belirlenen adrese GET isteği gönder ve zaman aşımını uygula.
      final response = await http.get(_unlockUri).timeout(_requestTimeout);

      // HTTP durum kodu 200 (OK) ise işlem başarılıdır.
      if (response.statusCode == 200) {
        ErrorHandler.info(
          'Kapı açma isteği başarılı (HTTP 200 OK)',
          category: ErrorCategory.network,
          tag: 'DOOR_UNLOCK_SUCCESS',
        );
        return true;
      } else {
        // Sunucudan beklenmedik bir durum kodu dönerse hata logla.
        ErrorHandler.error(
          'Kapı kilidi sunucusundan beklenmeyen yanıt.',
          category: ErrorCategory.network,
          tag: 'DOOR_UNLOCK_FAIL_STATUS',
          metadata: {'statusCode': response.statusCode, 'body': response.body},
        );
        return false;
      }
    } on TimeoutException catch (e, stackTrace) {
        // İstek zaman aşımına uğrarsa hata logla ve özel bir istisna fırlat.
        ErrorHandler.error(
          'Kapı kilidi sunucusuna bağlanırken zaman aşımı.',
          category: ErrorCategory.network,
          tag: 'DOOR_UNLOCK_TIMEOUT',
          error: e,
          stackTrace: stackTrace,
        );
        throw NetworkException.connectionTimeout();
    } 
    catch (e, stackTrace) {
       // Diğer ağ hatalarını (örn. bağlantı yok) yakala ve logla.
       ErrorHandler.error(
          'Kapı kilidi sunucusuna bağlanırken ağ hatası.',
          category: ErrorCategory.network,
          tag: 'DOOR_UNLOCK_NETWORK_ERROR',
          error: e,
          stackTrace: stackTrace,
        );
       throw NetworkException.requestFailed(_unlockUri.toString(), e.toString());
    }
  }
}
