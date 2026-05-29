import 'package:flutter/services.dart';

class WakelockService {
  static const _channel = MethodChannel('com.swiftcall.app/call_manager');

  static WakelockService get instance => _instance;
  static final WakelockService _instance = WakelockService._();
  WakelockService._();

  Future<void> enable() async {
    try {
      await _channel.invokeMethod('enableWakeLock');
    } catch (_) {}
  }

  Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableWakeLock');
    } catch (_) {}
  }
}
