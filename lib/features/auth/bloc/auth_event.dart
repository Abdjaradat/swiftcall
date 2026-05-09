part of 'auth_bloc.dart';

abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}
class AuthGoogleSignInRequested extends AuthEvent {}
class AuthSignOutRequested extends AuthEvent {}
