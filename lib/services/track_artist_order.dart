import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';

/// A displayed credit can lack an artist ID when Jellyfin only provides a name.
class TrackArtistCredit {
  const TrackArtistCredit({required this.name, this.id});

  final String? name;
  final BaseItemId? id;
}

String _nameKey(String? name) => name?.trim().toLowerCase() ?? '';

/// Orders display credits without changing the server metadata or adding album
/// artists who are not credited on this track.
List<TrackArtistCredit> orderedTrackArtists(BaseItemDto item, TrackArtistOrder order) {
  final artistItems = item.artistItems ?? const <NameIdPair>[];
  final credits = <TrackArtistCredit>[];
  final seenIds = <BaseItemId>{};
  final seenNamesWithoutIds = <String>{};

  void addCredit(String? name, BaseItemId? id) {
    if (id != null) {
      if (!seenIds.add(id)) return;
    } else if (_nameKey(name).isEmpty || !seenNamesWithoutIds.add(_nameKey(name))) {
      return;
    }
    credits.add(TrackArtistCredit(name: name, id: id));
  }

  // Artists preserves the tag credit order, including artists not yet resolved
  // to IDs. ArtistItems supplies navigation IDs and a fallback for older data.
  for (final name in item.artists ?? const <String>[]) {
    if (_nameKey(name).isEmpty) continue;
    final matches = artistItems.where((artist) => _nameKey(artist.name) == _nameKey(name));
    addCredit(name, matches.firstOrNull?.id);
  }
  if (credits.isEmpty) {
    for (final artist in artistItems) {
      addCredit(artist.name, artist.id);
    }
  }

  if (order == TrackArtistOrder.metadata || credits.length < 2) return credits;

  int albumArtistIndex(TrackArtistCredit credit) {
    final albumArtists = item.albumArtists ?? const <NameIdPair>[];
    for (var index = 0; index < albumArtists.length; index++) {
      final albumArtist = albumArtists[index];
      if (credit.id != null ? credit.id == albumArtist.id : _nameKey(credit.name) == _nameKey(albumArtist.name)) {
        return index;
      }
    }
    // The scalar fallback is only useful when Jellyfin did not provide IDs.
    if (albumArtists.isEmpty &&
        _nameKey(item.albumArtist).isNotEmpty &&
        _nameKey(credit.name) == _nameKey(item.albumArtist)) {
      return 0;
    }
    return -1;
  }

  final albumIndices = credits.map(albumArtistIndex).toList();
  if (order == TrackArtistOrder.albumArtistsFirst && albumIndices.every((index) => index < 0)) {
    // A compilation's album artist (e.g. Various Artists) is not a song's lead.
    return credits;
  }

  final indexed = credits.indexed.toList();
  indexed.sort((left, right) {
    if (order == TrackArtistOrder.albumArtistsFirst) {
      final leftAlbum = albumIndices[left.$1];
      final rightAlbum = albumIndices[right.$1];
      if (leftAlbum >= 0 || rightAlbum >= 0) {
        if (leftAlbum < 0) return 1;
        if (rightAlbum < 0) return -1;
        final result = leftAlbum.compareTo(rightAlbum);
        if (result != 0) return result;
      }
    } else if (order == TrackArtistOrder.firstArtistFirst && (left.$1 == 0 || right.$1 == 0)) {
      return left.$1.compareTo(right.$1);
    }
    final leftName = _nameKey(left.$2.name);
    final rightName = _nameKey(right.$2.name);
    if (leftName.isEmpty != rightName.isEmpty) return leftName.isEmpty ? 1 : -1;
    final result = leftName.compareTo(rightName);
    return result != 0 ? result : left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList();
}

String? trackArtistNames(BaseItemDto item, TrackArtistOrder order) {
  final names = orderedTrackArtists(
    item,
    order,
  ).map((artist) => artist.name).whereType<String>().where((name) => name.trim().isNotEmpty);
  return names.isEmpty ? item.albumArtist : names.join(', ');
}

/// Update cached display strings while preserving queue IDs, source metadata,
/// audio sources and playback position.
void updateQueueArtistOrder(Iterable<FinampQueueItem> items, TrackArtistOrder order) {
  for (final item in items) {
    item.item = item.item.copyWith(artist: trackArtistNames(item.baseItem, order));
  }
}
