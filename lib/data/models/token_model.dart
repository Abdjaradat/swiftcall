import 'package:cloud_firestore/cloud_firestore.dart';

class TokenTransaction {
  final String id;
  final int amount;
  final String type;
  final String description;
  final DateTime createdAt;

  const TokenTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  factory TokenTransaction.fromMap(Map<String, dynamic> map, String id) {
    return TokenTransaction(
      id: id,
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'type': type,
    'description': description,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class TokenWallet {
  final String uid;
  final int balance;
  final int totalEarned;
  final int totalSpent;
  final DateTime? lastAdWatched;
  final DateTime? lastShared;
  final int dailyAdCount;
  final int dailyShareCount;
  final DateTime? adResetDate;
  final DateTime? shareResetDate;

  const TokenWallet({
    required this.uid,
    required this.balance,
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.lastAdWatched,
    this.lastShared,
    this.dailyAdCount = 0,
    this.dailyShareCount = 0,
    this.adResetDate,
    this.shareResetDate,
  });

  factory TokenWallet.fromMap(Map<String, dynamic> map) {
    return TokenWallet(
      uid: map['uid'] as String? ?? '',
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      totalEarned: (map['totalEarned'] as num?)?.toInt() ?? 0,
      totalSpent: (map['totalSpent'] as num?)?.toInt() ?? 0,
      lastAdWatched: (map['lastAdWatched'] as Timestamp?)?.toDate(),
      lastShared: (map['lastShared'] as Timestamp?)?.toDate(),
      dailyAdCount: (map['dailyAdCount'] as num?)?.toInt() ?? 0,
      dailyShareCount: (map['dailyShareCount'] as num?)?.toInt() ?? 0,
      adResetDate: (map['adResetDate'] as Timestamp?)?.toDate(),
      shareResetDate: (map['shareResetDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'balance': balance,
    'totalEarned': totalEarned,
    'totalSpent': totalSpent,
    'lastAdWatched': lastAdWatched != null ? Timestamp.fromDate(lastAdWatched!) : null,
    'lastShared': lastShared != null ? Timestamp.fromDate(lastShared!) : null,
    'dailyAdCount': dailyAdCount,
    'dailyShareCount': dailyShareCount,
    'adResetDate': adResetDate != null ? Timestamp.fromDate(adResetDate!) : null,
    'shareResetDate': shareResetDate != null ? Timestamp.fromDate(shareResetDate!) : null,
  };

  bool get canWatchAd {
    final now = DateTime.now();
    if (adResetDate == null) return true;
    final sameDay = now.year == adResetDate!.year &&
        now.month == adResetDate!.month &&
        now.day == adResetDate!.day;
    return !sameDay || dailyAdCount < 10;
  }

  bool get canShare {
    final now = DateTime.now();
    if (shareResetDate == null) return true;
    final sameDay = now.year == shareResetDate!.year &&
        now.month == shareResetDate!.month &&
        now.day == shareResetDate!.day;
    return !sameDay || dailyShareCount < 3;
  }

  int get remainingAds {
    final now = DateTime.now();
    if (adResetDate == null) return 10;
    final sameDay = now.year == adResetDate!.year &&
        now.month == adResetDate!.month &&
        now.day == adResetDate!.day;
    return sameDay ? (10 - dailyAdCount).clamp(0, 10) : 10;
  }

  int get remainingShares {
    final now = DateTime.now();
    if (shareResetDate == null) return 3;
    final sameDay = now.year == shareResetDate!.year &&
        now.month == shareResetDate!.month &&
        now.day == shareResetDate!.day;
    return sameDay ? (3 - dailyShareCount).clamp(0, 3) : 3;
  }
}

class TokenCosts {
  static const int messagePerMessage = 1;
  static const int voiceCallPerMinute = 5;
  static const int videoCallPerMinute = 10;
  static const int groupCallPerMinute = 15;

  static const int welcomeBonus = 100;
  static const int watchAdReward = 50;
  static const int shareReward = 30;
}
