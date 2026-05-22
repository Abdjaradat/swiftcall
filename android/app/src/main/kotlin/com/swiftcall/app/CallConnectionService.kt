package com.swiftcall.app

import android.telecom.Connection
import android.telecom.ConnectionService
import android.telecom.PhoneAccountHandle
import android.telecom.ConnectionRequest
import android.telecom.DisconnectCause
import android.net.Uri
import android.content.Context

class CallConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val connection = object : Connection() {
            init {
                setConnectionProperties(PROPERTY_SELF_MANAGED)
                setAudioModeIsVoip(true)
            }
        }
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val connection = object : Connection() {
            init {
                setConnectionProperties(PROPERTY_SELF_MANAGED)
                setAudioModeIsVoip(true)
            }
        }
        return connection
    }
}