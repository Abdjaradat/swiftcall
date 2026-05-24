import 'dart:io';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static AdService get instance => _instance;
  static final AdService _instance = AdService._();
  AdService._();

  // ─────────────────────────────────────────────────────────────────────────
  // TEST IDs — يشتغلون فوراً بدون حساب Unity.
  // بعد تسجيل حساب على https://dashboard.unityads.unity.com
  // استبدل القيم أدناه بـ Game ID الحقيقي وAd Unit ID الخاص بك.
  // ─────────────────────────────────────────────────────────────────────────
  static const _androidGameId = '4374435';
  static const _iosGameId     = '4374434';

  String get _gameId      => Platform.isAndroid ? _androidGameId : _iosGameId;
  String get _rewardedId  => Platform.isAndroid ? 'Rewarded_Android' : 'Rewarded_iOS';

  bool _initialized = false;
  bool _adLoaded    = false;

  Future<void> init() async {
    if (_initialized) return;
    await UnityAds.init(
      gameId: _gameId,
      testMode: true, // ← اجعلها false عند النشر الحقيقي
      onComplete: () {
        _initialized = true;
        _loadAd();
      },
      onFailed: (error, message) {},
    );
  }

  void _loadAd() {
    UnityAds.load(
      placementId: _rewardedId,
      onComplete:  (_) => _adLoaded = true,
      onFailed:    (_, __, ___) => _adLoaded = false,
    );
  }

  bool get isReady => _adLoaded;

  /// يعرض الإعلان ويُعيد true إذا أكمله المستخدم (استحق التوكنز).
  Future<bool> showRewardedAd() async {
    if (!_initialized) await init();

    if (!_adLoaded) {
      _loadAd();
      for (var i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_adLoaded) break;
      }
      if (!_adLoaded) return false;
    }

    bool? result;

    UnityAds.showVideoAd(
      placementId: _rewardedId,
      onComplete:  (_) { result = true;  _adLoaded = false; _loadAd(); },
      onFailed:    (_, __, ___) { result = false; _loadAd(); },
      onSkipped:   (_) { result = false; _loadAd(); },
    );

    while (result == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return result!;
  }
}
