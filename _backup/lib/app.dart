import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/call/bloc/call_bloc.dart';
import 'features/chat/bloc/chat_bloc.dart';
import 'features/home/bloc/home_bloc.dart';

class SwiftCallApp extends StatefulWidget {
  final bool isDarkMode;
  final String locale;
  final bool onboardingDone;

  const SwiftCallApp({
    super.key,
    required this.isDarkMode,
    required this.locale,
    required this.onboardingDone,
  });

  @override
  State<SwiftCallApp> createState() => _SwiftCallAppState();
}

class _SwiftCallAppState extends State<SwiftCallApp> with WidgetsBindingObserver {
  late bool _isDark;
  late String _locale;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _locale = widget.locale;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isOnline = state == AppLifecycleState.resumed;
    AuthService.instance.setOnlineStatus(isOnline);
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = AuthService.instance.currentUser != null;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()..add(AuthCheckRequested())),
        BlocProvider(create: (_) => HomeBloc()),
        BlocProvider(create: (_) => ChatBloc()),
        BlocProvider(create: (_) => CallBloc()),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return MaterialApp.router(
            title: 'SwiftCall',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
            locale: Locale(_locale),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: AppRouter.router(
              onboardingDone: widget.onboardingDone,
              isAuthenticated: authState is AuthAuthenticated,
            ),
          );
        },
      ),
    );
  }
}
