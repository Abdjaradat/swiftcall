package com.swiftcall.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.UUID

class CallForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "swiftcall_incoming_call_channel"
        private const val NOTIFICATION_ID = 12345
        private const val TAG = "CallForegroundService"
        private const val CONNECTION_SERVICE_ID = "SwiftCallConnectionServiceId" // Unique ID for our PhoneAccountHandle
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        Log.d(TAG, "onStartCommand with action: $action")

        when (action) {
            "start" -> {
                val uuid = intent.getStringExtra("uuid") ?: UUID.randomUUID().toString()
                val callerName = intent.getStringExtra("callerName") ?: "Unknown Caller"
                val hasVideo = intent.getBooleanExtra("hasVideo", false)

                startForegroundNotification(uuid, callerName, hasVideo)

                // Report the incoming call to the TelecomManager
                val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                val phoneAccountHandle = PhoneAccountHandle(componentName, CONNECTION_SERVICE_ID)

                val extras = Bundle().apply {
                    putString("uuid", uuid)
                    putString("callerName", callerName)
                    putBoolean("hasVideo", hasVideo)
                    putBoolean(TelecomManager.EXTRA_IS_SELF_MANAGED_CONNECTION, true)
                }

                try {
                    telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
                    Log.d(TAG, "Reported incoming call to TelecomManager for UUID: $uuid")
                } catch (e: SecurityException) {
                    Log.e(TAG, "SecurityException: Cannot add new incoming call. Ensure MANAGE_OWN_CALLS permission is declared and granted.", e)
                    // If permissions are not correct, the call will not be managed by TelecomManager.
                    // The notification will still show, but answer/decline might not work as expected
                    // through the ConnectionService.
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to add new incoming call: ${e.message}", e)
                }
            }
            "end" -> {
                val uuid = intent.getStringExtra("uuid")
                if (uuid != null) {
                    CallConnectionService.reportCallEnded(uuid, DisconnectCause.LOCAL)
                }
                stopSelf()
            }
            "stop" -> {
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Incoming Call"
            val descriptionText = "Incoming SwiftCall notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                enableVibration(true)
                lightColor = Color.GREEN
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundNotification(uuid: String, callerName: String, hasVideo: Boolean) {
        createNotificationChannel()

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = "com.swiftcall.app.INCOMING_CALL"
            putExtra("uuid", uuid)
            putExtra("callerName", callerName)
            putExtra("hasVideo", hasVideo)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        val fullScreenPendingIntent: PendingIntent = PendingIntent.getActivity(
            this,
            0,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher) // Use your app's icon
            .setContentTitle("Incoming SwiftCall")
            .setContentText("Call from $callerName")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(true)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE))

        // Add action buttons for answer and decline
        val answerIntent = Intent(this, CallActionReceiver::class.java).apply {
            action = "com.swiftcall.app.ANSWER_CALL"
            putExtra("uuid", uuid)
        }
        val answerPendingIntent: PendingIntent = PendingIntent.getBroadcast(
            this,
            1,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(this, CallActionReceiver::class.java).apply {
            action = "com.swiftcall.app.DECLINE_CALL"
            putExtra("uuid", uuid)
        }
        val declinePendingIntent: PendingIntent = PendingIntent.getBroadcast(
            this,
            2,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        notificationBuilder
            .addAction(0, "Answer", answerPendingIntent)
            .addAction(0, "Decline", declinePendingIntent)

        val notification = notificationBuilder.build()
        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Foreground service destroyed")
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
    }
}
