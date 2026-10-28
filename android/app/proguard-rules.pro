# Release R8 rules for Gəlir-Çıxar. Flutter's own rules and most plugins'
# consumer rules are applied automatically; these cover the rest.

# flutter_local_notifications: persists notification details with Gson and
# reflects on its own classes (documented requirement of the plugin).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**

# local_auth: BiometricPrompt needs a FragmentActivity; MainActivity is kept
# by the manifest, androidx.biometric ships its own consumer rules.
-keep class io.flutter.plugins.localauth.** { *; }

# flutter_secure_storage: Keystore / cipher classes looked up by name.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter deferred components are not used; silence Play Core references.
-dontwarn com.google.android.play.core.**

# No log output from Java/Kotlin code in release builds.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
