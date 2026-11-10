import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/account.dart';
import '../domain/session_store.dart';

class DeviceSessionStore implements SessionStore {
  DeviceSessionStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secure = secureStorage ?? const FlutterSecureStorage();
  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secure;
  static const _rememberKey = 'mirage.iam.remember_session.v1';
  static const _tokenKey = 'mirage.iam.refresh_token.v1';

  Future<T> _access<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (_) {
      throw const AuthFailure(
        'session_storage_unavailable',
        'Could not access the saved session on this device. Please try again.',
      );
    }
  }

  @override
  Future<String?> readRefreshToken() => _access(() async {
    if (await _preferences.getBool(_rememberKey) != true) return null;
    return _secure.read(key: _tokenKey);
  });
  @override
  Future<void> writeRefreshToken(String token) => _access(() async {
    // Disable restoration until the new rotating credential is safely written.
    await _preferences.setBool(_rememberKey, false);
    await _secure.write(key: _tokenKey, value: token);
    await _preferences.setBool(_rememberKey, true);
  });
  @override
  Future<void> clear() => _access(() async {
    await _preferences.setBool(_rememberKey, false);
    await _secure.delete(key: _tokenKey);
  });
}
