import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miragemobile/iam/infrastructure/device_session_store.dart';

class MemoryPreferences implements SharedPreferencesAsync {
  final values = <String, bool>{};
  @override
  Future<bool?> getBool(String key) async => values[key];
  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'preferences contain only a flag; credential is in secure storage and is removed on logout',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const secure = FlutterSecureStorage();
      final preferences = MemoryPreferences();
      final store = DeviceSessionStore(
        preferences: preferences,
        secureStorage: secure,
      );
      await store.writeRefreshToken('fake-rotating-credential');
      expect(preferences.values, {'mirage.iam.remember_session.v1': true});
      expect(
        await secure.read(key: 'mirage.iam.refresh_token.v1'),
        'fake-rotating-credential',
      );
      expect(await store.readRefreshToken(), 'fake-rotating-credential');
      await store.clear();
      expect(await store.readRefreshToken(), isNull);
      expect(await secure.read(key: 'mirage.iam.refresh_token.v1'), isNull);
    },
  );
  test(
    'a leftover keychain credential without an install preference is not restored',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'mirage.iam.refresh_token.v1': 'old-install',
      });
      final store = DeviceSessionStore(preferences: MemoryPreferences());
      expect(await store.readRefreshToken(), isNull);
    },
  );
}
