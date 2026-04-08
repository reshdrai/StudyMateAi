import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'accessToken';
  static const String _emailKey = 'userEmail';
  static const String _nameKey = 'userName';
  static const String _roleKey = 'userRole';

  static Future<void> saveAuthData({
    required String token,
    String? email,
    String? name,
    String? role,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    if (email != null) await _storage.write(key: _emailKey, value: email);
    if (name != null) await _storage.write(key: _nameKey, value: name);
    if (role != null) await _storage.write(key: _roleKey, value: role);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _roleKey);
  }
}
