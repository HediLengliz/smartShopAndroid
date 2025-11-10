import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _rememberedEmailKey = 'remembered_email';
  static const String _rememberedPasswordKey = 'remembered_password';
  static const String _rememberMeKey = 'remember_me';

  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  static Future<void> saveUserData(String userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, userData);
  }

  static Future<String?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  static Future<void> deleteUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  static Future<void> clearAll() async {
    await deleteToken();
    await deleteUserData();
  }

  // Remember Me functionality
  static Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(key: _rememberedEmailKey, value: email);
    await _secureStorage.write(key: _rememberedPasswordKey, value: password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, true);
  }

  static Future<Map<String, String?>> getRememberedCredentials() async {
    final email = await _secureStorage.read(key: _rememberedEmailKey);
    final password = await _secureStorage.read(key: _rememberedPasswordKey);
    return {
      'email': email,
      'password': password,
    };
  }

  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  static Future<void> clearRememberedCredentials() async {
    await _secureStorage.delete(key: _rememberedEmailKey);
    await _secureStorage.delete(key: _rememberedPasswordKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
  }
}
