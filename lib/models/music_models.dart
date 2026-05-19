import 'dart:math';

import 'package:finamp/extensions/list.dart';
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
  Track(super.item, {required super.source}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.track) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  @override
  bool equalsHelper(Object other) {
    return other is Track && equalsHelperChain(other);
  }

  @override
  int get hashHelper => Object.hash(Track, hashHelperChain);
}

class Album extends FinampPlayableDto implements FinampUnpagedPlayable<Track> {
  Album(super.item, {required super.source}) {
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
  Playlist(super.item, {required super.source, required super.sortConfig}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.playlist) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  factory Playlist.fromItem(BaseItemDto item, {SortAndFilterConfiguration? sortConfig}) => Playlist(
    item,
    source: QueueItemSource.fromBaseItem(item),
    sortConfig: sortConfig ?? SortAndFilterConfiguration.defaultInAlbumSort,
  );

  @override
  bool equalsHelper(Object other) => other is Playlist;

  @override
  int get hashHelper => (Playlist as Object).hashCode;

  @override
  Playlist copyWith(SortAndFilterConfiguration newSort) => Playlist(item, source: source, sortConfig: newSort);
}

// TODO add shuffle grouping control?

class MusicScreenPlayable<ChildType extends FinampPlayableDto> extends _SortablePagedPlayable<ChildType> {
  final ContentType tab;
  final LibraryOrItemId library;

  MusicScreenPlayable._({required this.tab, required this.library, required super.source, required super.sortConfig}) {
    assert(() {
      final controller = SortAndFilterController(startingConfig: sortConfig, contentType: tab);
      final resolvedConfig = GetIt.instance<ProviderContainer>().read(resolveSortProvider(controller));
      return sortConfig == resolvedConfig;
    }());
    switch (tab) {
      case ContentType.albums:
        assert(ChildType == Album);
      case ContentType.playlists:
        assert(ChildType == Playlist);
      case ContentType.genres:
      case ContentType.performingArtists:
      case ContentType.albumArtists:
        assert(ChildType == GenericPlayableItem);
      case ContentType.tracks:
        assert(ChildType == Track);
      case ContentType.home:
      case ContentType.genericArtists:
      case ContentType.inPlaylist:
      case ContentType.mixed:
        throw UnsupportedError("Invalid content type $tab for music screen tab.");
    }
  }

  factory MusicScreenPlayable({
    required ContentType tab,
    required LibraryOrItemId library,
    required QueueItemSource source,
    required SortAndFilterConfiguration sortConfig,
  }) {
    switch (tab) {
      case ContentType.albums:
        return MusicScreenPlayable<Album>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.playlists:
        return MusicScreenPlayable<Playlist>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.performingArtists:
      case ContentType.albumArtists:
      case ContentType.genres:
        return MusicScreenPlayable<GenericPlayableItem>._(
              tab: tab,
              library: library,
              source: source,
              sortConfig: sortConfig,
            )
            as MusicScreenPlayable<ChildType>;
      case ContentType.tracks:
        return MusicScreenPlayable<Track>._(tab: tab, library: library, source: source, sortConfig: sortConfig)
            as MusicScreenPlayable<ChildType>;
      case ContentType.inPlaylist:
      case ContentType.genericArtists:
      case ContentType.home:
      case ContentType.mixed:
        throw UnsupportedError("Invalid content type $tab for music screen tab.");
    }
  }

  FinampPlayableDto buildChild(BaseItemDto item) {
    switch (tab) {
      case ContentType.tracks:
        return Track(item, source: source);
      case ContentType.albums:
        return Album(item, source: source);
      case ContentType.playlists:
        return Playlist(item, source: source, sortConfig: sortConfig);
      case ContentType.genres:
      case ContentType.performingArtists:
      case ContentType.albumArtists:
        // TODO return real item types
        return GenericPlayableItem(item, sortConfig: sortConfig);
      case ContentType.home:
      case ContentType.genericArtists:
      case ContentType.inPlaylist:
      case ContentType.mixed:
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
    ContentType.home => throw UnimplementedError(),
    ContentType.genericArtists => throw UnimplementedError(),
    ContentType.inPlaylist => throw UnimplementedError(),
    ContentType.mixed => throw UnimplementedError(),
  };

  @override
  bool equalsHelper(Object other) =>
      other is MusicScreenPlayable && tab == other.tab && library == other.library && equalsHelperChain(other);

  @override
  int get hashHelper => Object.hash(tab, library, hashHelperChain);

  @override
  String get id => "finamp-music-screen-$hashCode";

  @override
  MusicScreenPlayable<ChildType> copyWith(SortAndFilterConfiguration newSort) =>
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
class GenericPlayableItem extends _SortableItem<Track> {
  GenericPlayableItem(super.item, {SortAndFilterConfiguration? sortConfig})
    : super(
        source: QueueItemSource.fromBaseItem(item),
        sortConfig: sortConfig ?? SortAndFilterConfiguration.defaultSort,
      );

  factory GenericPlayableItem.defaultSort(BaseItemDto item) =>
      GenericPlayableItem(item, sortConfig: SortAndFilterConfiguration.defaultInAlbumSort);

  @override
  bool equalsHelper(Object other) => other is Playlist;

  @override
  int get hashHelper => (Playlist as Object).hashCode;

  @override
  GenericPlayableItem copyWith(SortAndFilterConfiguration newSort) => GenericPlayableItem(item, sortConfig: newSort);
}

class LatestQueues extends FinampSortable<PlayableQueue> implements FinampUnpagedDisplayable<PlayableQueue> {
  LatestQueues({required super.sortConfig, required super.source});

  @override
  bool equalsHelper(Object other) {
    return other is LatestQueues && equalsHelperChain(other);
  }

  @override
  int get hashHelper => Object.hash(LatestQueues, hashHelperChain);

  @override
  String get id => "latest-queues";

  @override
  LatestQueues copyWith(SortAndFilterConfiguration newSort) => LatestQueues(sortConfig: newSort, source: source);
}

class PlayableQueue extends FinampPlayable {
  PlayableQueue({required this.queue, required super.source});

  final FinampStorableQueueInfo queue;

  @override
  bool equalsHelper(Object other) {
    // Only identical() queues are equal.  That's probably fine?
    return other is PlayableQueue && other.queue == queue && equalsHelperChain(other);
  }

  @override
  int get hashHelper => Object.hash(PlayableQueue, queue, hashHelperChain);

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
    return other is InstantMix && equalsHelperChain(other);
  }

  @override
  int get hashHelper => Object.hash(InstantMix, hashHelperChain);
}

class JellyfinCollection extends _SortableItem<FinampPlayableDto> {
  JellyfinCollection(super.item, {required super.source, required super.sortConfig}) {
    if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.collection) {
      throw UnsupportedError("Wrong BaseItemDto type: ${item.type}");
    }
  }

  factory JellyfinCollection.fromItem(BaseItemDto item, {SortAndFilterConfiguration? sortConfig}) => JellyfinCollection(
    item,
    source: QueueItemSource.fromBaseItem(item),
    sortConfig: sortConfig ?? SortAndFilterConfiguration.defaultSort,
  );

  @override
  bool equalsHelper(Object other) => other is JellyfinCollection;

  @override
  int get hashHelper => (JellyfinCollection as Object).hashCode;

  @override
  JellyfinCollection copyWith(SortAndFilterConfiguration newSort) =>
      JellyfinCollection(item, source: source, sortConfig: newSort);
}
