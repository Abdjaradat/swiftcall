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

  static const _placementRewarded     = 'rewardedVideo';
  static const _placementInterstitial = 'video';
  static const _placementBanner       = 'Banner_Android';

  String get _gameId => Platform.isAndroid ? _androidGameId : _iosGameId;
  static String get bannerPlacementId => _placementBanner;

  bool _initialized        = false;
  bool _rewardedLoaded     = false;
  bool _interstitialLoaded = false;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    UnityAds.init(
      gameId: _gameId,
      testMode: false,
      onComplete: () {
        _initialized = true;
        _loadRewarded();
        _loadInterstitial();
      },
      onFailed: (UnityAdsInitializationError error, String message) {
        _initialized = false;
      },
    );
  }

  // ── Load helpers ──────────────────────────────────────────────────────────
  void _loadRewarded() {
    UnityAds.load(
      placementId: _placementRewarded,
      onComplete: (String _) => _rewardedLoaded = true,
      onFailed:   (String _, UnityAdsLoadError __, String ___) =>
          _rewardedLoaded = false,
    );
  }

  void _loadInterstitial() {
    UnityAds.load(
      placementId: _placementInterstitial,
      onComplete: (String _) => _interstitialLoaded = true,
      onFailed:   (String _, UnityAdsLoadError __, String ___) =>
          _interstitialLoaded = false,
    );
  }

  bool get isReady => _rewardedLoaded;

  // ── Rewarded Video — يمنح المستخدم توكنز ──────────────────────────────────
  Future<bool> showRewardedAd() async {
    if (!_initialized) await init();

    if (!_rewardedLoaded) {
      _loadRewarded();
      for (var i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_rewardedLoaded) break;
      }
      if (!_rewardedLoaded) return false;
    }

    bool? result;
    UnityAds.showVideoAd(
      placementId: _placementRewarded,
      onComplete: (String _) {
        result = true;
        _rewardedLoaded = false;
        _loadRewarded();
      },
      onFailed: (String _, UnityAdsShowError __, String ___) {
        result = false;
        _loadRewarded();
      },
      onSkipped: (String _) {
        result = false;
        _loadRewarded();
      },
    );

    while (result == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return result!;
  }

  // ── Interstitial — يظهر بعد المكالمات تلقائياً ────────────────────────────
  Future<void> showInterstitialAd() async {
    if (!_initialized) await init();

    if (!_interstitialLoaded) {
      _loadInterstitial();
      for (var i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_interstitialLoaded) break;
      }
      if (!_interstitialLoaded) return;
    }

    bool done = false;
    UnityAds.showVideoAd(
      placementId: _placementInterstitial,
      onComplete: (String _) {
        done = true;
        _interstitialLoaded = false;
        _loadInterstitial();
      },
      onFailed: (String _, UnityAdsShowError __, String ___) {
        done = true;
        _loadInterstitial();
      },
      onSkipped: (String _) {
        done = true;
        _loadInterstitial();
      },
    );

    while (!done) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
