import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const int _callNotificationId = 999;

  static NotificationService get instance => _instance;
  static final NotificationService _instance = NotificationService._();
  NotificationService._();

  static Map<String, dynamic>? pendingCallData;
  static void Function(Map<String, dynamic> callData)? onCallOpened;

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
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _createChannels();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final data = initialMessage.data;
      if (data['type'] == 'call') {
        pendingCallData = data;
      }
    }
  }

  Future<void> _createChannels() async {
    const msgChannel = AndroidNotificationChannel(
      'swiftcall_channel',
      'SwiftCall إشعارات',
      description: 'إشعارات المكالمات والرسائل',
      importance: Importance.high,
      playSound: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(msgChannel);

    const callChannel = AndroidNotificationChannel(
      'swiftcall_calls',
      'SwiftCall مكالمات',
      description: 'إشعارات المكالمات الواردة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'call') {
      await showCallNotification(
        callerName: data['callerName'] ?? '',
        callerPhoto: data['callerPhoto'],
        isVideoCall: data['callType'] == 'video',
      );
      return;
    }
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'swiftcall_channel',
          'SwiftCall إشعارات',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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
    // Called when user taps the call notification
  }

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
      'swiftcall_calls',
      'SwiftCall مكالمات',
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
      timeoutAfter: 45000,
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
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancelCallNotification() async {
    await _local.cancel(_callNotificationId);
  }
}
