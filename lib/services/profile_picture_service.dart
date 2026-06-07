import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages picking and persisting a custom local profile picture.
class ProfilePictureService {
  static const _key = 'profile_picture_path';
  static final _picker = ImagePicker();

  /// Returns the saved local [File], or null if none has been set / it was deleted.
  static Future<File?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// Opens [source] (camera or gallery), copies the chosen image into the app's
  /// documents directory so it survives app updates, and persists the path.
  /// Returns the saved [File], or null if the user cancelled.
  static Future<File?> pick({required ImageSource source}) async {
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xFile == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_picture.jpg');
    await File(xFile.path).copy(dest.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dest.path);
    return dest;
  }

  /// Removes the saved profile picture and clears the stored path.
  static Future<void> clear() async {
    final file = await loadLocal();
    if (file != null) {
      try { await file.delete(); } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
