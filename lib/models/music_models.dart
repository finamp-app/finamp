import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../components/MusicScreen/sort_and_filter_row.dart';
import 'jellyfin_models.dart';

// Interfaces are in a separate file, but must be included in this library so that the sealed classes work
part 'music_interfaces.dart';

//
//
//   Concrete instances
//
//

class Track extends FinampPlayableDto {
  Track(super.item, {super.source}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.track) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  factory Track.fromItem(BaseItemDto item) => Track(item, source: QueueItemSource.fromBaseItem(item));

  @override
  bool equalsHelper(Object other) {
    return other is Track;
  }

  @override
  int get hashHelper => (Track as Object).hashCode;
}

class Album extends FinampPlayableDto implements FinampUnpagedPlayable<Track> {
  Album(super.item, {super.source}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.album) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  factory Album.fromItem(BaseItemDto item) => Album(item, source: QueueItemSource.fromBaseItem(item));

  @override
  bool equalsHelper(Object other) => other is Album;

  @override
  int get hashHelper => (Album as Object).hashCode;
}

class Playlist extends _SortableItem<Track> {
  Playlist(super.item, {super.source, required super.sortConfig}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.playlist) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  factory Playlist.fromItem(BaseItemDto item) =>
      Playlist(item, source: QueueItemSource.fromBaseItem(item), sortConfig: ResolvedSortConfig.defaultInAlbumSort);

  @override
  bool equalsHelper(Object other) => other is Playlist;

  @override
  int get hashHelper => (Playlist as Object).hashCode;

  @override
  Playlist copyWith(ResolvedSortConfig newSort) => Playlist(item, source: source, sortConfig: newSort);
}

// TODO add shuffle grouping control?

class MusicScreenPlayable<ChildType extends FinampPlayableDto> extends _SortablePagedPlayable<ChildType> {
  final ContentType tab;
  final LibraryId library;

  MusicScreenPlayable._({required this.tab, required this.library, required super.source, required super.sortConfig}) {
    switch (tab) {
      case ContentType.albums:
        assert(ChildType == Album);
      case ContentType.playlists:
        assert(ChildType == Playlist);
      case ContentType.genres:
        assert(ChildType == Genre);
      case ContentType.performingArtists:
      case ContentType.albumArtists:
        assert(ChildType == Artist);
      case ContentType.tracks:
        assert(ChildType == Track);
      case ContentType.home:
      case ContentType.genericArtists:
      case ContentType.inPlaylist:
      case ContentType.mixed:
      case ContentType.inPerformingArtistAlbums:
      case ContentType.inAlbumArtistAlbums:
        throw UnsupportedError("Invalid content type $tab for music screen tab.");
    }
  }

  factory MusicScreenPlayable({
    required ContentType tab,
    required LibraryId library,
    required QueueItemSource source,
    required ResolvedSortConfig sortConfig,
  }) {
    assert(() {
      final controller = SortAndFilterController(startingConfig: sortConfig, contentType: tab);
      final resolvedConfig = GetIt.instance<ProviderContainer>().read(resolveSortProvider(controller));
      return sortConfig == resolvedConfig;
    }());
    switch (tab) {
      case ContentType.albums:
        return MusicScreenPlayable<Album>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.playlists:
        return MusicScreenPlayable<Playlist>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.performingArtists:
      case ContentType.albumArtists:
        return MusicScreenPlayable<Artist>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.genres:
        return MusicScreenPlayable<Genre>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.tracks:
        return MusicScreenPlayable<Track>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.inPlaylist:
      case ContentType.genericArtists:
      case ContentType.home:
      case ContentType.mixed:
      case ContentType.inPerformingArtistAlbums:
      case ContentType.inAlbumArtistAlbums:
        throw UnsupportedError("Invalid content type $tab for music screen tab.");
    }
  }

  FinampPlayableDto buildChild(BaseItemDto item) {
    switch (tab) {
      case ContentType.tracks:
        return Track.fromItem(item);
      case ContentType.albums:
        return Album.fromItem(item);
      case ContentType.playlists:
        return Playlist.fromItem(item);
      case ContentType.genres:
        return Genre.fromItem(item);
      case ContentType.performingArtists:
        return Artist.fromItem(item);
      case ContentType.albumArtists:
        return Artist.fromItem(item);
      case ContentType.home:
      case ContentType.genericArtists:
      case ContentType.inPlaylist:
      case ContentType.mixed:
      case ContentType.inPerformingArtistAlbums:
      case ContentType.inAlbumArtistAlbums:
        throw UnsupportedError("Invalid content type $tab for music screen tab.");
    }
  }

