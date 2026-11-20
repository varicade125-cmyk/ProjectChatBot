import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API-key storage contract. Production uses the platform Keychain/Keystore;
/// tests use an in-memory fake. Keys NEVER live in SQLite, logs, or exports.
abstract class AiCredentialStore {
  Future<String?> readKey();
  Future<void> writeKey(String key);
  Future<void> deleteKey();
  Future<bool> hasKey();
}

class SecureAiCredentialStore implements AiCredentialStore {
  static const String keyName = 'ai_api_key';
  final FlutterSecureStorage _storage;

  const SecureAiCredentialStore(
      [this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> readKey() => _storage.read(key: keyName);

  @override
  Future<void> writeKey(String key) =>
      _storage.write(key: keyName, value: key);

  @override
  Future<void> deleteKey() => _storage.delete(key: keyName);

  @override
  Future<bool> hasKey() async {
    final v = await _storage.read(key: keyName);
    return v != null && v.isNotEmpty;
  }
}
