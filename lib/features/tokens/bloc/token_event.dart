abstract class TokenEvent {}

class TokenLoadWallet extends TokenEvent {}
class TokenWatchAd extends TokenEvent {}
class TokenShare extends TokenEvent {}
class TokenSpend extends TokenEvent {
  final int amount;
  final String description;
  TokenSpend({required this.amount, required this.description});
}
class TokenLoadHistory extends TokenEvent {}
