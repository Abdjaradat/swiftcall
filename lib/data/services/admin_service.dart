import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static AdminService get instance => _instance;
  static final AdminService _instance = AdminService._();
  AdminService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> isAdmin(String uid) async {
    try {
      final snap = await _db.collection('admins').doc(uid).get();
      return snap.exists;
    } catch (e, stack) {
      print('AdminService.isAdmin ERROR: $e');
      print('STACK: $stack');
      return false;
    }
  }

  Future<String?> currentUid() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Add tokens to a user's balance
  Future<void> addTokens(String uid, int amount) async {
    final walletRef = _db.collection('token_wallets').doc(uid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(walletRef);
      final currentBalance = snap.exists ? (snap.data()?['balance'] as int?) ?? 0 : 0;
      txn.set(
        walletRef,
        {
          'balance': currentBalance + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Set a user's token balance to a specific amount
  Future<void> setTokenBalance(String uid, int amount) async {
    await _db.collection('token_wallets').doc(uid).set(
      {
        'balance': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Deduct tokens from a user's balance
  Future<void> deductTokens(String uid, int amount) async {
    final walletRef = _db.collection('token_wallets').doc(uid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(walletRef);
      final currentBalance = snap.exists ? (snap.data()?['balance'] as int?) ?? 0 : 0;
      final newBalance = currentBalance - amount;
      txn.set(
        walletRef,
        {
          'balance': newBalance < 0 ? 0 : newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
