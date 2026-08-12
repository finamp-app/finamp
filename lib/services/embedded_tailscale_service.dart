import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailscale/tailscale.dart';

/// Lifecycle wrapper around [package:tailscale] userspace tsnet.
///
/// Keeps the node state directory under application support and marks it
/// excluded from iCloud backup on iOS (leaked WireGuard keys can impersonate
/// the node).
///
/// **Auth keys only on iOS:** calling [up] without an auth key while the node
/// is in `NeedsLogin` makes tsnet run `StartLoginInteractive`, which opens an
/// auth sheet that can abort the process with an empty `NSUserActivity`.
/// Prefer a reusable auth key from the Tailscale admin console.
class EmbeddedTailscaleService {
  EmbeddedTailscaleService._();

  static final _log = Logger('EmbeddedTailscaleService');
  static const _authKeyPrefsKey = 'embedded_tailscale_auth_key';
  static bool _initialized = false;
  static TailscaleStatus? _lastStatus;
  static Object? _lastError;

  static TailscaleStatus? get lastStatus => _lastStatus;
  static Object? get lastError => _lastError;
  static bool get isRunning => _lastStatus?.isRunning ?? false;
  static Uri? get authUrl => _lastStatus?.authUrl;

  /// Ensure [Tailscale.init] has been called with a backup-excluded state dir.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    final support = await getApplicationSupportDirectory();
    final stateDir = Directory(p.join(support.path, 'embedded_tailscale'));
    if (!await stateDir.exists()) {
      await stateDir.create(recursive: true);
    }
    await _excludeFromBackup(stateDir);
    Tailscale.init(stateDir: stateDir.path);
    _initialized = true;
    _log.info('Initialized tsnet stateDir=${stateDir.path}');
  }

  static Future<String?> loadStoredAuthKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_authKeyPrefsKey)?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  static Future<void> storeAuthKey(String? authKey) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = authKey?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(_authKeyPrefsKey);
    } else {
      await prefs.setString(_authKeyPrefsKey, trimmed);
    }
  }

  /// Bring the node up. Prefer [authKey] for unattended join.
  ///
  /// On iOS, refuses to start without an auth key (stored or argument) so
  /// tsnet never enters interactive login. On other platforms, empty auth
  /// key may resume an already-registered node or surface [authUrl].
  static Future<TailscaleStatus> up({
    String? authKey,
    String hostname = 'finamp',
    bool ephemeral = false,
    bool allowInteractiveLogin = false,
  }) async {
    await ensureInitialized();
    _lastError = null;

    var key = authKey?.trim();
    if (key == null || key.isEmpty) {
      key = await loadStoredAuthKey();
    }

    if ((key == null || key.isEmpty) &&
        !allowInteractiveLogin &&
        (Platform.isIOS || Platform.isAndroid)) {
      _log.warning(
        'up() skipped: no auth key (interactive Tailscale login disabled '
        'on mobile to avoid NSUserActivity crashes)',
      );
      _lastStatus = TailscaleStatus.stopped;
      throw StateError(
        'Embedded Tailscale needs an auth key. Paste a tskey-auth-… key '
        'from the Tailscale admin console, then Connect.',
      );
    }

    try {
      final status = await Tailscale.instance.up(
        hostname: hostname,
        authKey: key,
        ephemeral: ephemeral,
      );
      _lastStatus = status;
      if (key != null && key.isNotEmpty) {
        await storeAuthKey(key);
      }
      _log.info(
        'up() → state=${status.state} ipv4=${status.ipv4} '
        'needsLogin=${status.needsLogin}',
      );
      return status;
    } catch (e, st) {
      _lastError = e;
      _log.severe('up() failed', e, st);
      rethrow;
    }
  }

  static Future<void> down() async {
    if (!_initialized) return;
    await Tailscale.instance.down();
    _lastStatus = await Tailscale.instance.status();
  }

  /// Revoke the node with the control plane and wipe local state.
  static Future<void> logout() async {
    if (!_initialized) return;
    await Tailscale.instance.logout();
    await storeAuthKey(null);
    _lastStatus = TailscaleStatus.stopped;
  }

  /// Refresh cached status from the native runtime.
  static Future<TailscaleStatus> refreshStatus() async {
    await ensureInitialized();
    _lastStatus = await Tailscale.instance.status();
    return _lastStatus!;
  }

  /// Listen for lifecycle state changes; refreshes [lastStatus] on each event.
  static StreamSubscription<NodeState> listenState(
    void Function(TailscaleStatus status) onData,
  ) {
    return Tailscale.instance.onStateChange.listen((_) async {
      try {
        final status = await Tailscale.instance.status();
        _lastStatus = status;
        onData(status);
      } catch (e, st) {
        _log.warning('status() after state change failed', e, st);
      }
    });
  }

  static Future<void> _excludeFromBackup(Directory dir) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      // NSURLIsExcludedFromBackupKey via xattr (same effect as Foundation API).
      await Process.run('xattr', [
        '-w',
        'com.apple.MobileBackup',
        '1',
        dir.path,
      ]);
    } catch (e) {
      _log.warning('Could not exclude Tailscale state from backup: $e');
    }
  }
}
