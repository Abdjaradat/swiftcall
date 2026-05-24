import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/token_model.dart';

class TokenService {
  static TokenService get instance => _instance;
  static final TokenService _instance = TokenService._();
  TokenService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _wallets => _db.collection('token_wallets');
  CollectionReference _transactions(String uid) =>
      _wallets.doc(uid).collection('transactions');

  Stream<TokenWallet> walletStream(String uid) {
    return _wallets.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return TokenWallet(uid: uid, balance: 0);
      return TokenWallet.fromMap(snap.data() as Map<String, dynamic>);
    });
  }

  Future<TokenWallet> getWallet(String uid) async {
    final snap = await _wallets.doc(uid).get();
    if (!snap.exists) return TokenWallet(uid: uid, balance: 0);
    return TokenWallet.fromMap(snap.data() as Map<String, dynamic>);
  }

  Future<void> initWallet(String uid) async {
    final snap = await _wallets.doc(uid).get();
    if (snap.exists) return;
    final wallet = TokenWallet(
      uid: uid,
      balance: TokenCosts.welcomeBonus,
      totalEarned: TokenCosts.welcomeBonus,
    );
    await _wallets.doc(uid).set(wallet.toMap());
    await _addTransaction(uid, TokenCosts.welcomeBonus, 'bonus', 'مرحباً! هدية الترحيب');
  }

  Future<bool> spendTokens(String uid, int amount, String description) async {
    final wallet = await getWallet(uid);
    if (wallet.balance < amount) return false;
    await _wallets.doc(uid).update({
      'balance': FieldValue.increment(-amount),
      'totalSpent': FieldValue.increment(amount),
    });
    await _addTransaction(uid, -amount, 'spend', description);
    return true;
  }

  Future<void> earnTokens(String uid, int amount, String type, String description) async {
    await _wallets.doc(uid).set({
      'uid': uid,
      'balance': FieldValue.increment(amount),
      'totalEarned': FieldValue.increment(amount),
    }, SetOptions(merge: true));
    await _addTransaction(uid, amount, type, description);
  }

  Future<bool> rewardAdWatch(String uid) async {
    final wallet = await getWallet(uid);
    if (!wallet.canWatchAd) return false;
    final now = DateTime.now();
    final sameDay = wallet.adResetDate != null &&
        now.year == wallet.adResetDate!.year &&
        now.month == wallet.adResetDate!.month &&
        now.day == wallet.adResetDate!.day;
    await _wallets.doc(uid).update({
      'balance': FieldValue.increment(TokenCosts.watchAdReward),
      'totalEarned': FieldValue.increment(TokenCosts.watchAdReward),
      'lastAdWatched': Timestamp.fromDate(now),
      'dailyAdCount': sameDay ? FieldValue.increment(1) : 1,
      'adResetDate': Timestamp.fromDate(now),
    });
    await _addTransaction(uid, TokenCosts.watchAdReward, 'ad', 'شاهدت إعلاناً');
    return true;
  }

  Future<bool> rewardShare(String uid) async {
    final wallet = await getWallet(uid);
    if (!wallet.canShare) return false;
    final now = DateTime.now();
    final sameDay = wallet.shareResetDate != null &&
        now.year == wallet.shareResetDate!.year &&
        now.month == wallet.shareResetDate!.month &&
        now.day == wallet.shareResetDate!.day;
    await _wallets.doc(uid).update({
      'balance': FieldValue.increment(TokenCosts.shareReward),
      'totalEarned': FieldValue.increment(TokenCosts.shareReward),
      'lastShared': Timestamp.fromDate(now),
      'dailyShareCount': sameDay ? FieldValue.increment(1) : 1,
      'shareResetDate': Timestamp.fromDate(now),
    });
    await _addTransaction(uid, TokenCosts.shareReward, 'share', 'شاركت التطبيق');
    return true;
  }

  Future<List<TokenTransaction>> getTransactions(String uid, {int limit = 20}) async {
    final snap = await _transactions(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) =>
        TokenTransaction.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
  }

  Future<void> _addTransaction(String uid, int amount, String type, String description) async {
    await _transactions(uid).add(TokenTransaction(
      id: '',
      amount: amount,
      type: type,
      description: description,
      createdAt: DateTime.now(),
    ).toMap());
  }
}
