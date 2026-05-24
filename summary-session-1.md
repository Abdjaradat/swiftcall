# SwiftCall Session Summary (May 9, 2026)

## Stack
- Flutter 3.29.2 / Dart
- Firebase (Firestore, Storage, FCM, Cloud Functions)
- LiveKit (WebRTC) — token server at `https://swiftcall-backend.onrender.com/getToken`
- State: flutter_bloc

## Done
- Ringtone fixed on Android (`res/raw/ringtone.wav`)
- Notification when app closed fixed (`pendingCallData`, `onCallOpened`, `_navigateToCallFromData`)
- AuthService bug fix: removed `googleUser.phoneNumber`
- iOS free-tier setup (no push): `GoogleService-Info.plist`, Podfile, ringtone in Xcode, deployment target 13.0
- iOS push removed (needs $99 Apple Developer Program)
- Cloud Function `sendCallNotification` deployed with `interruption-level: time-sensitive`
- Git initialized → committed → pushed to `github.com/Abdjaradat/swiftcall`
- Android APK built locally (`build/app/outputs/flutter-apk/app-release.apk`, 99.6 MB)
- Firebase config: `.firebaserc`, `firebase.json`, `google-services.json`, `storage.rules` deployed
- Billing enabled on Firebase project
- Insecure client-side FCM fallback removed
- Token refresh wired: `NotificationService.onTokenRefresh` → `AuthService.updateFcmToken`
- Privacy features: phone matching contacts, hide contact (`hiddenContacts`), delete chat
- compileSdk 35 + `androidx.core:core:1.13.1` for `livekit_client` compatibility
- GitHub Actions workflow: Android (Ubuntu) + iOS Simulator (macOS)

## Current Status
- **iOS CI build**: ✅ SUCCESS (unsigned IPA artifact available)
- **Android CI build**: FAILS — `debug.keystore` not found (fixed: now generates keystore instead of using secret)
- **Previous Android error** (`shareWithResult`): ✅ FIXED
- Local Android build: ✅ succeeds

## Key Firebase Config
```
Project: swiftcall-eec90 (1082599622155)
Storage: swiftcall-eec90.firebasestorage.app
WebSocket: wss://swiftcall-criz4m8x.livekit.cloud
Google client ID: 1082599622155-4gakg5bv8q1gtibljpuh1snc00ncnf62
iOS bundle ID: com.swiftcall.swiftcall
Android appId: com.swiftcall.app
```

## GitHub
- Repo: `https://github.com/Abdjaradat/swiftcall`
- Actions: `https://github.com/Abdjaradat/swiftcall/actions`

## Remaining
1. Fix Android CI build (lStar issue in livekit_client)
2. Wait for iOS Simulator build result
3. Make iOS build downloadable for test on iPhone
4. Test: voice (earpiece default + toggle), video (speaker default + toggle), timer only after join, privacy, hide contact, delete chat
5. Add phone number input screen for users without Google phone number
6. (Future) Apple Developer Program → enable iOS push
