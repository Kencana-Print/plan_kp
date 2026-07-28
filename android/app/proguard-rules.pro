# =============================================
# Flutter Proguard Rules (Updated)
# =============================================
# NOTE: Flutter's embedding rules are now handled internally by the Flutter SDK.
# Keeping deprecated io.flutter.app/view/util rules actually PREVENTS R8 from
# shrinking those classes. Remove them for smaller APK output.

# Keep Flutter embedding entry points (required for JNI)
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Flutter plugin registrar (for method channels)
-keep class io.flutter.plugin.common.** { *; }

# =============================================
# Library-specific rules
# =============================================

# Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Retrofit (if used transitively)
-dontwarn retrofit2.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# open_filex / FileProvider
-keep class androidx.core.content.FileProvider { *; }

# Keep Kotlin metadata for reflection (minimal set)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
