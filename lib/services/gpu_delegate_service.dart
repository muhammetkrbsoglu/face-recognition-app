import 'package:tflite_flutter/tflite_flutter.dart';

class GpuDelegateService {
  static InterpreterOptions getGpuOptions() {
    final options = InterpreterOptions();
    options.addDelegate(GpuDelegateV2());
    return options;
  }
}
