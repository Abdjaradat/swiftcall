part of 'auth_bloc.dart';

abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}
class AuthGoogleSignInRequested extends AuthEvent {}
class AuthSignOutRequested extends AuthEvent {}

class AuthEmailSignInRequested extends AuthEvent {
  final String email;
  final String password;
  AuthEmailSignInRequested({required this.email, required this.password});
}

class AuthEmailRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  AuthEmailRegisterRequested({
    required this.email,
    required this.password,
    required this.displayName,
  });
}
