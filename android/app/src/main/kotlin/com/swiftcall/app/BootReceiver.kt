package com.swiftcall.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.auth.FirebaseAuth

/**
 * Starts CallListenerService when device boots
 * or when app is updated/reinstalled.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "Boot completed, starting listener services")

                // Only start if user is logged in
                if (FirebaseAuth.getInstance().currentUser != null) {
                    // Start call listener
                    val callServiceIntent = Intent(context, CallListenerService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(callServiceIntent)
                    } else {
                        context.startService(callServiceIntent)
                    }

                    // Start message listener
                    val messageServiceIntent = Intent(context, MessageListenerService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(messageServiceIntent)
                    } else {
                        context.startService(messageServiceIntent)
                    }

                    Log.d(TAG, "Both listener services started")
                } else {
                    Log.d(TAG, "No authenticated user, skipping service start")
                }
            }
        }
    }
}
