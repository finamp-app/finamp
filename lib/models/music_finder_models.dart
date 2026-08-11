/// DTOs for the external Music Finder HTTP API.

class MusicFinderArtistOption {
  const MusicFinderArtistOption({
    required this.id,
    required this.name,
    required this.score,
    required this.source,
    this.disambiguation = "",
  });

  final String id;
  final String name;
  final double score;
  final String source;
  final String disambiguation;

  factory MusicFinderArtistOption.fromJson(Map<String, dynamic> json) {
    return MusicFinderArtistOption(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      score: (json["score"] as num?)?.toDouble() ?? 0.0,
      source: json["source"]?.toString() ?? "",
      disambiguation: json["disambiguation"]?.toString() ?? "",
    );
  }
}

class MusicFinderOwnedHit {
  const MusicFinderOwnedHit({
    this.artist = "",
    this.title = "",
    this.album = "",
    this.score = 0.0,
  });

  final String artist;
  final String title;
  final String album;
  final double score;

  factory MusicFinderOwnedHit.fromJson(Map<String, dynamic> json) {
    return MusicFinderOwnedHit(
      artist: json["artist"]?.toString() ?? "",
      title: json["title"]?.toString() ?? "",
      album: json["album"]?.toString() ?? "",
      score: (json["score"] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MusicFinderIdentity {
  const MusicFinderIdentity({
    required this.status,
    this.warnings = const [],
    this.owned,
    this.selected,
    this.artists = const [],
    this.recordingTitle = "",
  });

  final String status;
  final List<String> warnings;
  final MusicFinderOwnedHit? owned;
  final MusicFinderArtistOption? selected;
  final List<MusicFinderArtistOption> artists;
  final String recordingTitle;

  factory MusicFinderIdentity.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MusicFinderIdentity(status: "");
    }
    final artistsRaw = json["artists"] as List? ?? const [];
    return MusicFinderIdentity(
      status: json["status"]?.toString() ?? "",
      warnings: (json["warnings"] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      owned: json["owned"] is Map<String, dynamic>
          ? MusicFinderOwnedHit.fromJson(json["owned"] as Map<String, dynamic>)
          : null,
      selected: json["selected"] is Map<String, dynamic>
          ? MusicFinderArtistOption.fromJson(
              json["selected"] as Map<String, dynamic>)
          : null,
      artists: artistsRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) =>
              MusicFinderArtistOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      recordingTitle: json["recording_title"]?.toString() ?? "",
    );
  }
}

class MusicFinderCandidate {
  const MusicFinderCandidate({
    required this.title,
    required this.url,
    this.score = 0.0,
  });

  final String title;
  /// Magnet link (`magnet:…`) or other URL used when adding to the library.
  final String url;
  final double score;

  factory MusicFinderCandidate.fromJson(Map<String, dynamic> json) {
    return MusicFinderCandidate(
      title: json["title"]?.toString() ?? "",
      url: _urlFromJson(json),
      score: (json["score"] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Prefer `url`; accept legacy wire fields so older Music Finder builds work.
String _urlFromJson(Map<String, dynamic> json) {
  for (final key in ["url", "magnet", "id"]) {
    final value = json[key]?.toString() ?? "";
    if (value.isNotEmpty) {
      return value;
    }
  }
  return "";
}

class MusicFinderSearchResult {
  const MusicFinderSearchResult({
    required this.status,
    this.song = "",
    this.artist = "",
    this.album = "",
    this.query = "",
    this.warnings = const [],
    this.identity,
    this.candidates = const [],
  });

  final String status;
  final String song;
  final String artist;
  final String album;
  final String query;
  final List<String> warnings;
  final MusicFinderIdentity? identity;
  final List<MusicFinderCandidate> candidates;

  bool get needsArtistChoice => status == "need_artist_choice";
  bool get alreadyOwned => status == "already_owned";

  factory MusicFinderSearchResult.fromJson(Map<String, dynamic> json) {
    final candidatesRaw = json["candidates"] as List? ?? const [];
    return MusicFinderSearchResult(
      status: json["status"]?.toString() ?? "",
      song: json["song"]?.toString() ?? "",
      artist: json["artist"]?.toString() ?? "",
      album: json["album"]?.toString() ?? "",
      query: json["query"]?.toString() ?? "",
      warnings: (json["warnings"] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      identity: json["identity"] is Map<String, dynamic>
          ? MusicFinderIdentity.fromJson(
              json["identity"] as Map<String, dynamic>)
          : MusicFinderIdentity.fromJson(null),
      candidates: candidatesRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) =>
              MusicFinderCandidate.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MusicFinderAddItemResult {
  const MusicFinderAddItemResult({
    required this.url,
    required this.ok,
    this.detail = "",
  });

  final String url;
  final bool ok;
  final String detail;

  factory MusicFinderAddItemResult.fromJson(Map<String, dynamic> json) {
    return MusicFinderAddItemResult(
      url: _urlFromJson(json),
      ok: json["ok"] == true,
      detail: json["detail"]?.toString() ?? "",
    );
  }
}

class MusicFinderAddResult {
  const MusicFinderAddResult({
    required this.status,
    this.results = const [],
  });

  final String status;
  final List<MusicFinderAddItemResult> results;

  factory MusicFinderAddResult.fromJson(Map<String, dynamic> json) {
    final resultsRaw = json["results"] as List? ?? const [];
    return MusicFinderAddResult(
      status: json["status"]?.toString() ?? "",
      results: resultsRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) =>
              MusicFinderAddItemResult.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MusicFinderException implements Exception {
  MusicFinderException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
