import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:google_fonts/google_fonts.dart';

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

  // Use locally bundled Cairo font — never fetch from network
  GoogleFonts.config.allowRuntimeFetching = false;

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

  // Notifications
  await NotificationService.instance.initialize();

  // Update FCM token in Firestore on refresh
  NotificationService.instance.onTokenRefresh((token) {
    AuthService.instance.updateFcmToken(token);
  });

  // Network bypass (proxy) initialization
  await NetworkBypassService.instance.initialize();

  // Unity Ads — تهيئة مسبقة لتحميل الإعلانات
  AdService.instance.init();

  // Timeago Arabic locale
  timeago.setLocaleMessages('ar', timeago.ArMessages());

  // Preferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode     = prefs.getBool(AppConstants.isDarkModeKey)    ?? true;
  final locale         = prefs.getString(AppConstants.localeKey)      ?? 'ar';
  final onboardingDone = prefs.getBool(AppConstants.onboardingDoneKey) ?? false;

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

  runApp(SwiftCallApp(
    isDarkMode: isDarkMode,
    locale: locale,
    onboardingDone: onboardingDone,
  ));
}
