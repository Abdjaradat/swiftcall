package com.swiftcall.app

import android.telecom.ConnectionRequest

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telecom.ConnectionService
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.swiftcall.app/call_manager"
    private lateinit var channel: MethodChannel
    private lateinit var telecomManager: TelecomManager
    private lateinit var phoneAccountHandle: PhoneAccountHandle

    companion object {
        var flutterEngineReference: FlutterEngine? = null
        var isFlutterEngineReady: Boolean = false
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineReference = flutterEngine
        isFlutterEngineReady = true

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingCallUI" -> {
                    val uuid = call.argument<String>("uuid")
                    val callerName = call.argument<String>("callerName")
                    val hasVideo = call.argument<Boolean>("hasVideo") ?: false
                    if (uuid != null && callerName != null) {
                        showIncomingCallUI(uuid, callerName, hasVideo)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing UUID or callerName", null)
                    }
                }
                "endNativeCall" -> {
                    val uuid = call.argument<String>("uuid")
                    if (uuid != null) {
                        endNativeCall(uuid)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing UUID", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        registerPhoneAccount()
    }

    private fun registerPhoneAccount() {
        val componentName = ComponentName(packageName, CallConnectionService::class.java.name)
        phoneAccountHandle = PhoneAccountHandle(componentName, "SwiftCallConnectionServiceId")

        val builder = PhoneAccount.builder(phoneAccountHandle, "SwiftCall")
            .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER or PhoneAccount.CAPABILITY_SUPPORTS_VIDEO_CALLING)
            .setIcon(PhoneAccount.builder(phoneAccountHandle, "SwiftCall").build().icon) // Use default icon or provide a custom one

        val phoneAccount = builder.build()
        telecomManager.registerPhoneAccount(phoneAccount)
    }

    private fun showIncomingCallUI(uuid: String, callerName: String, hasVideo: Boolean) {
        if (!telecomManager.defaultDialerPackage.equals(packageName)) {
            // Your app is not the default dialer, show a notification to open the app
            // This is a fallback for when ConnectionService might not trigger the full UI directly
            val notificationIntent = Intent(this, MainActivity::class.java).apply {
                action = "com.swiftcall.app.INCOMING_CALL"
                putExtra("uuid", uuid)
                putExtra("callerName", callerName)
                putExtra("hasVideo", hasVideo)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            startActivity(notificationIntent)
            return
        }

        val extras = Bundle().apply {
            putString("uuid", uuid)
            putString("callerName", callerName)
            putBoolean("hasVideo", hasVideo)
            putParcelable(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, phoneAccountHandle)
        }

        val connectionRequest = ConnectionRequest(
            phoneAccountHandle,
            null, // No incoming address if it's a generic handle
            extras
        )

        // Start Foreground Service for higher priority processing and UI display
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            putExtra("uuid", uuid)
            putExtra("callerName", callerName)
            putExtra("hasVideo", hasVideo)
            putExtra("action", "start")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
    }

    private fun endNativeCall(uuid: String) {
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            putExtra("uuid", uuid)
            putExtra("action", "end")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == "com.swiftcall.app.INCOMING_CALL") {
            // Handle intent when app is already open
            val uuid = intent.getStringExtra("uuid")
            val callerName = intent.getStringExtra("callerName")
            val hasVideo = intent.getBooleanExtra("hasVideo", false)
            if (uuid != null && callerName != null) {
                // You might want to navigate to a call screen here in Flutter
                channel.invokeMethod("showCallScreen", mapOf("uuid" to uuid, "callerName" to callerName, "hasVideo" to hasVideo))
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isFlutterEngineReady = false
        flutterEngineReference = null
    }
}
