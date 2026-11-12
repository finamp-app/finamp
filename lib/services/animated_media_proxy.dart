import 'dart:io';

import 'package:logging/logging.dart';

final _proxyLogger = Logger("AnimatedMediaProxy");

class _ProxyTarget {
  const _ProxyTarget({required this.upstream, required this.headers});

  final Uri upstream;
  final Map<String, String> headers;
}

class ProxiedMedia {
  const ProxiedMedia({required this.id, required this.uri});

  final String id;
  final Uri uri;
}

class AnimatedMediaProxy {
  AnimatedMediaProxy._();

  static final instance = AnimatedMediaProxy._();

  final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30)
    ..autoUncompress = false;

  final _targets = <String, _ProxyTarget>{};
  HttpServer? _server;
  int _nextId = 0;

  Future<ProxiedMedia> register({
    required Uri upstream,
    required Map<String, String> headers,
    required String fileName,
  }) async {
    final server = await _ensureServer();
    final id = '${_nextId++}';
    _targets[id] = _ProxyTarget(upstream: upstream, headers: headers);
    var name = fileName.replaceAll(RegExp(r'[/\\]'), '_');
    if (name.isEmpty) {
      name = 'video.mp4';
    } else if (!name.contains('.')) {
      name = '$name.mp4';
    }
    return ProxiedMedia(
      id: id,
      uri: Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: '/$id/$name'),
    );
  }

  void unregister(String id) {
    _targets.remove(id);
  }

  Future<HttpServer> _ensureServer() async {
    final existing = _server;
    if (existing != null) {
      return existing;
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    final id = request.uri.pathSegments.firstOrNull;
    final target = id == null ? null : _targets[id];
    if (target == null || (request.method != 'GET' && request.method != 'HEAD')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    HttpClientRequest? upstream;
    try {
      upstream = await _client.openUrl(request.method, target.upstream);
      upstream.followRedirects = true;
      upstream.maxRedirects = 5;
      for (final entry in target.headers.entries) {
        upstream.headers.set(entry.key, entry.value);
      }
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        upstream.headers.set(HttpHeaders.rangeHeader, range);
      }
      upstream.headers.removeAll(HttpHeaders.acceptEncodingHeader);

      final response = await upstream.close();
      request.response.bufferOutput = false;
      request.response.statusCode = response.statusCode;
      response.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower == 'transfer-encoding' || lower == 'connection' || lower == 'keep-alive') {
          return;
        }
        request.response.headers.set(name, values);
      });
      if (request.method != 'HEAD') {
        await request.response.addStream(response);
      }
      await request.response.close();
    } catch (e, stack) {
      _proxyLogger.fine("Animated media proxy failed", e, stack);
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }
}
