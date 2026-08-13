import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logging/logging.dart';
import 'package:tailscale/tailscale.dart';

import 'embedded_tailscale_service.dart';
import 'finamp_settings_helper.dart';

/// [http.Client] that optionally routes through embedded Tailscale tsnet.
///
/// Chopper keeps a single client for the process lifetime; this delegates each
/// [send] to either the default [IOClient] or [Tailscale.instance.http.client]
/// based on the current [FinampSettings.useEmbeddedTailscale] flag and whether
/// tsnet is up.
///
/// Do **not** use this from background isolates — Hive settings are not open
/// there. [JellyfinApi.create] passes a plain [IOClient] when `inForeground`
/// is false.
class FinampHttpClient extends http.BaseClient {
  FinampHttpClient({Duration connectionTimeout = const Duration(seconds: 10)})
    : _default = IOClient(HttpClient()..connectionTimeout = connectionTimeout);

  final http.Client _default;
  final _log = Logger('FinampHttpClient');

  bool get _useEmbeddedTs {
    try {
      return FinampSettingsHelper.finampSettings.useEmbeddedTailscale;
    } catch (e) {
      _log.warning('settings unavailable ($e); assuming embedded TS off');
      return false;
    }
  }

  http.Client get _active {
    if (!_useEmbeddedTs) return _default;
    if (!EmbeddedTailscaleService.isRunning) {
      return _default;
    }
    try {
      return Tailscale.instance.http.client;
    } catch (e) {
      _log.warning('Tailscale http.client unavailable ($e); using default');
      return _default;
    }
  }

  /// MagicDNS (`*.ts.net`) or Tailscale CGNAT (`100.64.0.0/10`).
  static bool looksLikeTailnetHost(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.endsWith('.ts.net') || host.endsWith('.ts.net.')) return true;
    final ip = InternetAddress.tryParse(host);
    if (ip == null || ip.type != InternetAddressType.IPv4) return false;
    final b = ip.rawAddress;
    return b[0] == 100 && b[1] >= 64 && b[1] <= 127;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_useEmbeddedTs && looksLikeTailnetHost(request.url) && !EmbeddedTailscaleService.isRunning) {
      await EmbeddedTailscaleService.ensureRunning();
    }
    if (_useEmbeddedTs && !EmbeddedTailscaleService.isRunning && looksLikeTailnetHost(request.url)) {
      _log.warning(
        'MagicDNS request while tsnet is not Running: ${request.url} '
        '(status=${EmbeddedTailscaleService.lastStatus?.state}). '
        'Connect with an auth key under Settings → Embedded Tailscale.',
      );
      throw http.ClientException(
        'Embedded Tailscale is not connected (node not Running). '
        'Open Settings → Embedded Tailscale, paste a tskey-auth-… key, '
        'and Connect before using MagicDNS URLs like ${request.url.host}.',
        request.url,
      );
    }
    if (_useEmbeddedTs && !EmbeddedTailscaleService.isRunning) {
      _log.warning('useEmbeddedTailscale is on but tsnet is not running; using default client');
    }
    return _active.send(request);
  }

  @override
  void close() {
    _default.close();
    // Do not close Tailscale.instance.http.client — owned by the package.
  }
}
