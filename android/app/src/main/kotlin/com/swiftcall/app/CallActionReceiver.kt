package com.swiftcall.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telecom.TelecomManager
import android.util.Log
import java.util.UUID

class CallActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallActionReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val uuid = intent.getStringExtra("uuid") ?: return

        Log.d(TAG, "Received broadcast action: $action for UUID: $uuid")

        val connection = CallConnectionService.activeConnections[uuid]
        if (connection == null) {
            Log.e(TAG, "Connection not found for UUID: $uuid")
            return
        }

        when (action) {
            "com.swiftcall.app.ANSWER_CALL" -> {
                Log.d(TAG, "Answering call via broadcast for UUID: $uuid")
                connection.onAnswer()
            }
            "com.swiftcall.app.DECLINE_CALL" -> {
                Log.d(TAG, "Declining call via broadcast for UUID: $uuid")
                connection.onReject()
            }
        }

        // Stop the foreground service after handling the action
        val serviceIntent = Intent(context, CallForegroundService::class.java).apply {
            putExtra("action", "stop")
        }
        context.stopService(serviceIntent)
    }
}
