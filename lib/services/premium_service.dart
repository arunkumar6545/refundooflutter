import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the Premium subscription state.
///
/// Premium expiry is stored in encrypted storage (Android Keystore / iOS Keychain)
/// so it cannot be trivially tampered with on rooted/jailbroken devices.
/// ─────────────────────────────────────────────────────────
/// When real payment is ready:
///   TODO: Integrate `in_app_purchase` (or Razorpay/Stripe) and call
///         [activatePremium] only after a successful payment callback.
///         Product ID to register on Play Console / App Store Connect:
///           com.refundoo.refundoo.premium_yearly  — ₹100/year
/// ─────────────────────────────────────────────────────────
class PremiumService {
  static const _kKey = 'premium_until_ms';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Returns `true` if the current time is before the stored expiry.
  static Future<bool> get isPremium async {
    final raw = await _storage.read(key: _kKey);
    final until = int.tryParse(raw ?? '') ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  /// Returns the expiry [DateTime], or `null` if the user is not premium.
  static Future<DateTime?> get expiryDate async {
    final raw = await _storage.read(key: _kKey);
    final until = int.tryParse(raw ?? '') ?? 0;
    if (until == 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(until);
    return dt.isAfter(DateTime.now()) ? dt : null;
  }

  /// Grants premium for 1 year from now.
  /// Call this after a successful payment confirmation.
  static Future<void> activatePremium() async {
    final expiry = DateTime.now().add(const Duration(days: 365));
    await _storage.write(
      key: _kKey,
      value: expiry.millisecondsSinceEpoch.toString(),
    );
  }

  /// Revokes premium immediately (e.g. refund or cancellation).
  static Future<void> revokePremium() async {
    await _storage.delete(key: _kKey);
  }
}
