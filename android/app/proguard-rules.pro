# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Mercado Pago SDK
-keep class com.mercadopago.** { *; }
-dontwarn com.mercadopago.**

# Gson (used by Firebase)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
