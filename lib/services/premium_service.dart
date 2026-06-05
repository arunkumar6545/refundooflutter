import 'package:shared_preferences/shared_preferences.dart';

/// Manages the Premium subscription state.
///
/// Premium is stored locally as a Unix-ms expiry timestamp.
/// ─────────────────────────────────────────────────────────
/// When real payment is ready:
///   TODO: Integrate `in_app_purchase` (or Razorpay/Stripe) and call
///         [activatePremium] only after a successful payment callback.
///         Product ID to register on Play Console / App Store Connect:
///           com.refundoo.refundoo.premium_yearly  — ₹100/year
/// ─────────────────────────────────────────────────────────
class PremiumService {
  static const _kKey = 'premium_until_ms';

  /// Returns `true` if the current time is before the stored expiry.
  static Future<bool> get isPremium async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_kKey) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  /// Returns the expiry [DateTime], or `null` if the user is not premium.
  static Future<DateTime?> get expiryDate async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_kKey) ?? 0;
    if (until == 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(until);
    return dt.isAfter(DateTime.now()) ? dt : null;
  }

  /// Grants premium for 1 year from now.
  /// Call this after a successful payment confirmation.
  static Future<void> activatePremium() async {
    final expiry = DateTime.now().add(const Duration(days: 365));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKey, expiry.millisecondsSinceEpoch);
  }

  /// Revokes premium immediately (e.g. refund or cancellation).
  static Future<void> revokePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
