import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/router/auth_notifier.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_settings_notifier.dart';
import 'data/models/call_model.dart';
import 'data/services/auth_service.dart';
import 'data/services/notification_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/call/bloc/call_bloc.dart';
import 'features/chat/bloc/chat_bloc.dart';
import 'features/home/bloc/home_bloc.dart';

class SwiftCallApp extends StatefulWidget {
  final bool isDarkMode;
  final String locale;
  final bool onboardingDone;
  final GlobalKey<NavigatorState> navigatorKey; // New property

  const SwiftCallApp({
    super.key,
    required this.isDarkMode,
    required this.locale,
    required this.onboardingDone,
    required this.navigatorKey, // Initialize new property
  });

  @override
  State<SwiftCallApp> createState() => _SwiftCallAppState();
}

class _SwiftCallAppState extends State<SwiftCallApp>
    with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final AuthNotifier _authNotifier;
  late final GoRouter _router;

  bool _isDark = true;
  String _locale = 'ar';

  StreamSubscription? _incomingCallSub;
  String? _lastShownCallId;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _locale = widget.locale;

    AppSettingsNotifier.instance.init(widget.isDarkMode, widget.locale);
    AppSettingsNotifier.instance.addListener(_onSettingsChanged);

    _authBloc = AuthBloc()..add(AuthCheckRequested());
    _authNotifier = AuthNotifier(_authBloc);
    _router = AppRouter.build(
      onboardingDone: widget.onboardingDone,
      authNotifier: _authNotifier,
    );

    // Start/stop incoming-call listener as auth state changes
    _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _startIncomingCallListener(state.user.uid);
      } else if (state is AuthUnauthenticated) {
        _stopIncomingCallListener();
      }
    });

    WidgetsBinding.instance.addObserver(this);

    NotificationService.onCallOpened = _navigateToCallFromData;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (NotificationService.pendingCallData != null) {
        _navigateToCallFromData(NotificationService.pendingCallData!);
        NotificationService.pendingCallData = null;
      }
    });
  }

  void _startIncomingCallListener(String myUid) {
    _incomingCallSub?.cancel();
    _incomingCallSub = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          NotificationService.instance.cancelCallNotification();
          continue;
        }
        if (change.type != DocumentChangeType.added) continue;
        final call = CallModel.fromMap(change.doc.data()!, change.doc.id);
        if (_lastShownCallId == call.id) continue;
        _lastShownCallId = call.id;

        HapticFeedback.heavyImpact();

        NotificationService.instance.showCallNotification(
          callerName: call.callerName,
          callerPhoto: call.callerPhoto,
          isVideoCall: call.type == CallType.video,
        );

        final currentPath = _router.routeInformationProvider.value.uri.path;
        if (currentPath == AppRouter.incomingCall) continue;
        _router.push(AppRouter.incomingCall, extra: call);
      }
    });
  }

  void _navigateToCallFromData(Map<String, dynamic> data) {
    final call = CallModel(
      id: data['callId'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      callerPhoto: data['callerPhoto'] ?? '',
      receiverId: AuthService.instance.currentUserId ?? '',
      receiverName: '',
      type: data['callType'] == 'video' ? CallType.video : CallType.audio,
      status: CallStatus.ringing,
      roomName: data['roomName'] ?? '',
      timestamp: DateTime.now(),
    );
    if (_lastShownCallId == call.id) return;
    _lastShownCallId = call.id;
    final currentPath = _router.routeInformationProvider.value.uri.path;
    if (currentPath == AppRouter.incomingCall) return;
    _router.push(AppRouter.incomingCall, extra: call);
  }

  void _stopIncomingCallListener() {
    _incomingCallSub?.cancel();
    _incomingCallSub = null;
    _lastShownCallId = null;
    NotificationService.instance.cancelCallNotification();
  }

  void _onSettingsChanged() {
    setState(() {
      _isDark = AppSettingsNotifier.instance.isDark;
      _locale = AppSettingsNotifier.instance.locale;
    });
  }

  @override
  void dispose() {
    AppSettingsNotifier.instance.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _incomingCallSub?.cancel();
    _authNotifier.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AuthService.instance
        .setOnlineStatus(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => HomeBloc()),
        BlocProvider(create: (_) => ChatBloc()),
        BlocProvider(create: (_) => CallBloc()),
      ],
      child: _ThemeLocaleWrapper(
        isDark: _isDark,
        locale: _locale,
        router: _router,
        onThemeChanged: (v) => setState(() => _isDark = v),
        onLocaleChanged: (v) => setState(() => _locale = v),
        navigatorKey: widget.navigatorKey, // Pass the navigatorKey
      ),
    );
  }
}

class _ThemeLocaleWrapper extends StatelessWidget {
  final bool isDark;
  final String locale;
  final GoRouter router;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<String> onLocaleChanged;
  final GlobalKey<NavigatorState> navigatorKey; // New property

  const _ThemeLocaleWrapper({
    required this.isDark,
    required this.locale,
    required this.router,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.navigatorKey, // Initialize new property
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SwiftCall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Provide the navigatorKey to MaterialApp.router
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: router.backButtonDispatcher,
      builder: (context, child) {
        return Navigator(
          key: navigatorKey, // Use the global key here
          onGenerateRoute: (settings) {
            return MaterialPageRoute(builder: (_) => child!);
          },
        );
      },
    );
  }
}
