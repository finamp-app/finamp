import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A minimal HTTP proxy that serves media to DLNA renderers with the
/// correct DLNA content-feature headers.
///
/// Unlike general-purpose proxies, this adds `contentFeatures.dlna.org`
/// and `transferMode.dlna.org` headers to every response. Some DLNA
/// devices (notably Samsung TVs) refuse to honour Pause/Stop/Seek SOAP
/// actions unless these headers are present on the media stream.
///
/// Two registration modes:
/// - [registerFile] — serves a local file from the filesystem.
/// - [registerUrl] — proxies a remote URL (e.g. a Jellyfin direct-play URL),
///   forwarding Range requests and streaming the upstream response through.
class DlnaMediaProxy {
  HttpServer? _server;
  String? _baseUrl;
  final _routes = <String, _ProxyRoute>{};

  /// Starts the proxy, binding to the local IP on the same subnet as
  /// [targetDeviceIp] so the DLNA device can reach us.
  Future<void> start({String? targetDeviceIp}) async {
    if (_server != null) return;

    final ip = await _getLocalIp(targetDeviceIp);
    final bindAddress = ip ?? '0.0.0.0';
    _server = await HttpServer.bind(bindAddress, 0);
    // Clear default security headers that some DLNA renderers reject.
    _server!.defaultResponseHeaders.clear();
    final port = _server!.port;
    _baseUrl = 'http://${ip ?? bindAddress}:$port';
    _server!.listen(_handleRequest);
  }

