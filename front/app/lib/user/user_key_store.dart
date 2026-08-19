import 'package:shared_preferences/shared_preferences.dart';

abstract interface class UserKeyStore {
  Future<String?> read();

  Future<void> write(String userKey);

  Future<void> clear();
}

abstract interface class AsyncStringPreferences {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesAsyncAdapter implements AsyncStringPreferences {
  SharedPreferencesAsyncAdapter({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }
}

class SharedPreferencesUserKeyStore implements UserKeyStore {
  SharedPreferencesUserKeyStore({AsyncStringPreferences? preferences})
    : _preferences = preferences ?? SharedPreferencesAsyncAdapter();

  static const String storageKey = 'novelty.user_key';

  final AsyncStringPreferences _preferences;

  @override
  Future<String?> read() async {
    final value = await _preferences.getString(storageKey);
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> write(String userKey) async {
    final normalized = userKey.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(userKey, 'userKey', 'User key is required.');
    }
    await _preferences.setString(storageKey, normalized);
  }

  @override
  Future<void> clear() => _preferences.remove(storageKey);
}
