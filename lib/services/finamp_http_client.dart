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
class FinampHttpClient extends http.BaseClient {
  FinampHttpClient({Duration connectionTimeout = const Duration(seconds: 10)})
    : _default = IOClient(
        HttpClient()..connectionTimeout = connectionTimeout,
      );

  final http.Client _default;
  final _log = Logger('FinampHttpClient');

  http.Client get _active {
    final useTs = FinampSettingsHelper.finampSettings.useEmbeddedTailscale;
    if (!useTs) return _default;
    if (!EmbeddedTailscaleService.isRunning) {
      _log.warning(
        'useEmbeddedTailscale is on but tsnet is not running; using default client',
      );
      return _default;
    }
    try {
      return Tailscale.instance.http.client;
    } catch (e) {
      _log.warning('Tailscale http.client unavailable ($e); using default');
      return _default;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _active.send(request);
  }

  @override
  void close() {
    _default.close();
    // Do not close Tailscale.instance.http.client — owned by the package.
  }
}