  int get normalChildSize => switch (tab) {
    ContentType.albums => 10,
    ContentType.playlists => 20,
    ContentType.genres => 30,
    ContentType.tracks => 1,
    ContentType.performingArtists => 30,
    ContentType.albumArtists => 3,
    ContentType.home ||
    ContentType.genericArtists ||
    ContentType.inPlaylist ||
    ContentType.inAlbumArtistAlbums ||
    ContentType.inPerformingArtistAlbums ||
    ContentType.mixed => throw UnsupportedError("Invalid music screen content type $tab"),
  };

  @override
  bool equalsHelper(Object other) => other is MusicScreenPlayable && tab == other.tab && library == other.library;

  @override
  int get hashHelper => Object.hash(tab, library);

  @override
  String get id => "finamp-music-screen-$hashCode";

  @override
  MusicScreenPlayable<ChildType> copyWith(ResolvedSortConfig newSort) =>
      MusicScreenPlayable._(tab: tab, library: library, source: source, sortConfig: newSort);
}

// TODO do we need this to have an item?  Or can it be a generic prebaked section?
class AlbumDisc extends FinampPlayableDto implements FinampUnpagedPlayable<Track> {
  AlbumDisc(super.item, {required this.tracks})
    : assert(
        tracks.every((e) {
          return e.parentIndexNumber == tracks.first.parentIndexNumber;
        }),
      ),
      assert(
        tracks.every((e) {
          return e.albumId == item.id;
        }),
      ),
      // TODO disc-specific source?
      super(source: QueueItemSource.fromBaseItem(item));
  final List<BaseItemDto> tracks;

  @override
  bool equalsHelper(Object other) => other is AlbumDisc && listEquals(tracks, other.tracks);

  @override
  int get hashHelper => Object.hashAll(tracks);
}

class PrecalculatedPlayable extends FinampUnpagedPlayable<Track> {
  const PrecalculatedPlayable({required super.source, required this.tracks});
  final List<BaseItemDto> tracks;

  @override
  String get id => "finamp-music-screen-${source.hashCode}";

  @override
  bool equalsHelper(Object other) => other is PrecalculatedPlayable && listEquals(tracks, other.tracks);

  @override
  int get hashHelper => Object.hashAll(tracks);
}

// TODO get rid of this once we have all the real types.
/*class GenericPlayableItem extends _SortableItem<Track> {
  GenericPlayableItem(super.item, {ResolvedSortConfig? sortConfig})
    : super(source: QueueItemSource.fromBaseItem(item), sortConfig: sortConfig ?? ResolvedSortConfig.defaultSort);

  factory GenericPlayableItem.defaultSort(BaseItemDto item) =>
      GenericPlayableItem(item, sortConfig: ResolvedSortConfig.defaultInAlbumSort);

  @override
  bool equalsHelper(Object other) => other is GenericPlayableItem;

  @override
  int get hashHelper => (GenericPlayableItem as Object).hashCode;

  @override
  GenericPlayableItem copyWith(ResolvedSortConfig newSort) => GenericPlayableItem(item, sortConfig: newSort);
}*/

class LatestQueues extends FinampSortable<PlayableQueue> implements FinampUnpagedDisplayable<PlayableQueue> {
  LatestQueues({required super.sortConfig, required super.source});

  @override
  bool equalsHelper(Object other) {
    return other is LatestQueues;
  }

  @override
  int get hashHelper => (LatestQueues as Object).hashCode;

  @override
  String get id => "latest-queues";

  @override
  LatestQueues copyWith(ResolvedSortConfig newSort) => LatestQueues(sortConfig: newSort, source: source);
}

class PlayableQueue extends FinampPlayable {
  // Presumably, if we load a queue we use the original sources, so this doesn't really matter?
  PlayableQueue({required this.queue, required super.source});

  final FinampStorableQueueInfo queue;

  @override
  bool equalsHelper(Object other) {
    // Only identical() queues are equal.  That's probably fine?
    return other is PlayableQueue && other.queue == queue;
  }

  @override
  int get hashHelper => Object.hash(PlayableQueue, queue);

  @override
  String get id => "latest-queues";
}

class InstantMix extends FinampPlayableDto {
  InstantMix(super.item)
    : super(
        source: QueueItemSource(
          type: switch (BaseItemDtoType.fromItem(item)) {
            BaseItemDtoType.track => QueueItemSourceType.trackMix,
            BaseItemDtoType.album => QueueItemSourceType.albumMix,
            BaseItemDtoType.artist => QueueItemSourceType.artistMix,
            BaseItemDtoType.genre => QueueItemSourceType.genreMix,
            _ => QueueItemSourceType.unknown,
          },
          name: QueueItemSourceName(
            type: item.name != null ? QueueItemSourceNameType.mix : QueueItemSourceNameType.instantMix,
            localizationParameter: item.name ?? "",
          ),
          id: item.id,
          item: item,
        ),
      );

  @override
  bool equalsHelper(Object other) {
    return other is InstantMix;
  }

  @override
  int get hashHelper => (InstantMix as Object).hashCode;
}

