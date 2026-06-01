package com.swiftcall.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telecom.DisconnectCause
import android.util.Log

class CallActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallActionReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action     = intent.action ?: return
        val uuid       = intent.getStringExtra("uuid") ?: return
        val callerName  = intent.getStringExtra("callerName")  ?: ""
        val callerPhoto = intent.getStringExtra("callerPhoto") ?: ""
        val hasVideo    = intent.getBooleanExtra("hasVideo", false)
        val roomName    = intent.getStringExtra("roomName")    ?: ""
        val callType    = intent.getStringExtra("callType")    ?: "audio"

        Log.d(TAG, "Received action=$action uuid=$uuid")

        // Also update the TelecomManager connection if it exists
        val connection = CallConnectionService.activeConnections[uuid]

        when (action) {
            "com.swiftcall.app.ANSWER_CALL" -> {
                connection?.onAnswer()
                // Launch MainActivity to navigate Flutter to the active call screen
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    this.action = "com.swiftcall.app.ANSWER_CALL"
                    putExtra("uuid",        uuid)
                    putExtra("callerName",  callerName)
                    putExtra("callerPhoto", callerPhoto)
                    putExtra("hasVideo",    hasVideo)
                    putExtra("roomName",    roomName)
                    putExtra("callType",    callType)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                context.startActivity(launchIntent)
                // Stop ringtone when call is answered
                val stopIntent = Intent(context, CallForegroundService::class.java).apply {
                    putExtra("action", "stop")
                }
                context.stopService(stopIntent)
            }
            "com.swiftcall.app.DECLINE_CALL" -> {
                connection?.onReject()
                // Launch MainActivity to tell Flutter to reject the call in Firestore
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    this.action = "com.swiftcall.app.DECLINE_CALL"
                    putExtra("uuid",       uuid)
                    putExtra("callerName", callerName)
                    putExtra("hasVideo",   hasVideo)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                context.startActivity(launchIntent)
                // Stop the service immediately for decline
                val stopIntent = Intent(context, CallForegroundService::class.java).apply {
                    putExtra("action", "stop")
                }
                context.stopService(stopIntent)
            }
        }
    }
}
