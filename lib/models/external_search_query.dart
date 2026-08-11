/// Criteria for the external (non-Jellyfin) catalog search.
///
/// A future HTTP client on a separate server will consume these fields.
class ExternalSearchQuery {
  const ExternalSearchQuery({
    this.song,
    this.artist,
    this.album,
  });

  final String? song;
  final String? artist;
  final String? album;

  bool get hasAnyCriteria {
    return (song?.isNotEmpty ?? false) ||
        (artist?.isNotEmpty ?? false) ||
        (album?.isNotEmpty ?? false);
  }

  /// Human-readable summary of non-empty fields for snackbars / logging.
  String toCriteriaSummary({
    required String songLabel,
    required String artistLabel,
    required String albumLabel,
  }) {
    final parts = <String>[];
    if (song != null && song!.isNotEmpty) {
      parts.add('$songLabel: $song');
    }
    if (artist != null && artist!.isNotEmpty) {
      parts.add('$artistLabel: $artist');
    }
    if (album != null && album!.isNotEmpty) {
      parts.add('$albumLabel: $album');
    }
    return parts.join(', ');
  }
}
