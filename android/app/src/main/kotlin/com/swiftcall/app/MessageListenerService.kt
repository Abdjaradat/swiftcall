package com.swiftcall.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.auth.ktx.auth
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase

/**
 * Background service that listens to new messages in all user's chats
 * and shows notifications even when app is killed.
 */
class MessageListenerService : Service() {

    companion object {
        private const val TAG = "MessageListenerService"
        private const val CHANNEL_ID = "swiftcall_messages"
        private const val CHANNEL_NAME = "الرسائل"
        private const val LISTENER_CHANNEL_ID = "swiftcall_message_listener"
        private const val NOTIFICATION_ID = 1002
        private var instance: MessageListenerService? = null
        private val shownMessageIds = mutableSetOf<String>()

        fun isRunning(): Boolean = instance != null
    }

    private val chatListeners = mutableListOf<ListenerRegistration>()
    private var currentUserId: String? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Service created")
        createNotificationChannels()
        startForeground(NOTIFICATION_ID, createListenerNotification())
        startListening()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        if (chatListeners.isEmpty()) {
            startListening()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Channel for actual message notifications
            val messageChannel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات الرسائل الجديدة"
                enableVibration(true)
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null)
            }
            notificationManager.createNotificationChannel(messageChannel)

            // Channel for listener service (low priority)
            val listenerChannel = NotificationChannel(
                LISTENER_CHANNEL_ID,
                "خدمة الاستماع للرسائل",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "تعمل في الخلفية لاستقبال الرسائل"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(listenerChannel)
        }
    }

    private fun createListenerNotification(): android.app.Notification {
        return NotificationCompat.Builder(this, LISTENER_CHANNEL_ID)
            .setContentTitle("SwiftCall")
            .setContentText("جاهز لاستقبال الرسائل")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    private fun startListening() {
        currentUserId = Firebase.auth.currentUser?.uid
        if (currentUserId == null) {
            Log.w(TAG, "No authenticated user, stopping service")
            stopSelf()
            return
        }

        Log.d(TAG, "Starting Firestore listener for messages, user: $currentUserId")

        // Listen for all chats where user is a participant
        val chatListener = Firebase.firestore
            .collection("chats")
            .whereArrayContains("participantIds", currentUserId!!)
            .addSnapshotListener { chatSnapshots, error ->
                if (error != null) {
                    Log.e(TAG, "Chat listener error", error)
                    return@addSnapshotListener
                }

                if (chatSnapshots == null || chatSnapshots.isEmpty) return@addSnapshotListener

                // For each chat, listen to new messages
                for (chatDoc in chatSnapshots.documents) {
                    val chatId = chatDoc.id
                    listenToChatMessages(chatId)
                }
            }

        chatListeners.add(chatListener)
    }

    private fun listenToChatMessages(chatId: String) {
        // Check if already listening to this chat
        if (chatListeners.any { it.toString().contains(chatId) }) {
            return
        }

        val messageListener = Firebase.firestore
            .collection("chats")
            .document(chatId)
            .collection("messages")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .addSnapshotListener { messageSnapshots, error ->
                if (error != null) {
                    Log.e(TAG, "Message listener error for chat $chatId", error)
                    return@addSnapshotListener
                }

                if (messageSnapshots == null || messageSnapshots.isEmpty) return@addSnapshotListener

                for (doc in messageSnapshots.documentChanges) {
                    if (doc.type == DocumentChange.Type.ADDED) {
                        val message = doc.document.data
                        val messageId = doc.document.id

                        // Skip if already shown or if I'm the sender
                        val senderId = message["senderId"] as? String
                        if (senderId == currentUserId || shownMessageIds.contains(messageId)) {
                            continue
                        }

                        shownMessageIds.add(messageId)
                        showMessageNotification(chatId, message)
                    }
                }
            }

        chatListeners.add(messageListener)
    }

    private fun showMessageNotification(chatId: String, message: Map<String, Any>) {
        val senderName = message["senderName"] as? String ?: "مستخدم"
        val content = when (message["type"] as? String) {
            "image" -> "📷 صورة"
            "video" -> "🎥 فيديو"
            "audio" -> "🎤 رسالة صوتية"
            "file" -> "📎 ملف"
            "location" -> "📍 موقع"
            else -> message["content"] as? String ?: "رسالة جديدة"
        }

        // Intent to open chat when notification is tapped
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("chatId", chatId)
            putExtra("action", "open_chat")
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            chatId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(senderName)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
            .setVibrate(longArrayOf(0, 500, 250, 500))
            .setContentIntent(pendingIntent)
            .setColor(0xFF6C63FF.toInt())
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(chatId.hashCode(), notification)

        Log.d(TAG, "Notification shown for chat $chatId from $senderName")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        chatListeners.forEach { it.remove() }
        chatListeners.clear()
        shownMessageIds.clear()
        Log.d(TAG, "Service destroyed")
    }
}