class JellyfinCollection extends _SortableItem<FinampPlayableDto> {
  JellyfinCollection(super.item, {super.source, required super.sortConfig}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.collection) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  factory JellyfinCollection.fromItem(BaseItemDto item) =>
      JellyfinCollection(item, source: QueueItemSource.fromBaseItem(item), sortConfig: ResolvedSortConfig.defaultSort);

  @override
  bool equalsHelper(Object other) => other is JellyfinCollection;

  @override
  int get hashHelper => (JellyfinCollection as Object).hashCode;

  @override
  JellyfinCollection copyWith(ResolvedSortConfig newSort) =>
      JellyfinCollection(item, source: source, sortConfig: newSort);
}

class Artist<ChildType extends FinampPlayableDto> extends _SortableItem<ChildType> {
  Artist._(super.item, {super.source, required super.sortConfig, required this.type, required this.library}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.artist) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  final ArtistChildType type;
  final LibraryId library;

  factory Artist(
    BaseItemDto item, {
    QueueItemSource? source,
    required ResolvedSortConfig sortConfig,
    required ArtistChildType type,
    required LibraryId library,
  }) {
    switch (type) {
      case ArtistChildType.albumsFromArtist || ArtistChildType.appearsOnAlbums:
        return Artist<Album>._(item, source: source, sortConfig: sortConfig, type: type, library: library)
            as Artist<ChildType>;
      case ArtistChildType.tracks:
        return Artist<Track>._(item, source: source, sortConfig: sortConfig, type: type, library: library)
            as Artist<ChildType>;
    }
  }

  factory Artist.fromItem(BaseItemDto item) => Artist(
    item,
    source: QueueItemSource.fromBaseItem(item),
    sortConfig: ResolvedSortConfig.defaultSort,
    type: ArtistChildType.tracks,
    // TODO should this resolve current library on creation?
    library: currentLibraryPlaceholder,
  );

  @override
  bool equalsHelper(Object other) => other is Artist && type == other.type && other.library == library;

  @override
  int get hashHelper => Object.hash(Artist, type, library);

  @override
  Artist copyWith(ResolvedSortConfig newSort) =>
      Artist(item, source: source, sortConfig: newSort, type: type, library: library);
}

enum ArtistChildType {
  tracks,
  albumsFromArtist,
  appearsOnAlbums;

  factory ArtistChildType.fromContentType(ContentType type) => switch (type) {
    ContentType.tracks => ArtistChildType.tracks,
    ContentType.inPerformingArtistAlbums => ArtistChildType.appearsOnAlbums,
    ContentType.inAlbumArtistAlbums => ArtistChildType.albumsFromArtist,
    _ => throw UnsupportedError("Invalid artist content type $type"),
  };
}

class Genre<ChildType extends FinampPlayableDto> extends _SortableItem<ChildType> {
  Genre._(super.item, {super.source, required super.sortConfig, required this.type, required this.library}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.genre) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  final GenreChildType type;
  final LibraryId library;

  factory Genre(
    BaseItemDto item, {
    QueueItemSource? source,
    required ResolvedSortConfig sortConfig,
    required GenreChildType type,
    required LibraryId library,
  }) {
    switch (type) {
      case GenreChildType.tracks:
        return Genre<Track>._(item, source: source, sortConfig: sortConfig, type: type, library: library)
            as Genre<ChildType>;
      case GenreChildType.artists:
        return Genre<Artist>._(item, source: source, sortConfig: sortConfig, type: type, library: library)
            as Genre<ChildType>;
      case GenreChildType.albums:
        return Genre<Album>._(item, source: source, sortConfig: sortConfig, type: type, library: library)
            as Genre<ChildType>;
      case GenreChildType.playlists:
        return Genre<Playlist>._(item, source: source, sortConfig: sortConfig, type: type, library: library)
            as Genre<ChildType>;
    }
  }

  factory Genre.fromItem(BaseItemDto item) => Genre(
    item,
    source: QueueItemSource.fromBaseItem(item),
    sortConfig: ResolvedSortConfig.defaultSort,
    type: GenreChildType.tracks,
    library: currentLibraryPlaceholder,
  );

  @override
  bool equalsHelper(Object other) => other is Genre && type == other.type && other.library == library;

  @override
  int get hashHelper => Object.hash(Genre, type, library);

  @override
  Genre copyWith(ResolvedSortConfig newSort) =>
      Genre(item, source: source, sortConfig: newSort, type: type, library: library);
}

enum GenreChildType {
  tracks,
  albums,
  artists,
  playlists;

  factory GenreChildType.fromContentType(ContentType type) => switch (type) {
    ContentType.tracks => GenreChildType.tracks,
    ContentType.playlists => GenreChildType.playlists,
    ContentType.genericArtists => GenreChildType.artists,
    ContentType.albums => GenreChildType.albums,
    _ => throw UnsupportedError("Invalid genre content type $type"),
  };
}
