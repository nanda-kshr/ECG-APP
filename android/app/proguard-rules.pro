# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods and classes needed for JNI
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter native splash
-keep class net.jonhanson.flutter_native_splash.** { *; }

# Firebase
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn com.google.firebase.**

# Play core / deferred components referenced by Flutter engine
-dontwarn com.google.android.play.core.**

