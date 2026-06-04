import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Google Sign-In and persists session credentials in encrypted storage.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Non-sensitive flags stay in SharedPreferences
  static const _keySignedIn = 'auth_signed_in';

  // Sensitive identity data goes in encrypted storage
  static const _secKeyName  = 'auth_sec_name';
  static const _secKeyEmail = 'auth_sec_email';
  static const _secKeyPhoto = 'auth_sec_photo';
  static const _secKeyGuest = 'auth_sec_is_guest';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

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

  /// Restore persisted session from encrypted storage on app start.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final wasSignedIn = prefs.getBool(_keySignedIn) ?? false;
    if (!wasSignedIn) return false;

    // Try silent sign-in to refresh token
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) return true;
    } catch (_) {}

    // Restore from secure storage
    final name = await _secureStorage.read(key: _secKeyName);
    if (name != null) {
      final isGuest = await _secureStorage.read(key: _secKeyGuest);
      if (isGuest == 'true') _isGuest = true;
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
    await _secureStorage.write(key: _secKeyName, value: 'Guest');
    await _secureStorage.write(key: _secKeyEmail, value: '');
    await _secureStorage.write(key: _secKeyGuest, value: 'true');
  }

  bool _guestChecked = false;
  Future<bool> get isGuest async {
    if (!_guestChecked) {
      _guestChecked = true;
      final val = await _secureStorage.read(key: _secKeyGuest);
      _isGuest = val == 'true';
    }
    return _isGuest;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _isGuest = false;
    _guestChecked = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySignedIn);
    await _secureStorage.deleteAll();
  }

  Future<void> _persistUser(GoogleSignInAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySignedIn, true);
    await _secureStorage.write(key: _secKeyName, value: account.displayName ?? '');
    await _secureStorage.write(key: _secKeyEmail, value: account.email);
    if (account.photoUrl != null) {
      await _secureStorage.write(key: _secKeyPhoto, value: account.photoUrl!);
    }
  }

  // ── Cached getters ──────────────────────────────────────────────────────────

  Future<String> get cachedName async {
    if (_currentUser?.displayName != null) return _currentUser!.displayName!;
    return await _secureStorage.read(key: _secKeyName) ?? 'User';
  }

  Future<String> get cachedEmail async {
    if (_currentUser?.email != null) return _currentUser!.email;
    return await _secureStorage.read(key: _secKeyEmail) ?? '';
  }

  Future<String?> get cachedPhotoUrl async {
    if (_currentUser?.photoUrl != null) return _currentUser!.photoUrl;
    return await _secureStorage.read(key: _secKeyPhoto);
  }
}
