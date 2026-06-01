import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'data/services/ad_service.dart';
import 'data/services/auth_service.dart';
import 'data/services/network_bypass_service.dart';
import 'data/services/notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler
  FlutterError.onError = (details) {
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
  };

  bool isDarkMode = true;
  String locale = 'ar';
  bool onboardingDone = false;

  try {
    // Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);
    debugPrint('✅ Firebase initialized');
  } catch (e, stack) {
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('Stack: $stack');
  }

  try {
    // Notifications
    await NotificationService.instance.initialize();
    debugPrint('✅ NotificationService initialized');

    // Update FCM token in Firestore on refresh
    NotificationService.instance.onTokenRefresh((token) {
      AuthService.instance.updateFcmToken(token);
    });
  } catch (e) {
    debugPrint('❌ NotificationService error: $e');
  }

  try {
    // Network bypass (proxy) initialization
    await NetworkBypassService.instance.initialize();
    debugPrint('✅ NetworkBypassService initialized');
  } catch (e) {
    debugPrint('❌ NetworkBypassService error: $e');
  }

  try {
    // Unity Ads — تهيئة مسبقة لتحميل الإعلانات
    AdService.instance.init();
    debugPrint('✅ AdService initialized');
  } catch (e) {
    debugPrint('❌ AdService error: $e');
  }

  try {
    // Timeago Arabic locale
    timeago.setLocaleMessages('ar', timeago.ArMessages());
  } catch (e) {
    debugPrint('❌ Timeago error: $e');
  }

  try {
    // Preferences
    final prefs = await SharedPreferences.getInstance();
    isDarkMode     = prefs.getBool(AppConstants.isDarkModeKey)    ?? true;
    locale         = prefs.getString(AppConstants.localeKey)      ?? 'ar';
    onboardingDone = prefs.getBool(AppConstants.onboardingDoneKey) ?? false;
    debugPrint('✅ SharedPreferences loaded');
  } catch (e, stack) {
    debugPrint('❌ SharedPreferences error: $e');
    debugPrint('Stack: $stack');
    // Clear corrupted prefs and use defaults
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ SharedPreferences cleared');
    } catch (_) {}
  }

  try {
    // Lock to portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  } catch (e) {
    debugPrint('❌ SystemChrome error: $e');
  }

  runApp(SwiftCallApp(
    isDarkMode: isDarkMode,
    locale: locale,
    onboardingDone: onboardingDone,
  ));
}
