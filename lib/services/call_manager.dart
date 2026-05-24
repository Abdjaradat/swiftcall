import 'package:flutter/services.dart';

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
        // Native side answered the call — handled by app.dart incoming call listener
        break;
      case 'endCall':
        // Native side ended the call — handled by CallBloc
        break;
      case 'muteCall':
        // Native side muted the call — no direct action needed here
        break;
      case 'sendVoIPToken':
        // VoIP token is sent to your backend for push notifications
        break;
      default:
        break;
    }
    return null;
  }

  Future<void> endNativeCall(String uuid) async {
    try {
      await _methodChannel.invokeMethod('endNativeCall', {'uuid': uuid});
    } on PlatformException catch (_) {}
  }
}
