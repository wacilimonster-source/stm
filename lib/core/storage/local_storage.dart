import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _keyServerUrl = 'server_url';
  static const String _keyThemeMode = 'theme_mode';

  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  String? get serverUrl => _prefs.getString(_keyServerUrl);

  Future<void> setServerUrl(String url) async {
    await _prefs.setString(_keyServerUrl, url);
  }

  Future<void> clearServerUrl() async {
    await _prefs.remove(_keyServerUrl);
  }

  bool get isDarkMode => _prefs.getBool(_keyThemeMode) ?? true;

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_keyThemeMode, value);
  }
}
