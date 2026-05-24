import 'dart:io';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static AdService get instance => _instance;
  static final AdService _instance = AdService._();
  AdService._();

  // ─────────────────────────────────────────────────────────────────────────
  // Game ID الحقيقي من Unity Dashboard (حساب jaradatabdullah122)
  // ─────────────────────────────────────────────────────────────────────────
  static const _androidGameId = '800000852';
  static const _iosGameId     = '800000852';

  String get _gameId     => Platform.isAndroid ? _androidGameId : _iosGameId;
  String get _rewardedId => Platform.isAndroid ? 'Rewarded_Android' : 'Rewarded_iOS';

  bool _initialized = false;
  bool _adLoaded    = false;

  Future<void> init() async {
    if (_initialized) return;
    UnityAds.init(
      gameId: _gameId,
      testMode: true,
      onComplete: () {
        _initialized = true;
        _loadAd();
      },
      onFailed: (UnityAdsInitializationError error, String message) {
        _initialized = false;
      },
    );
  }

  void _loadAd() {
    UnityAds.load(
      placementId: _rewardedId,
      onComplete: (String placementId) {
        _adLoaded = true;
      },
      onFailed: (String placementId, UnityAdsLoadError error, String message) {
        _adLoaded = false;
      },
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
      onComplete: (String placementId) {
        result = true;
        _adLoaded = false;
        _loadAd();
      },
      onFailed: (String placementId, UnityAdsShowError error, String message) {
        result = false;
        _loadAd();
      },
      onSkipped: (String placementId) {
        result = false;
        _loadAd();
      },
    );

    while (result == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return result!;
  }
}
