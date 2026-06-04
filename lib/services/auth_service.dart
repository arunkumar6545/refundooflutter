import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Google Sign-In and persists the session locally.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _keySignedIn = 'auth_signed_in';
  static const _keyName = 'auth_name';
  static const _keyEmail = 'auth_email';
  static const _keyPhoto = 'auth_photo';

  static const _gmailScope =
      'https://www.googleapis.com/auth/gmail.readonly';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  bool _isGuest = false;

  /// True when signed in with Google OR continuing as guest.
  bool get isSignedIn => _currentUser != null || _isGuest;

  /// Request Gmail readonly scope for the current signed-in account.
  /// Returns true when the scope is granted.
  Future<bool> requestGmailScope() async {
    if (_currentUser == null) return false;
    try {
      final granted = await _googleSignIn.requestScopes([_gmailScope]);
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// True when the current account has the Gmail readonly scope.
  Future<bool> get hasGmailScope async {
    if (_currentUser == null) return false;
    try {
      return await GoogleSignIn(scopes: [_gmailScope]).isSignedIn();
    } catch (_) {
      return false;
    }
  }

  /// Restore persisted session from SharedPreferences on app start.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final wasSignedIn = prefs.getBool(_keySignedIn) ?? false;
    if (!wasSignedIn) return false;

    // Try silent sign-in to refresh token
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) return true;
    } catch (_) {}

    // Guest session or cached Google identity
    final name = prefs.getString(_keyName);
    final email = prefs.getString(_keyEmail);
    if (name != null) {
      // Restore guest flag if applicable
      if (prefs.getBool('_is_guest') == true) _isGuest = true;
      return true;
    }
    return false;
  }

  /// Trigger the Google account chooser dialog.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      _currentUser = account;
      await _persistUser(account);
      return account;
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a local guest session — no Google account needed.
  Future<void> signInAsGuest() async {
    _isGuest = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySignedIn, true);
    await prefs.setString(_keyName, 'Guest');
    await prefs.setString(_keyEmail, '');
    await prefs.setBool('_is_guest', true);
  }

  bool _guestChecked = false;
  Future<bool> get isGuest async {
    if (!_guestChecked) {
      final prefs = await SharedPreferences.getInstance();
      _guestChecked = true;
      return prefs.getBool('_is_guest') ?? false;
    }
    return false;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _isGuest = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySignedIn);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhoto);
    await prefs.remove('_is_guest');
  }

  Future<void> _persistUser(GoogleSignInAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySignedIn, true);
    await prefs.setString(_keyName, account.displayName ?? '');
    await prefs.setString(_keyEmail, account.email);
    if (account.photoUrl != null) {
      await prefs.setString(_keyPhoto, account.photoUrl!);
    }
  }

  // ── Cached getters (works even when GoogleSignInAccount is null) ─────────

  Future<String> get cachedName async {
    if (_currentUser?.displayName != null) return _currentUser!.displayName!;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName) ?? 'User';
  }

  Future<String> get cachedEmail async {
    if (_currentUser?.email != null) return _currentUser!.email;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  Future<String?> get cachedPhotoUrl async {
    if (_currentUser?.photoUrl != null) return _currentUser!.photoUrl;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhoto);
  }
}
