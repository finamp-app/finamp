import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'finamp_settings_helper.dart';
import 'jellyfin_api_helper.dart';

class ClientCertificateInstaller {
  static final isSupported = Platform.isAndroid;

  static final _logger = Logger('ClientCertificateInstaller');
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/client_certificate');

  /// Installs the configured [ClientCertificate] in the whole app, if supported and available:
  /// - into the [SecurityContext.defaultContext] used by Dart's HttpClient
  /// - into the process-global Android SSL context
  Future<void> installClientCertificate() async {
    if (!isSupported) {
      return;
    }
    var cert = FinampSettingsHelper.finampSettings.clientCertificate;
    if (cert == null) {
      return;
    }

    installCertificateInSecurityContext(cert, SecurityContext.defaultContext);

    // Install certificate to worker isolate with separate SecurityContext.
    // During app startup, the API helper isn't registered yet, we can ignore that,
    // since it'll pass the certificate to the isolate itself when spawning it.
    if (GetIt.instance.isRegistered<JellyfinApiHelper>()) {
      try {
        await GetIt.instance<JellyfinApiHelper>().runInIsolate((_) async {
          ClientCertificateInstaller().installCertificateInSecurityContext(cert, SecurityContext.defaultContext);
          return true;
        });
      } catch (e) {
        _logger.warning('Failed to install client certificate in worker isolate: $e');
      }
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

  /// Installs the given [cert] into [context].
  void installCertificateInSecurityContext(ClientCertificate cert, SecurityContext context) {
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
  }

  Future<void> clearClientCertificate() async {
    // TODO: clear certificate from SecurityContext.defaultContext

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('clearClientCertificate');
      } catch (e) {
        _logger.warning('Failed to clear client certificate from Android SSL context: $e');
      }
    }
  }
}
