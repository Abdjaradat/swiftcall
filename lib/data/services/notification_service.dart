import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const int _callNotificationId = 999;

  // ── iOS CallKit/PushKit channel ─────────────────────────────────────────
  static const _iosChannel = MethodChannel('com.swiftcall.swiftcall/callkit');
  // ── Android call manager channel ────────────────────────────────────────
  static const _androidChannel = MethodChannel('com.swiftcall.app/call_manager');

  static NotificationService get instance => _instance;
  static final NotificationService _instance = NotificationService._();
  NotificationService._();

  // Called when a push arrives and the user should see the incoming call screen
  static Map<String, dynamic>? pendingCallData;
  static void Function(Map<String, dynamic>)? onCallOpened;

  // Called when the user answers from the native UI (CallKit / notification button)
  // → Flutter should navigate directly to the active call screen
  static void Function(Map<String, dynamic>)? onCallAnsweredFromNative;

  // Called when the user declines from native UI
  static void Function(Map<String, dynamic>)? onCallDeclinedFromNative;

  // Called when the caller cancels (FCM call_cancelled message)
  static void Function(String callId)? onCallCancelled;

  // Called when VoIP token is received (iOS PushKit) — save to Firestore
  static void Function(String token)? onVoipTokenReceived;

  Future<void> initialize() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      criticalAlert: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _createChannels();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null && initialMessage.data['type'] == 'call') {
      pendingCallData = initialMessage.data;
    }

    // ── Native → Flutter channel handlers ──────────────────────────────
    _setupNativeChannelHandlers();
  }

  // ── Native channel setup ────────────────────────────────────────────────

  void _setupNativeChannelHandlers() {
    if (Platform.isIOS) {
      _iosChannel.setMethodCallHandler(_handleIosNativeCall);
    }
    if (Platform.isAndroid) {
      _androidChannel.setMethodCallHandler(_handleAndroidNativeCall);
    }
  }

  Future<dynamic> _handleIosNativeCall(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};

    switch (call.method) {
      case 'voipTokenReceived':
        final token = call.arguments as String?;
        if (token != null && onVoipTokenReceived != null) {
          onVoipTokenReceived!(token);
        }

      case 'answerCallFromNative':
        // User answered via CallKit native screen
        if (onCallAnsweredFromNative != null) {
          onCallAnsweredFromNative!(args);
        }
        await cancelCallNotification();

      case 'endCallFromNative':
        // User declined via CallKit native screen
        if (onCallDeclinedFromNative != null) {
          onCallDeclinedFromNative!(args);
        }
        await cancelCallNotification();
    }
  }

  Future<dynamic> _handleAndroidNativeCall(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};

    switch (call.method) {
      case 'showCallScreen':
        // Notification tapped → show incoming call screen in Flutter
        if (onCallOpened != null) {
          onCallOpened!(args);
        }

      case 'answerCallFromNative':
        // User tapped "Answer" button on Android notification
        if (onCallAnsweredFromNative != null) {
          onCallAnsweredFromNative!(args);
        }
        await cancelCallNotification();

      case 'declineCallFromNative':
        // User tapped "Decline" button on Android notification
        if (onCallDeclinedFromNative != null) {
          onCallDeclinedFromNative!(args);
        }
        await cancelCallNotification();
    }
  }

  // ── Local notification channels ─────────────────────────────────────────

  Future<void> _createChannels() async {
    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      'swiftcall_channel',
      'SwiftCall إشعارات',
      description: 'إشعارات المكالمات والرسائل',
      importance: Importance.high,
      playSound: true,
    ));

    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      'swiftcall_calls',
      'SwiftCall مكالمات',
      description: 'إشعارات المكالمات الواردة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
    ));
  }

  // ── FCM handlers ────────────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;

    // ── Incoming call ──────────────────────────────────────────────────────
    if (data['type'] == 'call') {
      // On Android when app is foreground, show a local high-priority notification.
      // (The Firestore listener in app.dart also shows the in-app incoming call screen.)
      if (Platform.isAndroid) {
        await showCallNotification(
          callerName:  data['callerName']  ?? '',
          callerPhoto: data['callerPhoto'],
          isVideoCall: data['callType'] == 'video',
        );
      }
      // On iOS, PushKit/CallKit handles kill/background; Firestore listener handles foreground.
      return;
    }

    // ── Call cancelled by caller ───────────────────────────────────────────
    if (data['type'] == 'call_cancelled') {
      await cancelCallNotification();
      final callId = data['callId'] as String?;
      if (callId != null && onCallCancelled != null) {
        onCallCancelled!(callId);
      }
      return;
    }

    // ── Regular notification ───────────────────────────────────────────────
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'swiftcall_channel', 'SwiftCall إشعارات',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'call' && onCallOpened != null) {
      onCallOpened!(data);
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Local notification tap — the Firestore listener will surface the call
  }

  // ── Public API ───────────────────────────────────────────────────────────

  Future<String?> getToken() => _fcm.getToken();

  void onTokenRefresh(void Function(String token) callback) {
    _fcm.onTokenRefresh.listen(callback);
  }

  Future<void> showCallNotification({
    required String callerName,
    required String? callerPhoto,
    required bool isVideoCall,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'swiftcall_calls', 'SwiftCall مكالمات',
      channelDescription: 'إشعارات المكالمات الواردة',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      autoCancel: false,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      timeoutAfter: 60000,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ringtone.wav',
      categoryIdentifier: 'incoming_call',
    );

    await _local.show(
      _callNotificationId,
      isVideoCall ? 'مكالمة فيديو واردة' : 'مكالمة صوتية واردة',
      callerName,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancelCallNotification() async {
    await _local.cancel(_callNotificationId);
  }
}
