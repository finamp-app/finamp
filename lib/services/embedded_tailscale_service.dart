import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tailscale/tailscale.dart';

import 'finamp_secrets.dart';

/// Lifecycle wrapper around [package:tailscale] userspace tsnet.
///
/// Keeps the node state directory under application support and marks it
/// excluded from iCloud backup on iOS (leaked WireGuard keys can impersonate
/// the node).
///
/// **Connect strategy:**
/// 1. Prefer [up] **without** an auth key so persisted credentials reconnect
///    (package:tailscale’s normal cold-start path).
/// 2. Only if that fails or returns [NodeState.needsLogin], enroll with a
///    stored/pasted auth key and `TSNET_FORCE_LOGIN=1` (needed when tsnet
///    would otherwise ignore AuthKey on `NoState`).
///
/// Always passing an auth key + FORCE_LOGIN on every launch breaks auto-connect
/// (one-time keys, and StartLoginInteractive instead of resume).
class EmbeddedTailscaleService {
  EmbeddedTailscaleService._();

  static final _log = Logger('EmbeddedTailscaleService');
  static bool _initialized = false;
  static String? _stateDirPath;
  static TailscaleStatus? _lastStatus;
  static Object? _lastError;

  static TailscaleStatus? get lastStatus => _lastStatus;
  static Object? get lastError => _lastError;
  static bool get isRunning => _lastStatus?.isRunning ?? false;
  static Uri? get authUrl => _lastStatus?.authUrl;

  static Future<bool>? _ensureRunningInFlight;

  /// Resume tsnet if the node dropped (common after Wi‑Fi ↔ cellular).
  ///
  /// Concurrent callers share one in-flight attempt.
  static Future<bool> ensureRunning({Duration timeout = const Duration(seconds: 12)}) {
    if (isRunning) return Future.value(true);
    return _ensureRunningInFlight ??= _ensureRunningBody(timeout: timeout).whenComplete(() {
      _ensureRunningInFlight = null;
    });
  }

