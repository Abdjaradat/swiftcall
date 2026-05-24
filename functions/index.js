/**
 * SwiftCall — Firebase Cloud Functions
 *
 * Triggers:
 *  1. sendCallNotification  — fires when a new call doc is created
 *     → Sends Android FCM data message  (high-priority, data-only — no notification block)
 *     → Sends iOS VoIP push via APNs    (PushKit, wakes app even when killed)
 *
 *  2. cancelCallNotification — fires when call status changes to cancelled/rejected/ended/missed
 *     → Tells the receiver to dismiss the incoming call UI immediately
 *
 *  3. timeoutStaleCalls — runs every minute via Cloud Scheduler
 *     → Marks any call still "ringing" after 45 s as "missed"
 *     → cancelCallNotification then fires and dismisses the UI on both devices
 *
 * ── iOS VoIP push setup ───────────────────────────────────────────────────────
 * VoIP pushes bypass FCM and go directly to Apple's servers.
 * You must configure three Firebase environment variables before deploying:
 *
 *   firebase functions:secrets:set APNS_KEY_ID      # e.g. "ABC1234DEF"
 *   firebase functions:secrets:set APNS_TEAM_ID     # e.g. "ABCDE12345"
 *   firebase functions:secrets:set APNS_KEY_P8      # the full .p8 file content
 *
 * The .p8 key is created in Apple Developer → Certificates → Keys
 * (check "Apple Push Notifications service (APNs)").
 *
 * Set APNS_PRODUCTION=true when deploying to production (App Store builds).
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const apn = require("apn");

admin.initializeApp();

const BUNDLE_ID = "com.swiftcall.app";

// ── APNs secrets (set via: firebase functions:secrets:set <NAME>) ─────────────
const APNS_KEY_ID  = defineSecret("APNS_KEY_ID");
const APNS_TEAM_ID = defineSecret("APNS_TEAM_ID");
const APNS_KEY_P8  = defineSecret("APNS_KEY_P8");   // full .p8 file content

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Builds an APNs Provider for VoIP pushes.
 * Returns null if secrets are not configured (graceful no-op).
 */
function buildApnProvider(keyId, teamId, keyContent) {
  if (!keyId || !teamId || !keyContent) {
    console.warn("[APNs] Secrets not configured — iOS VoIP push skipped.");
    return null;
  }
  return new apn.Provider({
    token: {
      key:    Buffer.from(keyContent),
      keyId,
      teamId,
    },
    production: process.env.APNS_PRODUCTION === "true",
  });
}

/**
 * Sends an iOS VoIP push notification via APNs (PushKit).
 * The apns-push-type header MUST be "voip" and the topic must end with ".voip".
 */
async function sendVoipPush(provider, voipToken, callData) {
  if (!provider || !voipToken) return;

  const note = new apn.Notification();
  note.topic    = `${BUNDLE_ID}.voip`; // required — must be <bundleId>.voip
  note.priority = 10;
  note.expiry   = Math.floor(Date.now() / 1000) + 45; // 45 s TTL — matches ringtone timeout

  // The payload is available as payload.dictionaryPayload in AppDelegate.swift
  note.payload  = {
    callId:      callData.callId,
    callerName:  callData.callerName,
    callerPhoto: callData.callerPhoto || "",
    roomName:    callData.roomName    || "",
    callType:    callData.callType    || "audio",
  };

  const result = await provider.send(note, voipToken);

  if (result.failed && result.failed.length > 0) {
    const reason = result.failed[0].response?.reason || "unknown";
    console.error(`[APNs] VoIP push failed — token=${voipToken.slice(-8)}, reason=${reason}`);
    // If the token is invalid, clean it from Firestore
    if (reason === "BadDeviceToken" || reason === "Unregistered") {
      await admin.firestore()
        .collection("users")
        .doc(callData.receiverId)
        .update({ voipToken: admin.firestore.FieldValue.delete() });
    }
  } else {
    console.log(`[APNs] VoIP push sent — token=...${voipToken.slice(-8)}`);
  }
}

/**
 * Sends a single high-priority FCM data message to all platforms.
 *
 * - Android (background/killed): SwiftCallFirebaseMessagingService receives it
 *   and starts CallForegroundService.
 * - iOS (foreground): Flutter onMessage handler fires; Firestore listener
 *   shows the in-app IncomingCallScreen.
 * - iOS (background/killed): Handled separately via APNs VoIP push (PushKit).
 *
 * IMPORTANT: No "notification" block — keeps this a pure data message so the
 * Android native service (not FCM) controls the UI. Only ONE message is sent
 * per call to avoid triggering the native service twice.
 */
