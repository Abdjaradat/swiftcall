# SwiftCall — Debug Build Guide

## Prerequisites

Make sure you have Flutter installed and set up:
```bash
flutter doctor
```
All checkmarks should be green (or at least Android toolchain + Xcode for respective targets).

---

## Android — Debug APK

### Build
```bash
flutter build apk --debug
```

Output location:
```
build/app/outputs/flutter-apk/app-debug.apk
```

### Install directly on a connected device/emulator
```bash
flutter install --debug
```

### Run with logs (recommended for debugging)
```bash
flutter run --debug
```

### Notes
- The debug APK is **not minified** and includes the Flutter engine debug symbols.
- Do **not** submit this to the Play Store — it is for internal testing only.
- The APK is unsigned with the debug keystore (automatically created by Flutter).

---

## iOS — Debug Build

### Option A: Simulator (no Apple account needed)
```bash
flutter build ios --debug --simulator
```
Then open the `.app` bundle in your simulator:
```bash
open -a Simulator
flutter install --debug
```

### Option B: Physical Device (requires a paid Apple Developer account)
```bash
flutter build ios --debug
```
Then open Xcode to deploy:
```bash
open ios/Runner.xcworkspace
```
In Xcode:
1. Select your physical device at the top
2. Set your Team under **Signing & Capabilities → Team**
3. Press **Run (▶)** or use `Product → Run`

### Option C: Run directly (device + simulator)
```bash
flutter run -d <device-id>
```
List available devices:
```bash
flutter devices
```

---

## Checking for Errors Before Building

Run a static analysis pass to catch any Dart errors before building:
```bash
flutter analyze
```

Run a dependency check:
```bash
flutter pub get
flutter pub outdated
```

---

## Firestore Indexes

The Call History tab uses two Firestore queries that require composite indexes.
Deploy them with Firebase CLI:

```bash
# Install Firebase CLI if needed
npm install -g firebase-tools

# Login and deploy indexes only
firebase login
firebase deploy --only firestore:indexes
```

Or click the links that appear in the Flutter debug console the first time
the Call History tab loads — Firebase auto-generates the index creation link.

---

## Common Build Issues

| Error | Fix |
|-------|-----|
| `Gradle build failed` | Run `flutter clean && flutter pub get` then retry |
| `CocoaPods not installed` | Run `sudo gem install cocoapods`, then `cd ios && pod install` |
| `No provisioning profile` | Set your Apple Team in Xcode Signing & Capabilities |
| `desugar_jdk_libs` error | Already fixed — version updated to `2.0.4` in `build.gradle` |
| `Missing permission string` | Already fixed — all NSUsageDescription keys added to `Info.plist` |
| `Firestore index missing` | Deploy `firestore.indexes.json` or click the auto-generated link in console |
