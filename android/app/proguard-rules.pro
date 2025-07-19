# Flutter and TFLite keep rules
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
-dontwarn org.tensorflow.**
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**
