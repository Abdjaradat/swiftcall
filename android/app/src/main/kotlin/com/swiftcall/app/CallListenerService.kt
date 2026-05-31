package com.swiftcall.app

import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.MetadataChanges

/**
 * Background service that listens to Firestore calls collection
 * even when the app is killed. This ensures incoming calls are
 * detected without relying on FCM or Cloud Functions.
 */
class CallListenerService : Service() {

    companion object {
        private const val TAG = "CallListenerService"
        private var instance: CallListenerService? = null

        fun isRunning(): Boolean = instance != null
    }

    private var callsListener: ListenerRegistration? = null
    private var currentUserId: String? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Service created")
        startListening()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        if (callsListener == null) {
            startListening()
        }
        return START_STICKY // Restart if killed
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startListening() {
        currentUserId = FirebaseAuth.getInstance().currentUser?.uid
        if (currentUserId == null) {
            Log.w(TAG, "No authenticated user, stopping service")
            stopSelf()
            return
        }

        Log.d(TAG, "Starting Firestore listener for user: $currentUserId")

        // Listen for new calls where receiverId == currentUserId and status == "ringing"
        callsListener = FirebaseFirestore.getInstance()
            .collection("calls")
            .whereEqualTo("receiverId", currentUserId)
            .whereEqualTo("status", "ringing")
            .addSnapshotListener(MetadataChanges.INCLUDE) { snapshots, error ->
                if (error != null) {
                    Log.e(TAG, "Firestore listener error", error)
                    return@addSnapshotListener
                }

                if (snapshots == null || snapshots.isEmpty) return@addSnapshotListener

                // Process each new ringing call
                for (doc in snapshots.documentChanges) {
                    if (doc.type == com.google.firebase.firestore.DocumentChange.Type.ADDED) {
                        val call = doc.document.data
                        handleIncomingCall(doc.document.id, call)
                    }
                }
            }
    }

    private fun handleIncomingCall(callId: String, callData: Map<String, Any>) {
        val callerName = callData["callerName"] as? String ?: "Unknown"
        val callerPhoto = callData["callerPhoto"] as? String ?: ""
        val roomName = callData["roomName"] as? String ?: ""
        val callType = callData["type"] as? String ?: "audio"
        val hasVideo = callType == "video"

        Log.d(TAG, "Incoming call from $callerName (callId=$callId)")

        // Start foreground service to show notification
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            putExtra("action", "start")
            putExtra("uuid", callId)
            putExtra("callerName", callerName)
            putExtra("callerPhoto", callerPhoto)
            putExtra("hasVideo", hasVideo)
            putExtra("roomName", roomName)
            putExtra("callType", callType)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        callsListener?.remove()
        callsListener = null
        Log.d(TAG, "Service destroyed")
    }
}
