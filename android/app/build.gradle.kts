import java.util.Properties

plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { properties.load(it) }
    }
    return properties
}

val flutterVersionCode: String = localProperties().getProperty("flutter.versionCode") ?: "1"
val flutterVersionName: String = localProperties().getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.akilli_kapi_guvenlik_sistemi"
    compileSdk = 36
    
    // HATA BURADAYDI: Belirli bir NDK versiyonunu zorlayan bu satır kaldırıldı.
    // Gradle artık bilgisayarınızda yüklü olan NDK'yı otomatik olarak kullanacak.
    // ndkVersion = flutter.ndkVersion 

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.akilli_kapi_guvenlik_sistemi"
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Bağımlılıklar
}
