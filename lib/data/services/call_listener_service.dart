import 'package:flutter/services.dart';

/// Service to start/stop native Firestore listeners
class CallListenerServiceManager {
  static const _channel = MethodChannel('com.swiftcall.app/call_listener');

  /// Start background Firestore listener for calls
  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startCallListener');
      print('CallListenerService started');
    } catch (e) {
      print('CallListenerService.start ERROR: $e');
    }
  }

  /// Stop background Firestore listener for calls
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopCallListener');
      print('CallListenerService stopped');
    } catch (e) {
      print('CallListenerService.stop ERROR: $e');
    }
  }

  /// Start background Firestore listener for messages
  static Future<void> startMessageListener() async {
    try {
      await _channel.invokeMethod('startMessageListener');
      print('MessageListenerService started');
    } catch (e) {
      print('MessageListenerService.start ERROR: $e');
    }
  }

  /// Stop background Firestore listener for messages
  static Future<void> stopMessageListener() async {
    try {
      await _channel.invokeMethod('stopMessageListener');
      print('MessageListenerService stopped');
    } catch (e) {
      print('MessageListenerService.stop ERROR: $e');
    }
  }
}
