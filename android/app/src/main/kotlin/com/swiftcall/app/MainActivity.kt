package com.swiftcall.app

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.swiftcall.app/call_manager"
    private lateinit var channel: MethodChannel
    private lateinit var telecomManager: TelecomManager
    private lateinit var phoneAccountHandle: PhoneAccountHandle

    companion object {
        private const val TAG = "MainActivity"
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
                    val uuid       = call.argument<String>("uuid")
                    val callerName = call.argument<String>("callerName")
                    val hasVideo   = call.argument<Boolean>("hasVideo") ?: false
                    if (uuid != null && callerName != null) {
                        triggerCallForegroundService(uuid, callerName, "", hasVideo, "", "audio")
                        result.success(true)
                    } else result.error("INVALID_ARGS", "Missing uuid/callerName", null)
                }
                "endNativeCall" -> {
                    val uuid = call.argument<String>("uuid")
                    if (uuid != null) {
                        endNativeCall(uuid)
                        result.success(true)
                    } else result.error("INVALID_ARGS", "Missing uuid", null)
                }
                "getLastKnownLocation" -> result.success(getLastKnownLocation())
                else -> result.notImplemented()
            }
        }

        telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        registerPhoneAccount()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleCallIntent(intent)
    }

    /**
     * Handles INCOMING_CALL, ANSWER_CALL, and DECLINE_CALL intents
     * sent from CallForegroundService or CallActionReceiver.
     */
    private fun handleCallIntent(intent: Intent?) {
        val action      = intent?.action ?: return
        val uuid        = intent.getStringExtra("uuid")        ?: return
        val callerName  = intent.getStringExtra("callerName")  ?: ""
        val callerPhoto = intent.getStringExtra("callerPhoto") ?: ""
        val hasVideo    = intent.getBooleanExtra("hasVideo", false)
        val roomName    = intent.getStringExtra("roomName")    ?: ""
        val callType    = intent.getStringExtra("callType")    ?: "audio"

        Log.d(TAG, "handleCallIntent: action=$action uuid=$uuid")

        when (action) {
            "com.swiftcall.app.INCOMING_CALL" -> {
                // App launched from notification tap — show incoming call screen in Flutter
                channel.invokeMethod("showCallScreen", mapOf(
                    "callId"      to uuid,
                    "callerName"  to callerName,
                    "callerPhoto" to callerPhoto,
                    "hasVideo"    to hasVideo,
                    "roomName"    to roomName,
                    "callType"    to callType,
                ))
            }
            "com.swiftcall.app.ANSWER_CALL" -> {
                // User tapped "Answer" on the notification
                channel.invokeMethod("answerCallFromNative", mapOf(
                    "callId"      to uuid,
                    "callerName"  to callerName,
                    "callerPhoto" to callerPhoto,
                    "hasVideo"    to hasVideo,
                    "roomName"    to roomName,
                    "callType"    to callType,
                ))
                // Stop ringing notification
                stopService(Intent(this, CallForegroundService::class.java))
            }
            "com.swiftcall.app.DECLINE_CALL" -> {
                // User tapped "Decline" on the notification
                channel.invokeMethod("declineCallFromNative", mapOf(
                    "callId"   to uuid,
                    "hasVideo" to hasVideo,
                ))
                stopService(Intent(this, CallForegroundService::class.java))
            }
        }
    }

    // ── Phone account registration ───────────────────────────────────────

    private fun registerPhoneAccount() {
        try {
            val componentName = ComponentName(packageName, CallConnectionService::class.java.name)
            phoneAccountHandle = PhoneAccountHandle(componentName, "SwiftCallConnectionServiceId")

            val phoneAccount = PhoneAccount.builder(phoneAccountHandle, "SwiftCall")
                .setCapabilities(
                    PhoneAccount.CAPABILITY_CALL_PROVIDER or
                    PhoneAccount.CAPABILITY_SUPPORTS_VIDEO_CALLING or
                    PhoneAccount.CAPABILITY_SELF_MANAGED
                )
                .build()
            telecomManager.registerPhoneAccount(phoneAccount)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register phone account: ${e.message}")
        }
    }

    // ── Native helpers ───────────────────────────────────────────────────

    private fun triggerCallForegroundService(
        uuid: String, callerName: String, callerPhoto: String,
        hasVideo: Boolean, roomName: String, callType: String
    ) {
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            putExtra("action",      "start")
            putExtra("uuid",        uuid)
            putExtra("callerName",  callerName)
            putExtra("callerPhoto", callerPhoto)
            putExtra("hasVideo",    hasVideo)
            putExtra("roomName",    roomName)
            putExtra("callType",    callType)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun endNativeCall(uuid: String) {
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            putExtra("action", "end")
            putExtra("uuid", uuid)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun getLastKnownLocation(): Map<String, Double>? {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return null
        }

        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
        var best: Location? = null
        for (provider in providers) {
            val location = try {
                manager.getLastKnownLocation(provider)
            } catch (_: Exception) {
                null
            }
            if (location != null && (best == null || location.time > best!!.time)) {
                best = location
            }
        }
        return best?.let {
            mapOf("latitude" to it.latitude, "longitude" to it.longitude)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isFlutterEngineReady = false
        flutterEngineReference = null
    }
}
