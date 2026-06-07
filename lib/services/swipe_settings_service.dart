import 'package:shared_preferences/shared_preferences.dart';

/// Which action a swipe gesture triggers.
enum SwipeAction { archive, delete }

extension SwipeActionX on SwipeAction {
  String get label => this == SwipeAction.archive ? 'Archive' : 'Delete';
  String get key   => name; // 'archive' | 'delete'
}

/// Persists the user's swipe gesture preferences.
class SwipeSettingsService {
  static const _keyLeft  = 'swipe_left_action';
  static const _keyRight = 'swipe_right_action';

  /// Left-swipe action (default: delete).
  static Future<SwipeAction> getLeftAction() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keyLeft);
    return val == 'archive' ? SwipeAction.archive : SwipeAction.delete;
  }

  /// Right-swipe action (default: archive).
  static Future<SwipeAction> getRightAction() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keyRight);
    return val == 'delete' ? SwipeAction.delete : SwipeAction.archive;
  }

  static Future<void> setLeftAction(SwipeAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLeft, action.key);
  }

  static Future<void> setRightAction(SwipeAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRight, action.key);
  }

  /// Loads both settings at once (used by swipeable widgets).
  static Future<({SwipeAction left, SwipeAction right})> load() async {
    final left  = await getLeftAction();
    final right = await getRightAction();
    return (left: left, right: right);
  }
}