  static Future<bool> _ensureRunningBody({required Duration timeout}) async {
    if (isRunning) return true;
    try {
      await up();
    } catch (e, st) {
      _log.warning('ensureRunning up() failed', e, st);
    }
    if (isRunning) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) && !isRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        await refreshStatus();
      } catch (_) {}
    }
    if (!isRunning) {
      _log.warning('ensureRunning: still not Running (state=${lastStatus?.state})');
    }
    return isRunning;
  }

  /// Ensure [Tailscale.init] has been called with a backup-excluded state dir.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await FinampSecrets.ensureInitialized();
    final support = await getApplicationSupportDirectory();
    final stateDir = Directory(p.join(support.path, 'embedded_tailscale'));
    if (!await stateDir.exists()) {
      await stateDir.create(recursive: true);
    }
    await _excludeFromBackup(stateDir);
    _stateDirPath = stateDir.path;
    Tailscale.init(stateDir: stateDir.path);
    _initialized = true;
    _log.info('Initialized tsnet stateDir=${stateDir.path}');
  }

  static Future<String?> loadStoredAuthKey() => FinampSecrets.loadAuthKey();

  static Future<void> storeAuthKey(String? authKey) => FinampSecrets.storeAuthKey(authKey);

  /// Bring the node up.
  ///
  /// By default resumes from disk when possible. Pass [forceEnroll] / a fresh
  /// [authKey] to register (or re-register) with the control plane.
  static Future<TailscaleStatus> up({
    String? authKey,
    String hostname = 'finamp',
    bool ephemeral = false,
    bool forceEnroll = false,
  }) async {
    await ensureInitialized();
    _lastError = null;

    var key = authKey?.trim();
    if (key == null || key.isEmpty) {
      key = await loadStoredAuthKey();
    }

    if (!forceEnroll) {
      final resumed = await _tryResume(hostname: hostname, ephemeral: ephemeral);
      if (resumed != null) {
        if (resumed.isRunning) {
          return resumed;
        }
        if (!resumed.needsLogin) {
          // needsMachineAuth or other stable non-running state
          return resumed;
        }
        _log.info('Resume reached needsLogin; will enroll with auth key if available');
      }
    }

    if (key == null || key.isEmpty) {
      _lastStatus = TailscaleStatus.stopped;
      throw StateError(
        'Embedded Tailscale needs an auth key. Paste a tskey-auth-… key '
        'from the Tailscale admin console, then Connect.',
      );
    }

    return _enrollWithAuthKey(key: key, hostname: hostname, ephemeral: ephemeral);
  }

  /// Resume without auth key (persisted node identity). Returns null if the
  /// native stack rejects the call (typically no state on disk).
  static Future<TailscaleStatus?> _tryResume({required String hostname, required bool ephemeral}) async {
    _clearTsnetForceLogin();
    try {
      final status = await Tailscale.instance.up(hostname: hostname, ephemeral: ephemeral);
      _lastStatus = status;
      _log.info(
        'Resume up() → state=${status.state} ipv4=${status.ipv4} '
        'isRunning=${status.isRunning}',
      );
      return status;
    } catch (e, st) {
      _log.info('Resume without auth key failed (will try enroll if key): $e');
      _log.fine('Resume stack', e, st);
      return null;
    }
  }

  static Future<TailscaleStatus> _enrollWithAuthKey({
    required String key,
    required String hostname,
    required bool ephemeral,
  }) async {
    // Without this, tsnet logs: "Authkey is set; but state is NoState.
    // Ignoring authkey." on first enrollment.
    _enableTsnetForceLogin();
    try {
      final status = await Tailscale.instance.up(hostname: hostname, authKey: key, ephemeral: ephemeral);
      _lastStatus = status;
      await storeAuthKey(key);
      _log.info(
        'Enroll up() → state=${status.state} ipv4=${status.ipv4} '
        'needsLogin=${status.needsLogin} isRunning=${status.isRunning}',
      );
      if (!status.isRunning) {
        _log.warning(
          'tsnet did not reach Running after auth-key enroll '
          '(state=${status.state}). MagicDNS will fail until Running.',
        );
      }
      return status;
    } catch (e, st) {
      _lastError = e;
      _log.severe('enroll up() failed', e, st);
      rethrow;
    } finally {
      // Do not leave FORCE_LOGIN set for the rest of the process lifetime.
      _clearTsnetForceLogin();
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
  static StreamSubscription<NodeState> listenState(void Function(TailscaleStatus status) onData) {
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

  static void _enableTsnetForceLogin() {
    _setEnv('TSNET_FORCE_LOGIN', '1');
    _log.info('Set TSNET_FORCE_LOGIN=1 for auth-key enrollment');
  }

  static void _clearTsnetForceLogin() {
    _unsetEnv('TSNET_FORCE_LOGIN');
  }

  static void _setEnv(String key, String value) {
    if (kIsWeb) return;
    try {
      final lib = _libc;
      final setenv = lib
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int32),
            int Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int)
          >('setenv');
      final k = key.toNativeUtf8();
      final v = value.toNativeUtf8();
      try {
        final rc = setenv(k, v, 1);
        if (rc != 0) {
          _log.warning('setenv($key) returned $rc');
        }
      } finally {
        malloc.free(k);
        malloc.free(v);
      }
    } catch (e, st) {
      _log.severe('Failed to setenv($key)', e, st);
    }
  }

  static void _unsetEnv(String key) {
    if (kIsWeb) return;
    try {
      final lib = _libc;
      final unsetenv = lib.lookupFunction<ffi.Int32 Function(ffi.Pointer<Utf8>), int Function(ffi.Pointer<Utf8>)>(
        'unsetenv',
      );
      final k = key.toNativeUtf8();
      try {
        unsetenv(k);
      } finally {
        malloc.free(k);
      }
    } catch (e, st) {
      _log.warning('Failed to unsetenv($key)', e, st);
    }
  }

  static ffi.DynamicLibrary get _libc =>
      (Platform.isAndroid || Platform.isLinux) ? ffi.DynamicLibrary.open('libc.so') : ffi.DynamicLibrary.process();

  static Future<void> _excludeFromBackup(Directory dir) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await Process.run('xattr', ['-w', 'com.apple.MobileBackup', '1', dir.path]);
    } catch (e) {
      _log.warning('Could not exclude Tailscale state from backup: $e');
    }
  }
}
