# ─── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Firebase Messaging ───────────────────────────────────────────────────────
# Our custom FCM service must never be removed by R8.
-keep class com.swiftcall.app.SwiftCallFirebaseMessagingService { *; }
-keep class com.swiftcall.app.CallForegroundService           { *; }
-keep class com.swiftcall.app.CallConnectionService           { *; }
-keep class com.swiftcall.app.CallActionReceiver              { *; }
-keep class com.swiftcall.app.MainActivity                    { *; }

# ─── LiveKit / WebRTC ─────────────────────────────────────────────────────────
-keep class io.livekit.** { *; }
-keep class org.webrtc.**  { *; }
-dontwarn io.livekit.**
-dontwarn org.webrtc.**

# ─── OkHttp & Retrofit (used by LiveKit) ─────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ─── Kotlin coroutines ────────────────────────────────────────────────────────
-keepclassmembernames class kotlinx.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# ─── Keep Parcelable / Serializable models ────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ─── Annotations ──────────────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions,InnerClasses

# ─── Unity Ads ────────────────────────────────────────────────────────────────
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.**

# ─── Gson (used by Firebase & LiveKit internals) ──────────────────────────────
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ─── Dio / OkHttp (used for LiveKit token requests) ──────────────────────────
-keep class com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**

# ─── R8 full-mode compatibility ───────────────────────────────────────────────
-allowaccessmodification

# ─── Android 15 Compatibility ─────────────────────────────────────────────────
# Keep all MainActivity methods (Android 15 may need them)
-keepclassmembers class com.swiftcall.app.MainActivity {
    *;
}

# Keep all FlutterActivity methods
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterActivityAndFragmentDelegate { *; }

# Keep generic signatures for Gson (fixes TypeToken error)
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep all notification classes (fixes flutter_local_notifications)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
