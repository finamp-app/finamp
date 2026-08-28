import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' show ClientException;
import 'package:logging/logging.dart';

import 'finamp_settings_helper.dart';
import 'jellyfin_api_helper.dart';

class ClientCertificateInstaller {
  static final isSupported = Platform.isAndroid;

  static final _logger = Logger('ClientCertificateInstaller');
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/client_certificate');

  static const _certificateRequiredAlert = "TLSV1_ALERT_CERTIFICATE_REQUIRED";

  /// OsError codes for EPIPE and ECONNRESET on Linux and macOS, and WSAECONNABORTED and WSAECONNRESET on Windows
  static const _writeFailureCodes = {32, 54, 104, 10053, 10054};

  /// Checks whether [error], thrown while connecting to [serverUrl],
  /// indicates that the server requires an mTLS client certificate.
  ///
  /// In the best case, the server's CERTIFICATE_REQUIRED alert shows up in the error message.
  ///
  /// However, with TLS 1.3, the client may already have started writing the HTTP request,
  /// which may fail first and mask the certificate error by a broken pipe.
  /// Older TLS 1.2 servers don't report a dedicated alert and just abort the handshake instead.
  ///
  /// In those unspecific cases, we probe the server for certificate errors without writing any data,
  /// in which case the issue should be reported cleanly.
  static Future<bool> isCertificateRequiredError(Object error, Uri serverUrl) async {
    if (error is ClientException && error.message.contains(_certificateRequiredAlert)) {
      return true;
    }
    if (error is TlsException && (error.osError?.message ?? error.message).contains(_certificateRequiredAlert)) {
      return true;
    }
    // Actual SocketExceptions only occur before a (HTTP) request is in flight (connection refused, DNS failures, ...),
    // so we can filter by errno here and skip probing servers that are simply unreachable.
    if (error is SocketException) {
      return _writeFailureCodes.contains(error.osError?.errorCode) && await _probeCertificateRequired(serverUrl);
    }
    if (error is TlsException || error is ClientException || error is HttpException) {
      return _probeCertificateRequired(serverUrl);
    }
    return false;
  }

  /// Connects to [url] and checks for the server's TLS alert without sending a request,
  /// so the "certificate required" alert can't be masked by a failed write.
  static Future<bool> _probeCertificateRequired(Uri url) async {
    if (url.scheme != "https") {
      return false;
    }
    Socket? socket;
    try {
      socket = await SecureSocket.connect(
        url.host,
        url.port,
        // Accepting any server certificate is fine here, no data is sent over the connection
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 3),
      );
      await socket.drain<void>().timeout(const Duration(seconds: 3));
    } on TlsException catch (e) {
      return (e.osError?.message ?? e.message).contains(_certificateRequiredAlert);
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
    return false;
  }

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
