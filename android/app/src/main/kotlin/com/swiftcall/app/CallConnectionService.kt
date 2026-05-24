package com.swiftcall.app

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class CallConnectionService : ConnectionService() {

    companion object {
        private const val TAG     = "CallConnectionService"
        private const val CHANNEL = "com.swiftcall.app/call_manager"
        val activeConnections = mutableMapOf<String, CallConnection>()

        fun reportCallEnded(uuid: String, causeCode: Int) {
            Log.d(TAG, "reportCallEnded uuid=$uuid cause=$causeCode")
            val disconnectCause = DisconnectCause(causeCode)
            activeConnections[uuid]?.apply {
                setDisconnected(disconnectCause)
                destroy()
            }
            activeConnections.remove(uuid)
        }

        private fun invokeFlutter(method: String, args: Map<String, Any?>) {
            val engine = MainActivity.flutterEngineReference ?: return
            if (!MainActivity.isFlutterEngineReady) return
            Handler(Looper.getMainLooper()).post {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod(method, args)
            }
        }
    }

    inner class CallConnection(
        private val context: Context,
        val uuid: String,
        val callerName: String,
        val hasVideo: Boolean
    ) : Connection() {

        init {
            setConnectionProperties(PROPERTY_SELF_MANAGED)
            setAudioModeIsVoip(true)
            setCallerDisplayName(callerName, TelecomManager.PRESENTATION_ALLOWED)
            var caps = CAPABILITY_HOLD or CAPABILITY_SUPPORT_HOLD
            if (hasVideo) {
                setVideoState(android.telecom.VideoProfile.STATE_BIDIRECTIONAL)
                caps = caps or android.telecom.PhoneAccount.CAPABILITY_VIDEO_CALLING
            }
            connectionCapabilities = caps
            val address = Uri.fromParts("tel", callerName.replace(" ", ""), null)
            setAddress(address, TelecomManager.PRESENTATION_ALLOWED)
        }

        override fun onAnswer() {
            super.onAnswer()
            Log.d(TAG, "onAnswer uuid=$uuid")
            setActive()
            invokeFlutter("answerCallFromNative", mapOf(
                "uuid"       to uuid,
                "callerName" to callerName,
                "hasVideo"   to hasVideo,
            ))
        }

        override fun onReject() {
            super.onReject()
            Log.d(TAG, "onReject uuid=$uuid")
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            destroy()
            activeConnections.remove(uuid)
            invokeFlutter("declineCallFromNative", mapOf("uuid" to uuid))
        }

        override fun onDisconnect() {
            super.onDisconnect()
            Log.d(TAG, "onDisconnect uuid=$uuid")
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            destroy()
            activeConnections.remove(uuid)
            invokeFlutter("endCallFromNative", mapOf("uuid" to uuid))
        }
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val extras     = request?.extras ?: Bundle()
        val uuid       = extras.getString("uuid")
            ?: return Connection.createFailedConnection(DisconnectCause(DisconnectCause.ERROR))
        val callerName = extras.getString("callerName") ?: "Unknown"
        val hasVideo   = extras.getBoolean("hasVideo", false)

        val connection = CallConnection(this, uuid, callerName, hasVideo)
        activeConnections[uuid] = connection
        connection.setRinging()
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val extras     = request?.extras ?: Bundle()
        val uuid       = extras.getString("uuid")
            ?: return Connection.createFailedConnection(DisconnectCause(DisconnectCause.ERROR))
        val callerName = extras.getString("callerName") ?: "Unknown"
        val hasVideo   = extras.getBoolean("hasVideo", false)

        val connection = CallConnection(this, uuid, callerName, hasVideo)
        activeConnections[uuid] = connection
        connection.setDialing()
        return connection
    }
}
