import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../main.dart' show premiumNotifier;

/// Manages all Google AdMob ad lifecycle for the app.
///
/// ── How to go live ────────────────────────────────────────────────────────
/// 1. Register your app at https://apps.admob.com
/// 2. Create ad units (Banner, Interstitial) for Android and iOS
/// 3. Set [_testMode] to `false`
/// 4. Replace every "TODO: real …" string below with your actual ad-unit IDs
/// 5. Replace the placeholder App IDs in AndroidManifest.xml (Android) and
///    Info.plist (iOS) with your real AdMob App IDs
/// ──────────────────────────────────────────────────────────────────────────
class AdService {
  AdService._();
  static final instance = AdService._();

  bool _initialized = false;

  // ── Mode switch ─────────────────────────────────────────────────────────
  // Flip to `false` once you have filled in your real ad unit IDs below
  // and your AdMob account is approved.
  static const bool _testMode = true;

  // ── Ad-unit IDs ──────────────────────────────────────────────────────────
  //
  // Test IDs are Google's official test IDs — safe to use during development
  // (they always return a filled ad, never real impressions/revenue).
  //
  // TODO: When _testMode is false, replace every 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'
  //       with your real AdMob ad unit IDs from https://apps.admob.com.

  static String get bannerId => Platform.isAndroid
      ? (_testMode
          ? 'ca-app-pub-3940256099942544/6300978111' // Google test banner
          : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX') // TODO: real Android banner
      : (_testMode
          ? 'ca-app-pub-3940256099942544/2934735716' // Google test banner
          : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'); // TODO: real iOS banner

  static String get interstitialId => Platform.isAndroid
      ? (_testMode
          ? 'ca-app-pub-3940256099942544/1033173712' // Google test interstitial
          : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX') // TODO: real Android interstitial
      : (_testMode
          ? 'ca-app-pub-3940256099942544/4411468910' // Google test interstitial
          : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'); // TODO: real iOS interstitial

  // ── Interstitial state ───────────────────────────────────────────────────
  InterstitialAd? _interstitial;

  /// Whether the launch interstitial has already been shown this session.
  bool _sessionInterstitialShown = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
  }

  // ── Interstitial ─────────────────────────────────────────────────────────

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
            },
          );
        },
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Shows the launch interstitial **once per app session**.
  /// Call after the first content frame is ready (e.g. after _loadRefunds).
  void showSessionInterstitial() {
    if (premiumNotifier.value) return; // Premium users skip all ads.
    if (_sessionInterstitialShown) return;
    if (_interstitial == null) return;
    _sessionInterstitialShown = true;
    _interstitial!.show();
    _interstitial = null;
  }

  // ── Banner factory ────────────────────────────────────────────────────────

  /// Creates a new [BannerAd] sized to [AdSize.banner] (320×50).
  /// The caller is responsible for calling [BannerAd.dispose].
  BannerAd createBannerAd({BannerAdListener? listener}) => BannerAd(
        adUnitId: bannerId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: listener ??
            BannerAdListener(
              onAdFailedToLoad: (ad, _) => ad.dispose(),
            ),
      );

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void dispose() {
    _interstitial?.dispose();
  }
}
