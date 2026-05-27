# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase rules
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keep class com.google.firebase.** { *; }

# Agora rules (required for agora_rtc_engine)
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# General AndroidX rules
-keep class androidx.core.** { *; }
-dontwarn androidx.core.**
