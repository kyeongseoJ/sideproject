import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/user/user_key_store.dart';

void main() {
  test('persists, restores, and clears the user key', () async {
    final preferences = _MemoryPreferences();
    final store = SharedPreferencesUserKeyStore(preferences: preferences);

    expect(await store.read(), isNull);
    await store.write('  cached-user-key  ');
    expect(await store.read(), 'cached-user-key');
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('rejects an empty user key', () async {
    final store = SharedPreferencesUserKeyStore(
      preferences: _MemoryPreferences(),
    );

    await expectLater(store.write('   '), throwsArgumentError);
  });
}

class _MemoryPreferences implements AsyncStringPreferences {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
