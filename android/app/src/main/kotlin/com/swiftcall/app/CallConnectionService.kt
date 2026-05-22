package com.swiftcall.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import android.telecom.DisconnectCause

class CallConnectionService : ConnectionService() {

    companion object {
        private const val TAG = "CallConnectionService"
        val activeConnections = mutableMapOf<String, MyConnection>()
        private var methodChannel: MethodChannel? = null

        fun setupMethodChannel(flutterEngine: FlutterEngine) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.swiftcall.app/call_manager")
        }

        fun reportCallEnded(uuid: String, reason: Int) {
            activeConnections[uuid]?.setDisconnected(DisconnectCause(reason))
            activeConnections[uuid]?.destroy()
            activeConnections.remove(uuid)
        }
    }

    override fun onCreateIncomingConnection(
        connectionRequest: ConnectionRequest
    ): Connection? {
        Log.d(TAG, "onCreateIncomingConnection: ${connectionRequest.extras}")

        val extras = connectionRequest.extras
        val uuid = extras.getString("uuid")
        val callerName = extras.getString("callerName")
        val hasVideo = extras.getBoolean("hasVideo", false)

        if (uuid == null || callerName == null) {
            return Connection.createFailedConnection(connectionRequest.address)
        }

        val newConnection = MyConnection(this, uuid, callerName, hasVideo)
        newConnection.setConnectionProperties(Connection.PROPERTY_SELF_MANAGED)
        newConnection.setAddress(Uri.parse("tel:$callerName"), TelecomManager.PRESENTATION_ALLOWED)
        newConnection.setCallerDisplayName(callerName, TelecomManager.PRESENTATION_ALLOWED)
        if (hasVideo) {
            newConnection.setVideoState(Connection.STATE_ACTIVE) // Indicates video call capable
            newConnection.connectionProperties = newConnection.connectionProperties or Connection.CAPABILITY_SUPPORTS_VT_LOCAL_RX
            newConnection.connectionProperties = newConnection.connectionProperties or Connection.CAPABILITY_SUPPORTS_VT_LOCAL_TX
            newConnection.connectionProperties = newConnection.connectionProperties or Connection.CAPABILITY_SUPPORTS_VT_REMOTE_RX
            newConnection.connectionProperties = newConnection.connectionProperties or Connection.CAPABILITY_SUPPORTS_VT_REMOTE_TX
        }


        newConnection.setRinging()
        activeConnections[uuid] = newConnection

        // Inform Flutter that an incoming call is being processed by the native system
        methodChannel?.invokeMethod("onIncomingCall", mapOf("uuid" to uuid, "callerName" to callerName, "hasVideo" to hasVideo))

        return newConnection
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called with intent: $intent")
        if (MainActivity.isFlutterEngineReady && methodChannel == null) {
            MainActivity.flutterEngineReference?.let { setupMethodChannel(it) }
        }
        return START_NOT_STICKY
    }

    class MyConnection(
        private val context: Context,
        private val uuid: String,
        private val callerName: String,
        private val hasVideo: Boolean
    ) : Connection() {

        init {
            Log.d(TAG, "MyConnection created for UUID: $uuid, Caller: $callerName")
            connectionProperties = Connection.PROPERTY_SELF_MANAGED
            if (hasVideo) {
                setVideoState(Connection.STATE_ACTIVE)
            }
        }

        override fun onAnswer() {
            Log.d(TAG, "onAnswer for UUID: $uuid")
            // Inform Flutter app to answer the call
            if (methodChannel != null) {
                methodChannel!!.invokeMethod("answerCall", mapOf("uuid" to uuid, "callerName" to callerName, "hasVideo" to hasVideo))
            } else {
                Log.e(TAG, "MethodChannel not initialized for onAnswer")
            }
            setActive()

            // Stop foreground service after call is answered
            val serviceIntent = Intent(context, CallForegroundService::class.java).apply {
                putExtra("action", "stop")
            }
            context.stopService(serviceIntent)
        }

        override fun onDisconnect() {
            Log.d(TAG, "onDisconnect for UUID: $uuid")
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            destroy()
            activeConnections.remove(uuid)

            // Inform Flutter app to end the call
            if (methodChannel != null) {
                methodChannel!!.invokeMethod("endCall", mapOf("uuid" to uuid, "callerName" to callerName))
            } else {
                Log.e(TAG, "MethodChannel not initialized for onDisconnect")
            }

            // Stop foreground service
            val serviceIntent = Intent(context, CallForegroundService::class.java).apply {
                putExtra("action", "stop")
            }
            context.stopService(serviceIntent)
        }

        override fun onReject() {
            Log.d(TAG, "onReject for UUID: $uuid")
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            destroy()
            activeConnections.remove(uuid)

            // Inform Flutter app that the call was rejected
            if (methodChannel != null) {
                methodChannel!!.invokeMethod("endCall", mapOf("uuid" to uuid, "callerName" to callerName, "isRejected" to true))
            } else {
                Log.e(TAG, "MethodChannel not initialized for onReject")
            }

            // Stop foreground service
            val serviceIntent = Intent(context, CallForegroundService::class.java).apply {
                putExtra("action", "stop")
            }
            context.stopService(serviceIntent)
        }

        override fun onHold() {
            Log.d(TAG, "onHold for UUID: $uuid")
            setOnHold()
            if (methodChannel != null) {
                methodChannel!!.invokeMethod("muteCall", mapOf("uuid" to uuid, "isMuted" to true))
            }
        }

        override fun onUnhold() {
            Log.d(TAG, "onUnhold for UUID: $uuid")
            setActive()
            if (methodChannel != null) {
                methodChannel!!.invokeMethod("muteCall", mapOf("uuid" to uuid, "isMuted" to false))
            }
        }

        override fun onStateChanged(state: Int) {
            super.onStateChanged(state)
            Log.d(TAG, "Connection state changed for $uuid to $state")
            // Can pass state changes to Flutter if needed
        }
    }
}
