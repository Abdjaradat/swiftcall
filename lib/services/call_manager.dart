import 'dart:async';
import 'package:flutter/material.dart'; // Import for Theme.of and TargetPlatform
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;

  final MethodChannel _methodChannel =
      const MethodChannel('com.swiftcall.app/call_manager');

  CallManager._internal() {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'answerCall':
        final String uuid = call.arguments['uuid'];
        print('Flutter: Answer call for UUID: $uuid');
        // Handle answering the call in Flutter UI
        // Example: Navigate to call screen
        break;
      case 'endCall':
        final String uuid = call.arguments['uuid'];
        print('Flutter: End call for UUID: $uuid');
        // Handle ending the call in Flutter UI
        break;
      case 'muteCall':
        final String uuid = call.arguments['uuid'];
        final bool isMuted = call.arguments['isMuted'];
        print('Flutter: Mute call for UUID: $uuid, Muted: $isMuted');
        // Handle muting the call in Flutter UI
        break;
      case 'sendVoIPToken':
        final String token = call.arguments['token'];
        print('Flutter: Received VoIP Token: $token');
        // Send this token to your backend
        break;
      default:
        print('Flutter: Unknown method call: ${call.method}');
    }
    return null;
  }

  // --- Methods to be called from Flutter app ---

  // For Android, this would report an incoming call to ConnectionService
  // For iOS, this is handled by PushKit/CallKit directly when receiving VoIP push
  Future<void> displayIncomingCall({
    required String uuid,
    required String callerName,
    required bool hasVideo,
  }) async {
    try {
      if (appContext != null && Theme.of(appContext!).platform == TargetPlatform.iOS) {
        // iOS incoming call is primarily handled by PushKit/CallKit native side
        // No direct Flutter call needed here unless it's a non-VoIP push
        print('iOS will handle incoming call via PushKit/CallKit');
      } else if (appContext != null && Theme.of(appContext!).platform == TargetPlatform.android) {
        await _methodChannel.invokeMethod('displayIncomingCall', {
          'uuid': uuid,
          'callerName': callerName,
          'hasVideo': hasVideo,
        });
        print('Android: Displayed incoming call via ConnectionService');
      }
    } on PlatformException catch (e) {
      print("Failed to display incoming call: '${e.message}'.");
    }
  }

  Future<void> endNativeCall(String uuid) async {
    try {
      await _methodChannel.invokeMethod('endNativeCall', {'uuid': uuid});
      print('Native call ended for UUID: $uuid');
    } on PlatformException catch (e) {
      print("Failed to end native call: '${e.message}'.");
    }
  }

  // To be called when your backend sends a regular FCM data message
  // for Android to trigger the full-screen intent directly.
  static Future<void> handleIncomingCallNotification(Map<String, dynamic> data) async {
    print("Handling incoming call notification in killed state: $data");
    final String? callerName = data['caller_name'] as String?;
    final String? callId = data['call_id'] as String?;
    final bool hasVideo = data['has_video'] == 'true'; // Assuming boolean as string

    if (callerName != null && callId != null) {
      // For Android, trigger native call UI
      if (appContext != null && Theme.of(appContext!).platform == TargetPlatform.android) {
        // This invokes the native Android code to show the full-screen intent
        // and handle the call through ConnectionService.
        await _instance._methodChannel.invokeMethod('showIncomingCallUI', {
          'uuid': callId,
          'callerName': callerName,
          'hasVideo': hasVideo,
        });
      }
    }
  }

  static BuildContext? appContext;
}
