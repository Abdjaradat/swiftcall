import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_notifier.dart';
import '../../data/models/call_model.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/call/screens/incoming_call_screen.dart';
import '../../features/call/screens/video_call_screen.dart';
import '../../features/call/screens/voice_call_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

class AppRouter {
  static const String onboarding  = '/onboarding';
  static const String login        = '/login';
  static const String home         = '/home';
  static const String chat         = '/chat';
  static const String videoCall    = '/video-call';
  static const String voiceCall    = '/voice-call';
  static const String incomingCall = '/incoming-call';
  static const String settings     = '/settings';
  static const String terms        = '/terms';
  static const String privacy      = '/privacy';

  /// Creates the router once. Use [authNotifier] to trigger redirect re-evals.
  static GoRouter build({
    required bool onboardingDone,
    required AuthNotifier authNotifier,
  }) {
    return GoRouter(
      initialLocation: onboardingDone ? login : onboarding,
      refreshListenable: authNotifier,
      redirect: (context, state) {
        // Still checking auth — don't redirect yet
        if (authNotifier.isChecking) return null;

        final isAuth = authNotifier.isAuthenticated;
        final path   = state.matchedLocation;

        final publicRoutes = {onboarding, login, terms, privacy};
        final isOnPublic   = publicRoutes.contains(path);

        // Authenticated user on a public screen → go home
        if (isAuth && isOnPublic) return home;

        // Unauthenticated user on a protected screen → go login
        if (!isAuth && !isOnPublic) return login;

        return null; // No redirect needed
      },
      routes: [
        GoRoute(path: onboarding,  builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: login,        builder: (_, __) => const LoginScreen()),
        GoRoute(path: home,         builder: (_, __) => const HomeScreen()),

        GoRoute(
          path: '$chat/:chatId',
          builder: (_, state) => ChatScreen(
            chatId:    state.pathParameters['chatId']!,
            otherUser: state.extra as UserModel?,
          ),
        ),

        GoRoute(
          path: '$videoCall/:roomName',
          builder: (_, state) => VideoCallScreen(
            roomName:  state.pathParameters['roomName']!,
            otherUser: state.extra as UserModel?,
          ),
        ),

        GoRoute(
          path: '$voiceCall/:roomName',
          builder: (_, state) => VoiceCallScreen(
            roomName:  state.pathParameters['roomName']!,
            otherUser: state.extra as UserModel?,
          ),
        ),

        GoRoute(
          path: incomingCall,
          builder: (_, state) =>
              IncomingCallScreen(call: state.extra as CallModel),
        ),

        GoRoute(path: settings, builder: (_, __) => const SettingsScreen()),
        GoRoute(
          path: terms,
          builder: (_, __) => const LegalScreen(type: LegalType.terms),
        ),
        GoRoute(
          path: privacy,
          builder: (_, __) => const LegalScreen(type: LegalType.privacy),
        ),
      ],

      errorBuilder: (_, state) => Scaffold(
        body: Center(child: Text('خطأ: ${state.error}')),
      ),
    );
  }
}
