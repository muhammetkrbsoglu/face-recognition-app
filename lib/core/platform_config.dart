import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformConfig {
  static bool get isWeb => kIsWeb;
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}
