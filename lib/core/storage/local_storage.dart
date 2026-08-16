import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _keyServerUrl = 'server_url';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyApiKey = 'api_key';
  static const String _keyApiModel = 'api_model';
  static const String _keyApiProxy = 'api_proxy';
  static const String _keyApiSource = 'api_source';
  static const String _keyApiCustomUrl = 'api_custom_url';

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

  String? get apiKey => _prefs.getString(_keyApiKey);

  Future<void> setApiKey(String value) async {
    await _prefs.setString(_keyApiKey, value);
  }

  String? get apiModel => _prefs.getString(_keyApiModel);

  Future<void> setApiModel(String value) async {
    await _prefs.setString(_keyApiModel, value);
  }

  String? get apiProxy => _prefs.getString(_keyApiProxy);

  Future<void> setApiProxy(String value) async {
    await _prefs.setString(_keyApiProxy, value);
  }

  String get apiSource => _prefs.getString(_keyApiSource) ?? 'custom';

  Future<void> setApiSource(String value) async {
    await _prefs.setString(_keyApiSource, value);
  }

  String get apiCustomUrl =>
      _prefs.getString(_keyApiCustomUrl) ?? 'https://opencode.ai/zen/go/v1';

  Future<void> setApiCustomUrl(String value) async {
    await _prefs.setString(_keyApiCustomUrl, value);
  }
}
