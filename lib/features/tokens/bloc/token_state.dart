import '../../../data/models/token_model.dart';

abstract class TokenState {}

class TokenInitial extends TokenState {}
class TokenLoading extends TokenState {}

class TokenLoaded extends TokenState {
  final TokenWallet wallet;
  final List<TokenTransaction> transactions;
  TokenLoaded({required this.wallet, this.transactions = const []});
}

class TokenError extends TokenState {
  final String message;
  TokenError(this.message);
}

class TokenInsufficient extends TokenState {
  final int required;
  final int current;
  TokenInsufficient({required this.required, required this.current});
}

class TokenAdLimitReached extends TokenState {}
class TokenShareLimitReached extends TokenState {}
class TokenActionSuccess extends TokenState {
  final int earned;
  final String message;
  TokenActionSuccess({required this.earned, required this.message});
}
