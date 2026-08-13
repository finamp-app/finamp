import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-backed encrypted storage for fork secrets (Keychain / Keystore).
///
/// Holds:
/// - Embedded Tailscale auth key (`tskey-auth-…`)
/// - Music Finder server base URL
///
/// Values are never written to Hive or plain SharedPreferences after migration.
class FinampSecrets {
  FinampSecrets._();

  static final _log = Logger('FinampSecrets');

  static const _authKeyStorageKey = 'embedded_tailscale_auth_key';
  static const _musicFinderUrlStorageKey = 'music_finder_server_url';

  /// Legacy plaintext prefs key used before secure storage.
  static const _legacyPrefsAuthKey = 'embedded_tailscale_auth_key';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static bool _initialized = false;
  static String? _musicFinderUrlCache;

  /// Cached Music Finder URL after [ensureInitialized] (sync reads for UI).
  static String? get musicFinderServerUrl => _musicFinderUrlCache;

  static bool get hasMusicFinderServer {
    final url = _musicFinderUrlCache?.trim();
    return url != null && url.isNotEmpty;
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _migrateLegacyAuthKeyFromPrefs();
    _musicFinderUrlCache =
        (await _storage.read(key: _musicFinderUrlStorageKey))?.trim();
    if (_musicFinderUrlCache != null && _musicFinderUrlCache!.isEmpty) {
      _musicFinderUrlCache = null;
    }
    _initialized = true;
    final hasAuth =
        ((await _storage.read(key: _authKeyStorageKey))?.trim() ?? '').isNotEmpty;
    _log.info(
      'Secure secrets ready (authKey=$hasAuth, musicFinder=$hasMusicFinderServer)',
    );
  }

  static Future<String?> loadAuthKey() async {
    await ensureInitialized();
    final key = (await _storage.read(key: _authKeyStorageKey))?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  static Future<void> storeAuthKey(String? authKey) async {
    await ensureInitialized();
    final trimmed = authKey?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _storage.delete(key: _authKeyStorageKey);
    } else {
      await _storage.write(key: _authKeyStorageKey, value: trimmed);
    }
    // Drop any leftover plaintext prefs copy.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsAuthKey);
  }

  static Future<void> setMusicFinderServerUrl(String? url) async {
    await ensureInitialized();
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _storage.delete(key: _musicFinderUrlStorageKey);
      _musicFinderUrlCache = null;
    } else {
      await _storage.write(key: _musicFinderUrlStorageKey, value: trimmed);
      _musicFinderUrlCache = trimmed;
    }
  }

  /// Move plaintext SharedPreferences auth key into the Keychain/Keystore.
  static Future<void> _migrateLegacyAuthKeyFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsAuthKey)?.trim();
    if (legacy == null || legacy.isEmpty) return;

    final existing = (await _storage.read(key: _authKeyStorageKey))?.trim();
    if (existing == null || existing.isEmpty) {
      await _storage.write(key: _authKeyStorageKey, value: legacy);
      _log.info('Migrated Tailscale auth key from SharedPreferences to secure storage');
    }
    await prefs.remove(_legacyPrefsAuthKey);
  }
}
