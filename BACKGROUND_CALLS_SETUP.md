# Background / Killed-State Incoming Calls — Setup Guide

This document explains every step needed to make SwiftCall ring on a **killed or background** app on both platforms.

---

## Android — No Extra Setup Required

Android works out of the box:

1. The custom `SwiftCallFirebaseMessagingService` receives the FCM **data-only** high-priority message even when the app is killed.
2. It starts `CallForegroundService`, which shows a full-screen notification with Answer / Decline buttons over the lock screen.
3. When the user taps Answer, `CallActionReceiver` → `MainActivity` → Flutter navigates to the call screen.

**The only requirement is that your backend (Cloud Function) sends a high-priority data-only FCM message** — which `functions/index.js` already does automatically whenever a new `calls/{callId}` document is created in Firestore.

---

## iOS — Requires APNs Key Configuration

iOS uses **PushKit** (VoIP pushes) + **CallKit**. Regular FCM notifications are **not enough** to wake a killed iOS app for a phone call — you must send a VoIP push directly to Apple's servers using the `voipToken` stored in Firestore.

### Step 1 — Create an APNs Auth Key

1. Go to [Apple Developer Console](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Keys**
2. Click **+** to create a new key
3. Name it (e.g. "SwiftCall APNs Key"), check **Apple Push Notifications service (APNs)**
4. Click **Continue** → **Register** → **Download** (you get a `.p8` file — keep it safe, you can only download it once)
5. Note down your **Key ID** (shown on the key page) and **Team ID** (top-right of Apple Developer portal)

### Step 2 — Set Firebase Secrets

Run these commands from your project root (requires Firebase CLI logged in):

```bash
# Your 10-character Key ID (e.g. "ABC1234DEF")
firebase functions:secrets:set APNS_KEY_ID

# Your 10-character Team ID (from Apple Developer portal, top-right)
firebase functions:secrets:set APNS_TEAM_ID

# The full content of the .p8 file (open it with a text editor and paste the entire content)
firebase functions:secrets:set APNS_KEY_P8
```

### Step 3 — Configure Bundle ID

The bundle ID in `functions/index.js` is already set to `com.swiftcall.app`.
If your bundle ID differs, update this line:

```js
const BUNDLE_ID = "com.swiftcall.app";
```

### Step 4 — Deploy Cloud Functions

```bash
cd functions
npm install          # installs firebase-admin, firebase-functions, apn
firebase deploy --only functions
```

### Step 5 — Production vs Sandbox

- **Development / TestFlight**: Leave `APNS_PRODUCTION` unset (defaults to sandbox)
- **App Store**: Set `APNS_PRODUCTION=true` in your Cloud Function environment

```bash
firebase functions:config:set apns.production=true
```

---

## How the Full Call Flow Works

### Receiver's App is KILLED

#### Android
```
Caller creates Firestore call doc
  → Cloud Function fires
  → Sends FCM high-priority data message
  → SwiftCallFirebaseMessagingService.onMessageReceived()
  → starts CallForegroundService
  → Full-screen notification shows over lock screen
  → User taps "Answer" → CallActionReceiver → MainActivity → Flutter navigates to call screen
```

#### iOS
```
Caller creates Firestore call doc
  → Cloud Function fires
  → Sends APNs VoIP push to voipToken
  → iOS wakes app via PushKit (even if killed)
  → AppDelegate.pushRegistry(_:didReceiveIncomingPushWith:) fires
  → provider.reportNewIncomingCall() → CallKit shows native call screen with ringtone
  → User taps "Answer" → CXAnswerCallAction → AppDelegate invokes Flutter "answerCallFromNative"
  → app.dart._navigateToActiveCall() → accepts in Firestore + navigates to call screen
```

### Receiver's App is in BACKGROUND

Same as killed state above.

### Receiver's App is in FOREGROUND

```
Caller creates Firestore call doc
  → Firestore listener in app.dart detects new 'ringing' call
  → Shows IncomingCallScreen with Accept / Decline buttons
  → Also shows local notification (Android) so it appears on lock screen if device locks
```

### Caller Cancels

```
Caller updates call status to 'cancelled'
  → Cloud Function (cancelCallNotification) fires
  → Sends FCM data message {type: "call_cancelled"} to both parties
  → Receiver (foreground): notification_service handles → cancelCallNotification() → pops IncomingCallScreen
  → Receiver (background/killed, Android): SwiftCallFirebaseMessagingService stops CallForegroundService
  → Receiver (background/killed, iOS): voipToken push with 0-second TTL can be sent (optional)
```

---

## Firestore User Document Fields

Each user document in `users/{uid}` should contain:

| Field | Type | Set by |
|---|---|---|
| `fcmToken` | String | Flutter (on login, on token refresh) |
| `voipToken` | String | Flutter iOS (on PushKit token received) |

Both are set automatically by the app — no manual setup needed.

---

## Testing

### Android
```bash
# Send a test FCM data message using Firebase CLI or console
# Or create a call document in Firestore and watch the Cloud Function trigger
```

### iOS (VoIP push test)
```bash
# Use the pusher tool or a script to send a test VoIP push:
# https://github.com/noodlewerk/NWPusher (GUI)
# Or use xcrun to send a VoIP push from command line
xcrun simctl push <device-id> com.swiftcall.app.voip voip_payload.json
```

Where `voip_payload.json`:
```json
{
  "callId": "test-call-123",
  "callerName": "Test Caller",
  "callerPhoto": "",
  "roomName": "test-room",
  "callType": "audio"
}
```
