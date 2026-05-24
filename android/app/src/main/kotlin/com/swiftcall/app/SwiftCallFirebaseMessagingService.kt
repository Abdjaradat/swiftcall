package com.swiftcall.app

import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Custom FCM service — handles data messages when the app is in background or KILLED.
 * High-priority FCM data messages wake this service even on a killed app.
 *
 * The Flutter _bgMessageHandler Dart isolate CANNOT start native services,
 * so we handle the "call" type here in native Kotlin instead.
 */
class SwiftCallFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "SwiftCallFCM"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val data = message.data
        Log.d(TAG, "FCM received: type=${data["type"]}, app foreground=${isAppForeground()}")

        when (data["type"]) {
            "call"            -> handleIncomingCall(data)
            "call_cancelled"  -> handleCallCancelled(data)
        }
    }

    private fun handleCallCancelled(data: Map<String, String>) {
        Log.d(TAG, "Call cancelled — stopping foreground service (callId=${data["callId"]})")
        // Stop the incoming call foreground service so the notification is dismissed
        val stopIntent = Intent(this, CallForegroundService::class.java).apply {
            putExtra("action", "stop")
        }
        stopService(stopIntent)
    }

    private fun handleIncomingCall(data: Map<String, String>) {
        val callId      = data["callId"]      ?: return   // required
        val callerName  = data["callerName"]  ?: "Unknown"
        val callerPhoto = data["callerPhoto"] ?: ""
        val roomName    = data["roomName"]    ?: ""
        val callType    = data["callType"]    ?: "audio"
        val hasVideo    = callType == "video"

        Log.d(TAG, "Incoming call from $callerName (callId=$callId)")

        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            putExtra("action",      "start")
            putExtra("uuid",        callId)
            putExtra("callerName",  callerName)
            putExtra("callerPhoto", callerPhoto)
            putExtra("hasVideo",    hasVideo)
            putExtra("roomName",    roomName)
            putExtra("callType",    callType)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    /**
     * Returns true if the app currently has a visible Activity.
     * Used for logging only — foreground service handles both cases.
     */
    private fun isAppForeground(): Boolean {
        return try {
            val am = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
            val tasks = am.getRunningTasks(1)
            tasks.isNotEmpty() && tasks[0].topActivity?.packageName == packageName
        } catch (e: Exception) { false }
    }

}