  /// Stops the proxy and clears all registered routes.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _baseUrl = null;
    _routes.clear();
  }

  /// The base URL the DLNA device should use to reach this proxy.
  String? get baseUrl => _baseUrl;

  /// Registers a local file for serving. Returns a URL the DLNA device
  /// can fetch.
  String registerFile(String filePath, {required String mimeType}) {
    final token = _generateToken();
    final ext = _extForMime(mimeType);
    _routes['$token$ext'] = _ProxyRoute(type: _RouteType.file, path: filePath, mimeType: mimeType);
    return '$_baseUrl/file/$token$ext';
  }

  /// Registers a remote URL for proxying. Returns a URL the DLNA device
  /// can fetch.
  String registerUrl(String url, {required String mimeType}) {
    final token = _generateToken();
    final ext = _extForMime(mimeType);
    _routes['$token$ext'] = _ProxyRoute(type: _RouteType.remote, path: url, mimeType: mimeType);
    return '$_baseUrl/stream/$token$ext';
  }

  // ── HTTP handling ──────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      String token;
      if (path.startsWith('/file/')) {
        token = path.substring('/file/'.length);
        await _serveFile(request, token);
      } else if (path.startsWith('/stream/')) {
        token = path.substring('/stream/'.length);
        await _serveStream(request, token);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveFile(HttpRequest request, String token) async {
    final route = _routes[token];
    if (route == null || route.type != _RouteType.file) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final file = File(route.path);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final fileLength = await file.length();
    final rangeHeader = request.headers.value('Range');
    int start = 0, end = fileLength - 1;
    int statusCode = 200;
    String statusText = 'OK';

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final spec = rangeHeader.substring('bytes='.length);
      final parts = spec.split('-');
      if (parts[0].isEmpty) {
        final suffix = int.tryParse(parts[1]) ?? 0;
        start = (fileLength - suffix).clamp(0, fileLength - 1);
      } else {
        start = int.tryParse(parts[0]) ?? 0;
        if (parts[1].isNotEmpty) {
          end = (int.tryParse(parts[1]) ?? fileLength - 1).clamp(0, fileLength - 1);
        }
      }
      statusCode = 206;
      statusText = 'Partial Content';
    }

    if (start > end || start >= fileLength) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set('Content-Range', 'bytes */$fileLength');
      await request.response.close();
      return;
    }

    final length = end - start + 1;

    // Detach socket and write HTTP/1.0 response manually for maximum
    // DLNA compatibility — some renderers reject HTTP/1.1 from Dart's
    // HttpServer.
    final socket = await request.response.detachSocket(writeHeaders: false);
    try {
      final headers = StringBuffer()
        ..write('HTTP/1.0 $statusCode $statusText\r\n')
        ..write('Content-Type: ${route.mimeType}\r\n')
        ..write('Content-Length: $length\r\n')
        ..write('Accept-Ranges: bytes\r\n')
        ..write('transferMode.dlna.org: Streaming\r\n')
        ..write('contentFeatures.dlna.org: ${_contentFeatures(route.mimeType)}\r\n');
      if (statusCode == 206) {
        headers.write('Content-Range: bytes $start-$end/$fileLength\r\n');
      }
      headers.write('\r\n');
      socket.add(utf8.encode(headers.toString()));

      if (request.method != 'HEAD') {
        await file.openRead(start, end + 1).pipe(socket);
      }
    } finally {
      await socket.close();
    }
  }

  Future<void> _serveStream(HttpRequest request, String token) async {
    final route = _routes[token];
    if (route == null || route.type != _RouteType.remote) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final upstreamUri = Uri.parse(route.path);
    final httpClient = HttpClient();
    try {
      final upstreamReq = await httpClient.openUrl('GET', upstreamUri);
      final rangeHeader = request.headers.value('Range');
      if (rangeHeader != null) {
        upstreamReq.headers.set('Range', rangeHeader);
      }
      final upstreamResp = await upstreamReq.close();

      // Detach and write HTTP/1.0 response with DLNA headers.
      final socket = await request.response.detachSocket(writeHeaders: false);
      try {
        final statusCode = upstreamResp.statusCode;
        final statusText = upstreamResp.reasonPhrase;
        final contentLength = upstreamResp.headers.value('Content-Length');
        final contentRange = upstreamResp.headers.value('Content-Range');

        final headers = StringBuffer()
          ..write('HTTP/1.0 $statusCode $statusText\r\n')
          ..write('Content-Type: ${route.mimeType}\r\n');
        if (contentLength != null) {
          headers.write('Content-Length: $contentLength\r\n');
        }
        if (contentRange != null) {
          headers.write('Content-Range: $contentRange\r\n');
        }
        headers
          ..write('Accept-Ranges: bytes\r\n')
          ..write('transferMode.dlna.org: Streaming\r\n')
          ..write('contentFeatures.dlna.org: ${_contentFeatures(route.mimeType)}\r\n')
          ..write('\r\n');
        socket.add(utf8.encode(headers.toString()));

        if (request.method != 'HEAD') {
          await upstreamResp.pipe(socket);
        }
      } finally {
        await socket.close();
      }
    } finally {
      httpClient.close(force: true);
    }
  }

  // ── DLNA helpers ────────────────────────────────────────────────

  /// Build the `contentFeatures.dlna.org` header value for a MIME type.
  ///
  /// `DLNA.ORG_OP=01` advertises byte-range seek support.
  /// `DLNA.ORG_CI=0` means no transcoding/conversion.
  /// `DLNA.ORG_FLAGS=01700000...` is the standard streaming flag set.
  static const _dlnaFlags = '01700000000000000000000000000000';

  static String _contentFeatures(String mimeType) {
    final pn = _dlnaPn(mimeType);
    if (pn != null) {
      return '$pn;DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=$_dlnaFlags';
    }
    return 'DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=$_dlnaFlags';
  }

  /// Map a MIME type to its DLNA.ORG_PN profile name, if known.
  static String? _dlnaPn(String mimeType) {
    return switch (mimeType) {
      'audio/mpeg' => 'DLNA.ORG_PN=MP3',
      'audio/x-ms-wma' => 'DLNA.ORG_PN=WMABASE',
      'audio/vnd.dlna.adts' => 'DLNA.ORG_PN=AAC_ADTS',
      'audio/mp4' || 'audio/m4a' || 'audio/aac' => 'DLNA.ORG_PN=AAC_ISO',
      'audio/wav' || 'audio/x-wav' => 'DLNA.ORG_PN=LPCM',
      _ => null,
    };
  }

  /// Pick a file extension for a MIME type so the proxy URL ends with
  /// a recognisable extension (some DLNA devices rely on this).
  static String _extForMime(String mimeType) {
    return switch (mimeType) {
      'audio/mpeg' => '.mp3',
      'audio/flac' => '.flac',
      'audio/wav' || 'audio/x-wav' => '.wav',
      'audio/m4a' => '.m4a',
      'audio/aac' => '.aac',
      'audio/ogg' => '.ogg',
      'audio/x-ms-wma' => '.wma',
      'audio/ape' || 'audio/x-ape' => '.ape',
      'audio/ac3' => '.ac3',
      'audio/vnd.dlna.adts' => '.adts',
      _ => '',
    };
  }

  static String _generateToken() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
        (DateTime.now().millisecond % 1000).toRadixString(36);
  }

  /// Find the local IP on the same subnet as [targetDeviceIp].
  static Future<String?> _getLocalIp(String? targetDeviceIp) async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final addresses = <InternetAddress>[];
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback && !addr.isLinkLocal) {
          addresses.add(addr);
        }
      }
    }
    if (addresses.isEmpty) return null;

    if (targetDeviceIp != null) {
      final targetPrefix = _subnetPrefix(targetDeviceIp);
      if (targetPrefix != null) {
        for (final addr in addresses) {
          if (_subnetPrefix(addr.address) == targetPrefix) return addr.address;
        }
      }
    }

    // Prefer RFC 1918 private addresses.
    for (final addr in addresses) {
      if (_isPrivate(addr.address)) return addr.address;
    }
    return addresses.first.address;
  }

  static String? _subnetPrefix(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  static bool _isPrivate(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }
}

enum _RouteType { file, remote }

class _ProxyRoute {
  final _RouteType type;
  final String path; // file path or remote URL
  final String mimeType;

  const _ProxyRoute({required this.type, required this.path, required this.mimeType});
}