async function sendFcmDataMessage(fcmToken, callData) {
  if (!fcmToken) return;

  const message = {
    token: fcmToken,
    data: {
      type:        "call",
      callId:      callData.callId,
      callerId:    callData.callerId   || "",
      callerName:  callData.callerName,
      callerPhoto: callData.callerPhoto || "",
      callType:    callData.callType   || "audio",
      roomName:    callData.roomName   || "",
    },
    // Android: highest delivery priority, 45 s TTL (matches call timeout)
    android: {
      priority: "high",
      ttl:      45000,
    },
    // iOS: silent background wakeup (belt-and-suspenders for foreground state;
    // killed/background state is handled by the VoIP push below).
    apns: {
      payload: { aps: { "content-available": 1 } },
      headers: { "apns-priority": "5", "apns-push-type": "background" },
    },
  };

  const response = await admin.messaging().send(message);
  console.log(`[FCM] Data message sent — ${response}`);
}

/**
 * Sends an FCM data message to BOTH platforms to dismiss the call UI.
 */
async function sendCancelMessage(fcmToken, callId) {
  if (!fcmToken) return;
  const message = {
    token: fcmToken,
    data:  { type: "call_cancelled", callId },
    android: { priority: "high" },
    apns: {
      payload: { aps: { "content-available": 1 } },
      headers: { "apns-priority": "5" },
    },
  };
  await admin.messaging().send(message);
  console.log(`[FCM] Cancel message sent for callId=${callId}`);
}

// ── Cloud Functions ───────────────────────────────────────────────────────────

/**
 * Trigger: new call document created in Firestore.
 * Notifies the receiver on both Android (FCM) and iOS (VoIP push).
 */
exports.sendCallNotification = onDocumentCreated(
  {
    document: "calls/{callId}",
    secrets:  [APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8],
  },
  async (event) => {
    const callId = event.params.callId;           // ← correct way to get the doc ID
    const call   = event.data.data();

    // Only notify for ringing calls
    if (call.status && call.status !== "ringing") {
      console.log(`[sendCallNotification] Skipping — status=${call.status}`);
      return;
    }

    const receiverId = call.receiverId;
    if (!receiverId) {
      console.error("[sendCallNotification] Missing receiverId");
      return;
    }

    // Fetch receiver's tokens
    const userDoc  = await admin.firestore().collection("users").doc(receiverId).get();
    const userData = userDoc.data();
    if (!userData) {
      console.error(`[sendCallNotification] Receiver ${receiverId} not found`);
      return;
    }

    const fcmToken  = userData.fcmToken;
    const voipToken = userData.voipToken;

    const callData = {
      callId,
      callerId:    call.callerId    || "",
      callerName:  call.callerName  || "Unknown",
      callerPhoto: call.callerPhoto || "",
      callType:    call.type        || "audio",
      roomName:    call.roomName    || "",
      receiverId,
    };

    console.log(`[sendCallNotification] callId=${callId}, caller=${callData.callerName}, ` +
      `hasFcm=${!!fcmToken}, hasVoip=${!!voipToken}`);

    const tasks = [];

    // ── 1. FCM data message (Android background/killed + iOS foreground) ──
    // Single high-priority data-only message — no "notification" block so the
    // Android native SwiftCallFirebaseMessagingService gets it exclusively.
    if (fcmToken) {
      tasks.push(
        sendFcmDataMessage(fcmToken, callData).catch((err) =>
          console.error("[FCM] send error:", err.message)
        )
      );
    }

    // ── 2. APNs VoIP push (iOS background/killed via PushKit) ──────────────
    // Required to wake a killed iOS app and show the native CallKit screen.
    // Secrets must be configured; silently skipped if not set.
    if (voipToken) {
      const provider = buildApnProvider(
        APNS_KEY_ID.value(),
        APNS_TEAM_ID.value(),
        APNS_KEY_P8.value(),
      );
      if (provider) {
        tasks.push(
          sendVoipPush(provider, voipToken, callData)
            .catch((err) => console.error("[APNs] VoIP push error:", err.message))
            .finally(() => provider.shutdown())
        );
      }
    }

    await Promise.allSettled(tasks);
  }
);

/**
 * Trigger: call document updated.
 * When the caller cancels or the call ends, tell the receiver to dismiss
 * the incoming call screen immediately.
 */
