import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/bloc/auth_bloc.dart';

class AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  bool _isAuthenticated = false;
  bool _isChecking = true;

  AuthNotifier(AuthBloc bloc) {
    _isAuthenticated = bloc.state is AuthAuthenticated;
    _isChecking = bloc.state is AuthInitial || bloc.state is AuthLoading;

    _sub = bloc.stream.listen((state) {
      _isAuthenticated = state is AuthAuthenticated;
      _isChecking = state is AuthInitial || state is AuthLoading;
      notifyListeners();
    });
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isChecking => _isChecking;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
