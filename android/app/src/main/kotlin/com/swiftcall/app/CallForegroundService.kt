package com.swiftcall.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
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
        private const val CHANNEL_ID       = "swiftcall_incoming_call_channel"
        private const val NOTIFICATION_ID  = 12345
        private const val TAG              = "CallForegroundService"
        private const val PHONE_ACCOUNT_ID = "SwiftCallConnectionServiceId"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        Log.d(TAG, "onStartCommand: action=$action")

        when (action) {
            "start" -> {
                val uuid        = intent.getStringExtra("uuid")        ?: UUID.randomUUID().toString()
                val callerName  = intent.getStringExtra("callerName")  ?: "Unknown"
                val callerPhoto = intent.getStringExtra("callerPhoto") ?: ""
                val hasVideo    = intent.getBooleanExtra("hasVideo", false)
                val roomName    = intent.getStringExtra("roomName")    ?: ""
                val callType    = intent.getStringExtra("callType")    ?: "audio"

                startForegroundNotification(uuid, callerName, callerPhoto, hasVideo, roomName, callType)
                reportToTelecom(uuid, callerName, hasVideo)
            }
            "end"  -> {
                val uuid = intent?.getStringExtra("uuid")
                if (uuid != null) CallConnectionService.reportCallEnded(uuid, DisconnectCause.LOCAL)
                stopSelf()
            }
            "stop" -> stopSelf()
        }
        return START_NOT_STICKY
    }

    // ── Notification channel ─────────────────────────────────────────────

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.deleteNotificationChannel(CHANNEL_ID)

        val channel = NotificationChannel(CHANNEL_ID, "Incoming Call", NotificationManager.IMPORTANCE_HIGH).apply {
            description          = "SwiftCall incoming call notifications"
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            setSound(
                Uri.parse("android.resource://${packageName}/raw/ringtone"),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            enableVibration(true)
            lightColor = Color.GREEN
        }
        nm.createNotificationChannel(channel)
    }

    // ── Full-screen notification ─────────────────────────────────────────

    private fun startForegroundNotification(
        uuid: String, callerName: String, callerPhoto: String,
        hasVideo: Boolean, roomName: String, callType: String
    ) {
        ensureChannel()

        // Full-screen intent — launches MainActivity when screen is locked / app killed
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = "com.swiftcall.app.INCOMING_CALL"
            putExtra("uuid",        uuid)
            putExtra("callerName",  callerName)
            putExtra("callerPhoto", callerPhoto)
            putExtra("hasVideo",    hasVideo)
            putExtra("roomName",    roomName)
            putExtra("callType",    callType)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val fullScreenPI = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Answer action
        val answerIntent = Intent(this, CallActionReceiver::class.java).apply {
            action = "com.swiftcall.app.ANSWER_CALL"
            putExtra("uuid",        uuid)
            putExtra("callerName",  callerName)
            putExtra("callerPhoto", callerPhoto)
            putExtra("hasVideo",    hasVideo)
            putExtra("roomName",    roomName)
            putExtra("callType",    callType)
        }
        val answerPI = PendingIntent.getBroadcast(
            this, 1, answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline action
        val declineIntent = Intent(this, CallActionReceiver::class.java).apply {
            action = "com.swiftcall.app.DECLINE_CALL"
            putExtra("uuid",       uuid)
            putExtra("callerName", callerName)
            putExtra("hasVideo",   hasVideo)
        }
        val declinePI = PendingIntent.getBroadcast(
            this, 2, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val callLabel = if (hasVideo) "مكالمة فيديو" else "مكالمة صوتية"
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(callLabel)
            .setContentText(callerName)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPI, true)
            .setContentIntent(fullScreenPI)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(Uri.parse("android.resource://${packageName}/raw/ringtone"))
            .setTimeoutAfter(45_000L)
            .addAction(android.R.drawable.ic_menu_call,     "قبول",  answerPI)
            .addAction(android.R.drawable.ic_delete,        "رفض",   declinePI)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    // ── TelecomManager (system call UI on some devices) ──────────────────

    private fun reportToTelecom(uuid: String, callerName: String, hasVideo: Boolean) {
        try {
            val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val handle  = PhoneAccountHandle(
                android.content.ComponentName(this, CallConnectionService::class.java),
                PHONE_ACCOUNT_ID
            )
            val extras = android.os.Bundle().apply {
                putString("uuid",       uuid)
                putString("callerName", callerName)
                putBoolean("hasVideo",  hasVideo)
            }
            telecom.addNewIncomingCall(handle, extras)
            Log.d(TAG, "Reported to TelecomManager: $uuid")
        } catch (e: SecurityException) {
            Log.w(TAG, "TelecomManager requires MANAGE_OWN_CALLS — falling back to notification UI")
        } catch (e: Exception) {
            Log.w(TAG, "TelecomManager failed: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
    }
}
