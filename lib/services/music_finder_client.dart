import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/music_finder_models.dart';
import 'finamp_http_client.dart';

/// HTTP client for a self-hosted Music Finder service (non-Jellyfin).
///
/// Uses [FinampHttpClient] so MagicDNS hosts (`*.ts.net`) go through embedded
/// Tailscale when it is Running.
class MusicFinderClient {
  MusicFinderClient({http.Client? client})
    : _client = client ?? FinampHttpClient();

  final http.Client _client;
  final _log = Logger('MusicFinderClient');

  Uri _apiUri(String baseUrl, String path) {
    final root = baseUrl.endsWith("/")
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse("$root$path");
  }

  /// Returns true when `GET {baseUrl}/api/health` returns HTTP 200.
  Future<bool> checkConnection(String baseUrl) async {
    try {
      final response = await _getJson(baseUrl, "/api/health");
      return response.statusCode == 200;
    } catch (e) {
      _log.warning('Music Finder health check failed: $e');
      return false;
    }
  }

  Future<MusicFinderSearchResult> search({
    required String baseUrl,
    String song = "",
    String artist = "",
    String album = "",
    String? artistId,
  }) async {
    final body = <String, dynamic>{
      "song": song,
      "artist": artist,
      "album": album,
      if (artistId != null && artistId.isNotEmpty) "artist_id": artistId,
    };
    final response = await _postJson(baseUrl, "/api/v1/search", body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicFinderException(
        "Search failed (HTTP ${response.statusCode})",
        statusCode: response.statusCode,
      );
    }
    return MusicFinderSearchResult.fromJson(response.json);
  }

  Future<MusicFinderAddResult> addItems({
    required String baseUrl,
    required List<String> urls,
  }) async {
    final response = await _postJson(baseUrl, "/api/v1/add", {
      "urls": urls,
      // Legacy field name for Music Finder builds that predate `urls`.
      "magnets": urls,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicFinderException(
        "Add failed (HTTP ${response.statusCode})",
        statusCode: response.statusCode,
      );
    }
    return MusicFinderAddResult.fromJson(response.json);
  }

  Future<_JsonResponse> _getJson(String baseUrl, String path) async {
    final uri = _apiUri(baseUrl, path);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  Future<_JsonResponse> _postJson(
    String baseUrl,
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _apiUri(baseUrl, path);
    try {
      final response = await _client
          .post(
            uri,
            headers: const {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
      return _parse(response);
    } on FormatException catch (e) {
      throw MusicFinderException("Invalid JSON response: $e");
    }
  }

  _JsonResponse _parse(http.Response response) {
    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      } else if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
      }
    }
    return _JsonResponse(statusCode: response.statusCode, json: json);
  }
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.json});

  final int statusCode;
  final Map<String, dynamic> json;
}
