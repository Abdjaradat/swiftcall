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
    if (!snap.exists) {
      await initWallet(uid);
      final created = await _wallets.doc(uid).get();
      if (!created.exists) return TokenWallet(uid: uid, balance: 0);
      return TokenWallet.fromMap(created.data() as Map<String, dynamic>);
    }
    return TokenWallet.fromMap(snap.data() as Map<String, dynamic>);
  }

  Future<void> initWallet(String uid) async {
    final wallet = TokenWallet(
      uid: uid,
      balance: TokenCosts.welcomeBonus,
      totalEarned: TokenCosts.welcomeBonus,
    );

    await _db.runTransaction((tx) async {
      final walletRef = _wallets.doc(uid);
      final snap = await tx.get(walletRef);
      if (snap.exists) return;

      tx.set(walletRef, wallet.toMap());
      tx.set(
        _transactions(uid).doc(),
        TokenTransaction(
          id: '',
          amount: TokenCosts.welcomeBonus,
          type: 'bonus',
          description: 'مرحباً! هدية الترحيب',
          createdAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  Future<bool> spendTokens(String uid, int amount, String description) {
    return _db.runTransaction((tx) async {
      final walletRef = _wallets.doc(uid);
      final snap = await tx.get(walletRef);
      if (!snap.exists) return false;

      final wallet = TokenWallet.fromMap(snap.data() as Map<String, dynamic>);
      if (wallet.balance < amount) return false;

      tx.set(walletRef, {
        'balance': FieldValue.increment(-amount),
        'totalSpent': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      tx.set(
        _transactions(uid).doc(),
        TokenTransaction(
          id: '',
          amount: -amount,
          type: 'spend',
          description: description,
          createdAt: DateTime.now(),
        ).toMap(),
      );
      return true;
    });
  }

  Future<void> earnTokens(
    String uid,
    int amount,
    String type,
    String description,
  ) async {
    await _db.runTransaction((tx) async {
      final walletRef = _wallets.doc(uid);
      tx.set(walletRef, {
        'uid': uid,
        'balance': FieldValue.increment(amount),
        'totalEarned': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      tx.set(
        _transactions(uid).doc(),
        TokenTransaction(
          id: '',
          amount: amount,
          type: type,
          description: description,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  Future<bool> rewardAdWatch(String uid) async {
    final wallet = await getWallet(uid);
    if (!wallet.canWatchAd) return false;

    final now = DateTime.now();
    final sameDay = wallet.adResetDate != null &&
        now.year == wallet.adResetDate!.year &&
        now.month == wallet.adResetDate!.month &&
        now.day == wallet.adResetDate!.day;

    await _db.runTransaction((tx) async {
      final walletRef = _wallets.doc(uid);
      tx.set(walletRef, {
        'uid': uid,
        'balance': FieldValue.increment(TokenCosts.watchAdReward),
        'totalEarned': FieldValue.increment(TokenCosts.watchAdReward),
        'lastAdWatched': Timestamp.fromDate(now),
        'dailyAdCount': sameDay ? FieldValue.increment(1) : 1,
        'adResetDate': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      tx.set(
        _transactions(uid).doc(),
        TokenTransaction(
          id: '',
          amount: TokenCosts.watchAdReward,
          type: 'ad',
          description: 'شاهدت إعلاناً',
          createdAt: now,
        ).toMap(),
      );
    });
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

    await _db.runTransaction((tx) async {
      final walletRef = _wallets.doc(uid);
      tx.set(walletRef, {
        'uid': uid,
        'balance': FieldValue.increment(TokenCosts.shareReward),
        'totalEarned': FieldValue.increment(TokenCosts.shareReward),
        'lastShared': Timestamp.fromDate(now),
        'dailyShareCount': sameDay ? FieldValue.increment(1) : 1,
        'shareResetDate': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      tx.set(
        _transactions(uid).doc(),
        TokenTransaction(
          id: '',
          amount: TokenCosts.shareReward,
          type: 'share',
          description: 'شاركت التطبيق',
          createdAt: now,
        ).toMap(),
      );
    });
    return true;
  }

  Future<List<TokenTransaction>> getTransactions(
    String uid, {
    int limit = 20,
  }) async {
    try {
      final snap = await _transactions(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) =>
              TokenTransaction.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (_) {
      try {
        final snap = await _transactions(uid).limit(limit).get();
        final list = snap.docs
            .map((d) => TokenTransaction.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      } catch (_) {
        return [];
      }
    }
  }

  // ── Admin: credit tokens manually ──────────────────────────

  Future<void> creditTokensManually(
    String uid,
    int amount,
    String description,
  ) async {
    await _db.runTransaction((tx) async {
      final walletRef = _wallets.doc(uid);
      tx.set(walletRef, {
        'uid': uid,
        'balance': FieldValue.increment(amount),
        'totalEarned': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      tx.set(
        _transactions(uid).doc(),
        TokenTransaction(
          id: '',
          amount: amount,
          type: 'admin_credit',
          description: description,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  // ── Admin: token packages ──────────────────────────────────

  Stream<List<TokenPackage>> tokenPackagesStream() {
    return _db.collection('token_packages').snapshots().map((snap) =>
        snap.docs
            .map((d) => TokenPackage.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> addTokenPackage(TokenPackage pkg) async {
    final doc = _db.collection('token_packages').doc();
    await doc.set(pkg.toMap());
  }

  Future<void> deleteTokenPackage(String id) async {
    await _db.collection('token_packages').doc(id).delete();
  }

  Future<void> toggleTokenPackage(String id, bool isActive) async {
    await _db.collection('token_packages').doc(id).update({'isActive': isActive});
  }
}
