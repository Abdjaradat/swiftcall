import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/token_service.dart';
import 'token_event.dart';
import 'token_state.dart';

class TokenBloc extends Bloc<TokenEvent, TokenState> {
  final _tokenService = TokenService.instance;
  final _authService = AuthService.instance;

  TokenBloc() : super(TokenInitial()) {
    on<TokenLoadWallet>(_onLoad);
    on<TokenWatchAd>(_onWatchAd);
    on<TokenShare>(_onShare);
    on<TokenSpend>(_onSpend);
    on<TokenLoadHistory>(_onLoadHistory);
  }

  String? get _uid => _authService.currentUserId;

  Future<void> _onLoad(TokenLoadWallet event, Emitter<TokenState> emit) async {
    emit(TokenLoading());
    try {
      final uid = _uid;
      if (uid == null) {
        emit(TokenError('يجب تسجيل الدخول أولاً'));
        return;
      }
      final wallet = await _tokenService.getWallet(uid);
      final transactions = await _tokenService.getTransactions(uid);
      emit(TokenLoaded(wallet: wallet, transactions: transactions));
    } catch (_) {
      emit(TokenError('فشل تحميل المحفظة، حاول مرة أخرى'));
    }
  }

  Future<void> _onWatchAd(TokenWatchAd event, Emitter<TokenState> emit) async {
    try {
      final uid = _uid;
      if (uid == null) {
        emit(TokenError('يجب تسجيل الدخول أولاً'));
        return;
      }
      final wallet = await _tokenService.getWallet(uid);
      if (!wallet.canWatchAd) {
        emit(TokenAdLimitReached());
        return;
      }
      final success = await _tokenService.rewardAdWatch(uid);
      if (success) {
        emit(TokenActionSuccess(
          earned: 50,
          message: 'حصلت على 50 توكن!',
        ));
        add(TokenLoadWallet());
      }
    } catch (_) {
      emit(TokenError('تعذر تحديث المحفظة، حاول مرة أخرى'));
    }
  }

  Future<void> _onShare(TokenShare event, Emitter<TokenState> emit) async {
    try {
      final uid = _uid;
      if (uid == null) {
        emit(TokenError('يجب تسجيل الدخول أولاً'));
        return;
      }
      final wallet = await _tokenService.getWallet(uid);
      if (!wallet.canShare) {
        emit(TokenShareLimitReached());
        return;
      }
      final success = await _tokenService.rewardShare(uid);
      if (success) {
        emit(TokenActionSuccess(
          earned: 30,
          message: 'حصلت على 30 توكن مقابل المشاركة!',
        ));
        add(TokenLoadWallet());
      }
    } catch (_) {
      emit(TokenError('تعذر تحديث المحفظة، حاول مرة أخرى'));
    }
  }

  Future<void> _onSpend(TokenSpend event, Emitter<TokenState> emit) async {
    try {
      final uid = _uid;
      if (uid == null) {
        emit(TokenError('يجب تسجيل الدخول أولاً'));
        return;
      }
      final wallet = await _tokenService.getWallet(uid);
      if (wallet.balance < event.amount) {
        emit(TokenInsufficient(required: event.amount, current: wallet.balance));
        return;
      }
      await _tokenService.spendTokens(uid, event.amount, event.description);
      add(TokenLoadWallet());
    } catch (_) {
      emit(TokenError('تعذر تحديث المحفظة، حاول مرة أخرى'));
    }
  }

  Future<void> _onLoadHistory(
    TokenLoadHistory event,
    Emitter<TokenState> emit,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final wallet = await _tokenService.getWallet(uid);
      final transactions = await _tokenService.getTransactions(uid, limit: 50);
      emit(TokenLoaded(wallet: wallet, transactions: transactions));
    } catch (_) {
      emit(TokenError('فشل تحميل السجل'));
    }
  }
}