exports.cancelCallNotification = onDocumentUpdated(
  "calls/{callId}",
  async (event) => {
    const callId  = event.params.callId;
    const before  = event.data.before.data();
    const after   = event.data.after.data();

    const dismissStatuses = new Set(["cancelled", "rejected", "ended", "missed", "busy"]);

    // Only act when the status just became a terminal state from ringing
    if (before.status !== "ringing") return;
    if (!dismissStatuses.has(after.status)) return;

    console.log(`[cancelCallNotification] callId=${callId}, new status=${after.status}`);

    // Notify BOTH parties to clear call state
    const uids = [after.receiverId, after.callerId].filter(Boolean);
    await Promise.allSettled(
      uids.map(async (uid) => {
        const doc  = await admin.firestore().collection("users").doc(uid).get();
        const token = doc.data()?.fcmToken;
        if (token) {
          await sendCancelMessage(token, callId).catch((e) =>
            console.warn(`[FCM] cancel to ${uid} failed:`, e.message)
          );
        }
      })
    );
  }
);

/**
 * Scheduled: runs every minute.
 *
 * Finds all calls that are still "ringing" but were created more than
 * CALL_TIMEOUT_SECONDS ago, and marks them "missed".
 *
 * This triggers cancelCallNotification, which immediately sends an FCM
 * call_cancelled message to both parties — dismissing the incoming-call
 * UI on Android and popping the IncomingCallScreen on iOS/Flutter.
 */
const CALL_TIMEOUT_SECONDS = 45;

/**
 * Trigger: new group_calls document created.
 * Notifies all invited participants (excluding the creator) via FCM.
 */
exports.sendGroupCallNotification = onDocumentCreated(
  {
    document: "group_calls/{callId}",
    secrets:  [APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8],
  },
  async (event) => {
    const callId = event.params.callId;
    const call   = event.data.data();

    if (call.status && call.status !== "ringing") return;

    const participants  = call.participants || [];
    const createdBy     = call.createdBy    || "";
    const creatorName   = call.creatorName  || "Unknown";
    const creatorPhoto  = call.creatorPhoto || "";
    const roomName      = call.roomName     || "";
    const callType      = call.callType     || "audio";

    // Notify every invited participant (skip creator)
    const invitedUids = participants
      .filter((p) => p.uid !== createdBy && p.status === "invited")
      .map((p) => p.uid);

    if (invitedUids.length === 0) {
      console.log(`[sendGroupCallNotification] No invited participants for ${callId}`);
      return;
    }

    console.log(`[sendGroupCallNotification] callId=${callId}, notifying ${invitedUids.length} participants`);

    await Promise.allSettled(
      invitedUids.map(async (uid) => {
        const userDoc  = await admin.firestore().collection("users").doc(uid).get();
        const userData = userDoc.data();
        if (!userData) return;

        const fcmToken  = userData.fcmToken;
        const voipToken = userData.voipToken;

        const callData = {
          callId,
          callerId:    createdBy,
          callerName:  creatorName,
          callerPhoto: creatorPhoto,
          callType:    callType,
          roomName:    roomName,
          receiverId:  uid,
          isGroupCall: "true",
        };

        const tasks = [];

        if (fcmToken) {
          const message = {
            token: fcmToken,
            data: {
              type:        "group_call",
              callId,
              callerId:    createdBy,
              callerName:  creatorName,
              callerPhoto: creatorPhoto,
              callType,
              roomName,
              isGroupCall: "true",
            },
            android: { priority: "high", ttl: 45000 },
            apns: {
              payload: { aps: { "content-available": 1 } },
              headers: { "apns-priority": "5", "apns-push-type": "background" },
            },
          };
          tasks.push(
            admin.messaging().send(message).catch((e) =>
              console.warn(`[FCM] group call to ${uid} failed:`, e.message)
            )
          );
        }

        if (voipToken) {
          const provider = buildApnProvider(
            APNS_KEY_ID.value(),
            APNS_TEAM_ID.value(),
            APNS_KEY_P8.value(),
          );
          if (provider) {
            tasks.push(
              sendVoipPush(provider, voipToken, callData)
                .catch((e) => console.error("[APNs] VoIP push error:", e.message))
                .finally(() => provider.shutdown())
            );
          }
        }

        await Promise.allSettled(tasks);
      })
    );
  }
);

exports.timeoutStaleCalls = onSchedule("every 1 minutes", async (_event) => {
  const cutoff = admin.firestore.Timestamp.fromMillis(
    Date.now() - CALL_TIMEOUT_SECONDS * 1000
  );

  const snapshot = await admin
    .firestore()
    .collection("calls")
    .where("status", "==", "ringing")
    .where("timestamp", "<", cutoff)
    .get();

  if (snapshot.empty) {
    console.log("[timeoutStaleCalls] No stale calls found.");
    return;
  }

  // Batch-write all updates (Firestore max 500 per batch — more than enough here)
  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { status: "missed" });
  });
  await batch.commit();

  console.log(
    `[timeoutStaleCalls] Marked ${snapshot.size} call(s) as missed:`,
    snapshot.docs.map((d) => d.id).join(", ")
  );
});
