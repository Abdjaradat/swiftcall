package com.swiftcall.app

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log

class CallConnectionService : ConnectionService() {

    companion object {
        private const val TAG = "CallConnectionService"
        val activeConnections = mutableMapOf<String, CallConnection>()

        fun reportCallEnded(uuid: String, causeCode: Int) {
            Log.d(TAG, "Reporting call ended for UUID: $uuid with cause code: $causeCode")
            val disconnectCause = DisconnectCause(causeCode)
            activeConnections[uuid]?.apply {
                setDisconnected(disconnectCause)
                destroy()
            }
            activeConnections.remove(uuid)
        }
    }

    inner class CallConnection(
        private val context: Context,
        val uuid: String,
        callerName: String,
        hasVideo: Boolean
    ) : Connection() {

        init {
            Log.d(TAG, "New CallConnection created for UUID: $uuid, Caller: $callerName, Video: $hasVideo")
            setConnectionProperties(PROPERTY_SELF_MANAGED)
            setAudioModeIsVoip(true)
            setCallerDisplayName(callerName, TelecomManager.PRESENTATION_ALLOWED)
            if (hasVideo) {
                setVideoState(Connection.STATE_BIDIRECTIONAL)
                connectionCapabilities = connectionCapabilities or Connection.CAPABILITY_SUPPORTS_VT_LOCAL or Connection.CAPABILITY_SUPPORTS_VT_REMOTE
            }
            // Set initial address for the connection
            val address = Uri.fromParts("tel", callerName.replace(" ", ""), null) // Using callerName as a pseudo-number
            setAddress(address, TelecomManager.PRESENTATION_ALLOWED)
        }

        override fun onAnswer() {
            super.onAnswer()
            Log.d(TAG, "CallConnection onAnswer for UUID: $uuid")
            setActive()
            // TODO: Notify Flutter app that call is answered
        }

        override fun onReject() {
            super.onReject()
            Log.d(TAG, "CallConnection onReject for UUID: $uuid")
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            destroy()
            activeConnections.remove(uuid)
            // TODO: Notify Flutter app that call is rejected
        }

        override fun onDisconnect() {
            super.onDisconnect()
            Log.d(TAG, "CallConnection onDisconnect for UUID: $uuid")
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            destroy()
            activeConnections.remove(uuid)
            // TODO: Notify Flutter app that call is disconnected
        }
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(TAG, "onCreateIncomingConnection: ${request?.extras}")
        val extras: Bundle = request?.extras ?: Bundle()
        val uuid = extras.getString("uuid") ?: return Connection.createFailedConnection(DisconnectCause(DisconnectCause.ERROR))
        val callerName = extras.getString("callerName") ?: "Unknown Caller"
        val hasVideo = extras.getBoolean("hasVideo", false)

        val connection = CallConnection(this, uuid, callerName, hasVideo)
        activeConnections[uuid] = connection
        connection.setRinging()
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(TAG, "onCreateOutgoingConnection: ${request?.extras}")
        val extras: Bundle = request?.extras ?: Bundle()
        val uuid = extras.getString("uuid") ?: return Connection.createFailedConnection(DisconnectCause(DisconnectCause.ERROR))
        val callerName = extras.getString("callerName") ?: "Unknown Caller"
        val hasVideo = extras.getBoolean("hasVideo", false)

        val connection = CallConnection(this, uuid, callerName, hasVideo)
        activeConnections[uuid] = connection
        connection.setDialing()
        return connection
    }
}
