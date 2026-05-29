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
import 'data/models/group_call_model.dart';
import 'data/services/auth_service.dart';
import 'data/services/notification_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/call/bloc/call_bloc.dart';
import 'features/call_history/bloc/call_history_bloc.dart';
import 'features/chat/bloc/chat_bloc.dart';
import 'features/group_call/bloc/group_call_bloc.dart';
import 'features/home/bloc/home_bloc.dart';
import 'features/tokens/bloc/token_bloc.dart';
import 'features/location/bloc/location_bloc.dart';
import 'data/services/location_service.dart';

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

class _SwiftCallAppState extends State<SwiftCallApp>
    with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final AuthNotifier _authNotifier;
  late final GoRouter _router;

  bool _isDark = true;
  String _locale = 'ar';

  StreamSubscription? _incomingCallSub;
  StreamSubscription? _incomingGroupCallSub;
  String? _lastShownCallId;
  String? _lastShownGroupCallId;

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

    _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _startIncomingCallListener(state.user.uid);
        _startIncomingGroupCallListener(state.user.uid);
      } else if (state is AuthUnauthenticated) {
        _stopIncomingCallListener();
      }
    });

    WidgetsBinding.instance.addObserver(this);

    // ── Native → Flutter callbacks ────────────────────────────────────────

    // FCM notification tapped (app was background/killed) → show incoming call UI
    NotificationService.onCallOpened = _navigateToIncomingCall;

    // User answered from native CallKit (iOS) or tapped Answer button (Android)
    // → navigate directly to the active call screen
    NotificationService.onCallAnsweredFromNative = _navigateToActiveCall;

    // User declined from native CallKit (iOS) or tapped Decline button (Android)
    NotificationService.onCallDeclinedFromNative = _handleNativeDecline;

    // Caller cancelled before the receiver answered → dismiss incoming call UI
    NotificationService.onCallCancelled = _dismissIncomingCall;

    // iOS PushKit VoIP token → save to Firestore for backend to use
    NotificationService.onVoipTokenReceived = (token) {
      AuthService.instance.updateVoipToken(token);
    };

    // Deliver pending call data from a cold start via notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (NotificationService.pendingCallData != null) {
        _navigateToIncomingCall(NotificationService.pendingCallData!);
        NotificationService.pendingCallData = null;
      }
    });
  }

  // ── Firestore incoming-call listener ─────────────────────────────────────
  // Used when app is in foreground (both iOS + Android)

  void _startIncomingCallListener(String myUid) {
    _incomingCallSub?.cancel();
    _incomingCallSub = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        // Call left the 'ringing' query → caller cancelled or it ended
        if (change.type == DocumentChangeType.removed) {
          final callId = change.doc.id;
          _dismissIncomingCall(callId);
          continue;
        }
        if (change.type != DocumentChangeType.added) continue;
        final call = CallModel.fromMap(change.doc.data()!, change.doc.id);
        if (_lastShownCallId == call.id) continue;
        _lastShownCallId = call.id;

        HapticFeedback.heavyImpact();

        NotificationService.instance.showCallNotification(
          callerName:  call.callerName,
          callerPhoto: call.callerPhoto,
          isVideoCall: call.type == CallType.video,
        );

        final currentPath = _router.routeInformationProvider.value.uri.path;
        if (currentPath == AppRouter.incomingCall) continue;
        _router.push(AppRouter.incomingCall, extra: call);
      }
    });
  }

  void _stopIncomingCallListener() {
    _incomingCallSub?.cancel();
    _incomingCallSub = null;
    _lastShownCallId = null;
    _incomingGroupCallSub?.cancel();
    _incomingGroupCallSub = null;
    _lastShownGroupCallId = null;
    NotificationService.instance.cancelCallNotification();
  }

  // ── Firestore incoming group-call listener ────────────────────────────────

  void _startIncomingGroupCallListener(String myUid) {
    _incomingGroupCallSub?.cancel();
    _incomingGroupCallSub = FirebaseFirestore.instance
        .collection('group_calls')
        .where('participantUids', arrayContains: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          final callId = change.doc.id;
          if (_lastShownGroupCallId == callId) {
            _lastShownGroupCallId = null;
            final path =
                _router.routeInformationProvider.value.uri.path;
            if (path == AppRouter.incomingGroupCall) _router.pop();
          }
          continue;
        }
        if (change.type != DocumentChangeType.added) continue;

        final data  = change.doc.data()!;
        final model = GroupCallModel.fromMap(data, change.doc.id);

        // Creator doesn't get an incoming screen for their own call
        if (model.createdBy == myUid) continue;

        // Check that this user is still 'invited' (not yet joined/declined)
        final me = model.participants
            .where((p) => p.uid == myUid)
            .firstOrNull;
        if (me == null || me.status != 'invited') continue;

        if (_lastShownGroupCallId == model.id) continue;
        _lastShownGroupCallId = model.id;

        HapticFeedback.heavyImpact();

        final currentPath =
            _router.routeInformationProvider.value.uri.path;
        if (currentPath == AppRouter.incomingGroupCall) continue;
        _router.push(AppRouter.incomingGroupCall, extra: model);
      }
    });
  }

  // ── Navigation helpers ───────────────────────────────────────────────────

  /// Shows the full incoming call screen (ring + accept/reject buttons).
  /// Used when the app is woken from background/killed via FCM notification tap.
  void _navigateToIncomingCall(Map<String, dynamic> data) {
    final callId = data['callId'] ?? data['call_id'] ?? '';
    if (_lastShownCallId == callId) return;
    _lastShownCallId = callId;

    final call = CallModel(
      id:           callId,
      callerId:     data['callerId']    ?? '',
      callerName:   data['callerName']  ?? '',
      callerPhoto:  data['callerPhoto'] as String?,
      receiverId:   AuthService.instance.currentUserId ?? '',
      receiverName: '',
      type: data['callType'] == 'video' ? CallType.video : CallType.audio,
      status:   CallStatus.ringing,
      roomName: data['roomName'] ?? '',
      timestamp: DateTime.now(),
    );

    final currentPath = _router.routeInformationProvider.value.uri.path;
    if (currentPath == AppRouter.incomingCall) return;
    _router.push(AppRouter.incomingCall, extra: call);
  }

  /// Navigates directly to the active call screen.
  /// Used when the user answers from the native CallKit/notification UI.
  void _navigateToActiveCall(Map<String, dynamic> data) {
    final callId   = data['callId']    ?? data['uuid']     ?? '';
    final roomName = data['roomName']  ?? '';
    final callType = data['callType']  ?? 'audio';
    final hasVideo = data['hasVideo']  as bool? ?? callType == 'video';

    // Accept the call in Firestore so the caller knows it was answered
    if (callId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .update({'status': 'accepted'}).catchError((_) {});
    }

    _lastShownCallId = callId;
    NotificationService.instance.cancelCallNotification();

    final route = hasVideo
        ? '${AppRouter.videoCall}/$roomName'
        : '${AppRouter.voiceCall}/$roomName';

    // Build a minimal UserModel-like extra for the call screen
    _router.push(route);
  }

  /// Marks the call as rejected in Firestore when the user declines from native UI.
  void _handleNativeDecline(Map<String, dynamic> data) {
    final callId = data['callId'] ?? data['uuid'] ?? '';
    if (callId.isEmpty) return;
    FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .update({'status': 'rejected'}).catchError((_) {});
    NotificationService.instance.cancelCallNotification();
    _dismissIncomingCall(callId);
  }

  /// Dismisses the incoming call screen and notification.
  /// Called when: Firestore call doc leaves 'ringing', or FCM call_cancelled arrives.
  void _dismissIncomingCall(String callId) {
    NotificationService.instance.cancelCallNotification();
    if (_lastShownCallId == callId || _lastShownCallId == null) {
      _lastShownCallId = null;
      final path = _router.routeInformationProvider.value.uri.path;
      if (path == AppRouter.incomingCall) {
        _router.pop();
      }
    }
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  void _onSettingsChanged() {
    setState(() {
      _isDark  = AppSettingsNotifier.instance.isDark;
      _locale  = AppSettingsNotifier.instance.locale;
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
    AuthService.instance.setOnlineStatus(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => HomeBloc()),
        BlocProvider(create: (_) => ChatBloc()),
        BlocProvider(create: (_) => CallBloc()),
        BlocProvider(create: (_) => GroupCallBloc()),
        BlocProvider(create: (_) => CallHistoryBloc()..add(CallHistoryLoad())),
        // TokenBloc auto-loads via _listenAuth() when Firebase Auth completes
        BlocProvider(create: (_) => TokenBloc()),
        BlocProvider(
          create: (_) => LocationBloc(
            locationService: LocationService(),
            authService: AuthService.instance,
          ),
        ),
      ],
      child: _ThemeLocaleWrapper(
        isDark: _isDark,
        locale: _locale,
        router: _router,
      ),
    );
  }
}

class _ThemeLocaleWrapper extends StatelessWidget {
  final bool isDark;
  final String locale;
  final GoRouter router;

  const _ThemeLocaleWrapper({
    required this.isDark,
    required this.locale,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    final textDir = locale == 'ar' ? TextDirection.rtl : TextDirection.ltr;
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
      // Explicit RTL/LTR directionality at the root so every widget
      // inherits the correct text direction regardless of platform default.
      builder: (context, child) => Directionality(
        textDirection: textDir,
        child: child!,
      ),
      routerConfig: router,
    );
  }
}
