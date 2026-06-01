import 'dart:async';
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

  static const _placementRewarded     = 'Rewarded_Android';
  static const _placementInterstitial = 'Interstitial_Android';
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
      // Wait up to 3 s for the ad to load before giving up.
      for (var i = 0; i < 15 && !_rewardedLoaded; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (!_rewardedLoaded) return false;
    }

    final completer = Completer<bool>();
    UnityAds.showVideoAd(
      placementId: _placementRewarded,
      onComplete: (String _) {
        _rewardedLoaded = false;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(true);
      },
      onFailed: (String _, UnityAdsShowError __, String ___) {
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
      onSkipped: (String _) {
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    return completer.future;
  }

  // ── Interstitial — يظهر بعد المكالمات تلقائياً ────────────────────────────
  Future<void> showInterstitialAd() async {
    if (!_initialized) await init();

    if (!_interstitialLoaded) {
      _loadInterstitial();
      for (var i = 0; i < 10 && !_interstitialLoaded; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (!_interstitialLoaded) return;
    }

    final completer = Completer<void>();
    UnityAds.showVideoAd(
      placementId: _placementInterstitial,
      onComplete: (String _) {
        _interstitialLoaded = false;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onFailed: (String _, UnityAdsShowError __, String ___) {
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onSkipped: (String _) {
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }
}
