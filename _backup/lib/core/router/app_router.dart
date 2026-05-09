import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/call_model.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/call/screens/incoming_call_screen.dart';
import '../../features/call/screens/video_call_screen.dart';
import '../../features/call/screens/voice_call_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

class AppRouter {
  static const String onboarding   = '/onboarding';
  static const String login         = '/login';
  static const String home          = '/home';
  static const String chat          = '/chat';
  static const String videoCall     = '/video-call';
  static const String voiceCall     = '/voice-call';
  static const String incomingCall  = '/incoming-call';
  static const String settings      = '/settings';

  static GoRouter router({
    required bool onboardingDone,
    required bool isAuthenticated,
  }) {
    return GoRouter(
      initialLocation: _initialRoute(onboardingDone, isAuthenticated),
      routes: [
        GoRoute(
          path: onboarding,
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: login,
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: home,
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '$chat/:chatId',
          builder: (_, state) {
            final chatId    = state.pathParameters['chatId']!;
            final otherUser = state.extra as UserModel?;
            return ChatScreen(chatId: chatId, otherUser: otherUser);
          },
        ),
        GoRoute(
          path: '$videoCall/:roomName',
          builder: (_, state) {
            final roomName  = state.pathParameters['roomName']!;
            final otherUser = state.extra as UserModel?;
            return VideoCallScreen(roomName: roomName, otherUser: otherUser);
          },
        ),
        GoRoute(
          path: '$voiceCall/:roomName',
          builder: (_, state) {
            final roomName  = state.pathParameters['roomName']!;
            final otherUser = state.extra as UserModel?;
            return VoiceCallScreen(roomName: roomName, otherUser: otherUser);
          },
        ),
        GoRoute(
          path: incomingCall,
          builder: (_, state) => IncomingCallScreen(call: state.extra as CallModel),
        ),
        GoRoute(
          path: settings,
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(child: Text('404: ${state.error}')),
      ),
    );
  }

  static String _initialRoute(bool onboardingDone, bool isAuthenticated) {
    if (!onboardingDone) return onboarding;
    if (!isAuthenticated) return login;
    return home;
  }
}
