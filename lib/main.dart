import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'data/services/auth_service.dart';
import 'data/services/network_bypass_service.dart';
import 'data/services/notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// Define the MethodChannel for shared communication
final MethodChannel _platformChannel = const MethodChannel('com.swiftcall.swiftcall/callkit');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the MethodChannel handler to receive calls from native
  _platformChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case "callAnswered":
        final uuid = call.arguments?['uuid'] as String?;
        debugPrint("Call with UUID $uuid answered by native CallKit");
        // Handle call answered logic (e.g., navigate to call screen, start media)
        break;
      case "callEnded":
        final uuid = call.arguments?['uuid'] as String?;
        debugPrint("Call with UUID $uuid ended by native CallKit");
        // Handle call ended logic (e.g., dismiss call screen)
        break;
      case "callHeld":
        final uuid = call.arguments?['uuid'] as String?;
        final isOnHold = call.arguments?['isOnHold'] as bool?;
        debugPrint("Call with UUID $uuid hold status: $isOnHold");
        // Handle call hold status change
        break;
      // Add other CallKit action handlers as needed
      default:
        debugPrint("Unhandled method call from native: ${call.method}");
        // throw MissingPluginException(); // Uncomment if unhandled calls should throw
    }
  });

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

  // Timeago Arabic locale
  timeago.setLocaleMessages('ar', timeago.ArMessages());

  // Preferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode      = prefs.getBool(AppConstants.isDarkModeKey)   ?? true;
  final locale          = prefs.getString(AppConstants.localeKey)     ?? 'ar';
  final onboardingDone  = prefs.getBool(AppConstants.onboardingDoneKey) ?? false;

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
    navigatorKey: navigatorKey, // Pass the navigator key
  ));

  // Set the app context for CallManager (used for platform check)
  CallManager.appContext = navigatorKey.currentContext;

  // Example of how to report an incoming call to native platform
  // This would typically be triggered by an FCM message or WebSocket event.
  // Uncomment and fill with actual call details to test.
  /*
  _reportIncomingCallToNative(
    uuid: 'a-unique-call-id-123',
    handle: '1234567890', // Caller's phone number or email
    callerName: 'Alice Smith',
    hasVideo: true,
  );
  */
}

/// Function to report an incoming call to the native platform.
/// On iOS, this will use CallKit. On Android, it would trigger a custom notification.
Future<void> _reportIncomingCallToNative({
  required String uuid,
  required String handle,
  required String callerName,
  bool hasVideo = false,
}) async {
  try {
    if (Theme.of(navigatorKey.currentContext!).platform == TargetPlatform.iOS) {
      await _platformChannel.invokeMethod('reportIncomingCall', {
        'uuid': uuid,
        'handle': handle,
        'callerName': callerName,
        'hasVideo': hasVideo,
      });
      debugPrint('Incoming call reported to iOS CallKit.');
    } else if (Theme.of(navigatorKey.currentContext!).platform == TargetPlatform.android) {
      // Implement Android specific incoming call notification/UI here,
      // possibly using a local notification or a custom full-screen intent.
      debugPrint('Incoming call notification for Android (implementation needed).');
    }
  } on PlatformException catch (e) {
    debugPrint("Failed to report incoming call to native: '${e.message}'.");
  } catch (e) {
    debugPrint("An unexpected error occurred while reporting incoming call: $e");
  }
}
