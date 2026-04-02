import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'finamp_settings_helper.dart';

class ClientCertificateInstaller {
  static final _logger = Logger('ClientCertificateInstaller');
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/client_certificate');

  /// Installs the configured [ClientCertificate] to the [SecurityContext.defaultContext], if available.
  Future<void> defaultInstallClientCertificate() async {
    await installClientCertificate(SecurityContext.defaultContext);
  }

  /// Installs the configured [ClientCertificate] into the given [context], if available.
  Future<void> installClientCertificate(SecurityContext context) async {
    var cert = FinampSettingsHelper.finampSettings.clientCertificate;
    if (cert == null) {
      return;
    }

    try {
      context.usePrivateKeyBytes(cert.data, password: cert.password);
      // "On iOS one call to usePrivateKey […] is used instead of two calls
      // to useCertificateChain and usePrivateKey." (see [SecurityContext.usePrivateKey]).
      if (!Platform.isIOS) {
        context.useCertificateChainBytes(cert.data, password: cert.password);
      }
    } catch (e) {
      _logger.warning('Failed to install client certificate in SecurityContext: $e');
    }

    // On Android, ExoPlayer uses HttpURLConnection (not Dart's HttpClient),
    // so we also configure the JVM-global SSLContext via a method channel.
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('installClientCertificate', {'bytes': cert.data, 'password': cert.password});
      } catch (e) {
        _logger.warning('Failed to install client certificate in Android SSL context: $e');
      }
    }
  }

  Future<void> defaultClearClientCertificate() async {
    await clearClientCertificate(SecurityContext.defaultContext);
  }

  Future<void> clearClientCertificate(SecurityContext context) async {
    // TODO: clear certificate from context

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('clearClientCertificate');
      } catch (e) {
        _logger.warning('Failed to install client certificate in Android SSL context: $e');
      }
    }
  }
}
