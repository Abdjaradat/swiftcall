import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthEmailSignInRequested>(_onEmailSignIn);
    on<AuthEmailRegisterRequested>(_onEmailRegister);
    on<AuthSignOutRequested>(_onSignOut);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final user = await AuthService.instance.getCurrentUserModel();
    if (user != null) {
      await AuthService.instance.setOnlineStatus(true);
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onEmailSignIn(
    AuthEmailSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await AuthService.instance.signInWithEmail(
          event.email, event.password);
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthError('البريد أو الباسورد غير صحيح'));
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('user-not-found') || msg.contains('wrong-password') || msg.contains('invalid-credential')) {
        emit(AuthError('البريد أو الباسورد غير صحيح'));
      } else if (msg.contains('too-many-requests')) {
        emit(AuthError('حاولت كثيراً، انتظر قليلاً'));
      } else {
        emit(AuthError('حدث خطأ، حاول مجدداً'));
      }
    }
  }

  Future<void> _onEmailRegister(
    AuthEmailRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await AuthService.instance.registerWithEmail(
          event.email, event.password, event.displayName);
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthError('فشل إنشاء الحساب'));
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('email-already-in-use')) {
        emit(AuthError('هذا البريد مستخدم مسبقاً'));
      } else if (msg.contains('weak-password')) {
        emit(AuthError('الباسورد ضعيف — استخدم 6 أحرف على الأقل'));
      } else if (msg.contains('invalid-email')) {
        emit(AuthError('البريد الإلكتروني غير صحيح'));
      } else {
        emit(AuthError('حدث خطأ، حاول مجدداً'));
      }
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await AuthService.instance.signOut();
    emit(AuthUnauthenticated());
  }
}
