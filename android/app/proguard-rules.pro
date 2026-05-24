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

# ─── R8 full-mode compatibility ───────────────────────────────────────────────
-allowaccessmodification
