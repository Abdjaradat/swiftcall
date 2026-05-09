const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendCallNotification = functions.firestore
  .document("calls/{callId}")
  .onCreate(async (snap, context) => {
    const call = snap.data();
    const receiverId = call.receiverId;

    // Get receiver's FCM token
    const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return;

    const isVideo = call.type === "video";
    const payload = {
      token,
      priority: "high",
      data: {
        type: "call",
        callId: call.id,
        callerId: call.callerId,
        callerName: call.callerName,
        callerPhoto: call.callerPhoto || "",
        callType: call.type,
        roomName: call.roomName || "",
      },
      notification: {
        title: isVideo ? "📹 مكالمة فيديو" : "🎙️ مكالمة صوتية",
        body: call.callerName,
        sound: "ringtone.wav",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "swiftcall_calls",
          priority: "max",
          sound: "ringtone",
          vibrationPattern: "0, 1000, 500, 1000",
          fullScreenIntent: true,
          visibility: "public",
          notificationPriority: "PRIORITY_MAX",
          ticker: `مكالمة من ${call.callerName}`,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: isVideo ? "📹 مكالمة فيديو" : "🎙️ مكالمة صوتية",
              body: call.callerName,
            },
            sound: "ringtone.wav",
            category: "incoming_call",
            "content-available": 1,
            "interruption-level": "time-sensitive",
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      functions.logger.log("Notification sent:", response);
    } catch (error) {
      functions.logger.error("Failed to send notification:", error);
    }
  });
