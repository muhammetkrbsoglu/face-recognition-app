
# Yüz Tanıma Kapı Açma Sistemi

Bu uygulama Flutter ile geliştirilmiş, ArcFace ve TFLite tabanlı bir yüz tanıma sistemidir. Tüm veriler ve yüz embedding'leri cihazda yerel olarak saklanır. Uygulama tamamen Türkçe arayüz ve mesajlar ile çalışır.

## Özellikler
- Kamera ile yüz tanıma ve kapı açma
- Yönetici kimlik doğrulama (parmak izi/yüz)
- Farklı pozlarda yüz kaydı (5 fotoğraf)
- Kayıtlı yüzleri listeleme, yeniden adlandırma, silme
- Tüm işlemler sonrası Türkçe ve modern geri bildirim (animasyon, banner, modal)
- Dark Mode desteği
- Haptic feedback (titreşim)
- GPU delegate ile hızlı TFLite inference
- Eşleşme skoru ve KNN karşılaştırma
- Arka planda (isolate) yüz tanıma
- PIN ile yönetici yedek giriş
- Silme/yeniden adlandırma onayı
- SQLite şifreleme
- Splash login ekranı
- Merkezi hata yönetimi ve yapılandırılmış logger
- Servisler için unit test
- Yüz dosyalarını klasörlerde saklama
- Kullanıcı profil görünümü
- Rol tabanlı erişim (admin/guest)
- Raspberry Pi HTTP log entegrasyonu
- Flutter Web/Desktop desteği
- MVVM/Modüler mimari

## Gereksinimler
- Flutter 3.19+
- Dart 3.2+
- Android/iOS cihaz (kamera ve biyometrik destekli)

## Kullanılan Paketler
- camera
- tflite_flutter
- local_auth
- sqflite
- path_provider

## Kurulum
1. Flutter ortamını kurun.
2. Gerekli paketleri yükleyin:
   ```
   flutter pub get
   ```
3. Uygulamayı başlatın:
   ```
   flutter run
   ```

## Test Senaryoları
- Yüz kaydı: 5 pozda fotoğraf çekip isim girin, kayıt başarılı mesajı alın.
- Yüz tanıma: Ana sayfada yüzünüzü tanıtın, eşleşirse animasyonlu başarı ve skoru ile kapı açıldı mesajı alın.
- Yönetici: Kimlik doğrulama veya PIN ile giriş sonrası kayıtlı yüzleri görüntüleyin, yeniden adlandırın veya silin (onay ile).
- Hatalar: Kamera/kimlik doğrulama/embedding hatalarında Türkçe ve modern uyarı alın.
- Dark Mode ve haptic feedback test edin.
- SQLite şifreleme ve veri güvenliğini doğrulayın.
- Web/Desktop ve Raspberry Pi entegrasyonunu test edin.

## Notlar
- Tüm veriler cihazda şifreli olarak saklanır, bulut veya internet bağlantısı gerekmez.
- Geliştirme sırasında konsola ve dosyaya yapılandırılmış hata logları basılır.
- Tüm modüller ve servisler için unit testler mevcuttur.
- Yüz dosyaları ve verileri organize klasörlerde tutulur.

## Lisans
Bu proje eğitim ve demo amaçlıdır.
