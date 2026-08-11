import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/music_finder_models.dart';

/// HTTP client for a self-hosted Music Finder service (non-Jellyfin).
class MusicFinderClient {
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
    } catch (_) {
      // Timeouts, DNS, TLS, socket, format — treat as unreachable.
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
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      final httpResponse =
          await request.close().timeout(const Duration(seconds: 15));
      final text = await httpResponse.transform(utf8.decoder).join();
      Map<String, dynamic> json = {};
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      }
      return _JsonResponse(statusCode: httpResponse.statusCode, json: json);
    } finally {
      client.close(force: true);
    }
  }

  Future<_JsonResponse> _postJson(
    String baseUrl,
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _apiUri(baseUrl, path);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType =
          ContentType("application", "json", charset: "utf-8");
      request.add(utf8.encode(jsonEncode(body)));
      final httpResponse =
          await request.close().timeout(const Duration(seconds: 60));
      final text = await httpResponse.transform(utf8.decoder).join();
      Map<String, dynamic> json = {};
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        } else if (decoded is Map) {
          json = Map<String, dynamic>.from(decoded);
        }
      }
      return _JsonResponse(statusCode: httpResponse.statusCode, json: json);
    } on FormatException catch (e) {
      throw MusicFinderException("Invalid JSON response: $e");
    } finally {
      client.close(force: true);
    }
  }
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.json});

  final int statusCode;
  final Map<String, dynamic> json;
}
