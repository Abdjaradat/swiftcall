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
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query

/**
 * Background service that listens to new messages in all user's chats
 * and shows notifications even when app is killed.
 */
class MessageListenerService : Service() {

    companion object {
        private const val TAG = "MessageListenerService"
        private const val CHANNEL_ID = "swiftcall_messages"
        private const val CHANNEL_NAME = "الرسائل"
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
        createNotificationChannel()
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات الرسائل الجديدة"
                enableVibration(true)
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startListening() {
        currentUserId = FirebaseAuth.getInstance().currentUser?.uid
        if (currentUserId == null) {
            Log.w(TAG, "No authenticated user, stopping service")
            stopSelf()
            return
        }

        Log.d(TAG, "Starting Firestore listener for messages, user: $currentUserId")

        // Listen for all chats where user is a participant
        val chatListener = FirebaseFirestore.getInstance()
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

        val messageListener = FirebaseFirestore.getInstance()
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
                    if (doc.type == com.google.firebase.firestore.DocumentChange.Type.ADDED) {
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
