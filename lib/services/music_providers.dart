import 'dart:math';

import 'package:collection/collection.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/extensions/list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../components/global_snackbar.dart';
import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import '../models/music_models.dart';
import 'album_screen_provider.dart';
import 'artist_content_provider.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'item_by_id_provider.dart';
import 'jellyfin_api_helper.dart';
import 'music_screen_provider.dart';

part 'music_providers.g.dart';

@riverpod
Future<List<BaseItemDto>> globalSearch(Ref ref, String searchTerm, {required bool includeTracks}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final baseFuture = jellyfinApiHelper.getItems(
    includeItemTypes: [
      BaseItemDtoType.album.jellyfinName,
      BaseItemDtoType.playlist.jellyfinName,
      BaseItemDtoType.collection.jellyfinName,
      if (includeTracks) BaseItemDtoType.track.jellyfinName,
    ].join(","),
    recursive: true,
    searchTerm: searchTerm,
    limit: 30,
  );
  // TODO handle album artists?
  final artistFuture = jellyfinApiHelper.getItems(
    includeItemTypes: [BaseItemDtoType.artist.jellyfinName].join(","),
    recursive: false,
    searchTerm: searchTerm,
    limit: 10,
  );
  // TODO handle genres for all libraries?  Or just use current?  We could just warn on no/low results?
  final genreFuture = jellyfinApiHelper.getItems(
    parentItem: GetIt.instance<FinampUserHelper>().currentUser!.currentView!,
    includeItemTypes: [BaseItemDtoType.genre.jellyfinName].join(","),
    recursive: false,
    searchTerm: searchTerm,
    limit: 10,
  );
  final values = await Future.wait([baseFuture, artistFuture, genreFuture]);
  final out = <BaseItemDto>[];
  for (var val in values) {
    if (val != null) {
      out.addAll(val);
    }
  }
  return out;
}

@Riverpod(keepAlive: true)
Future<FinampDisplayable<FinampPlayable>> resolveSection(Ref ref, HomeScreenSectionConfiguration section) async {
  switch (section.base) {
    case TabsHomeSection tabSection:
      final source = QueueItemSource.rawId(
        type: QueueItemSourceType.homeScreenSection,
        name: QueueItemSourceName(
          type: QueueItemSourceNameType.homeScreenSection,
          localizationParameter: section.presetType?.name,
          pretranslatedName: section.getTitle(GlobalSnackbar.requireL10n),
        ),
        id: section.id,
      );
      return MusicScreenPlayable(
        tab: tabSection.contentType,
        library: tabSection.libraryId,
        source: source,
        sortConfig: SortAndFilterController.resolveOffline(ref, tabSection.contentType, section.sortConfig),
      );
    case CollectionHomeSection collectionSection:
      final item = await ref.watch(itemByIdProvider(collectionSection.itemId).future);
      // TODO better source
      if (item == null) {
        // TODO should we be throwing?  Or returning null?
        return PrecalculatedPlayable(
          source: QueueItemSource(
            type: QueueItemSourceType.unknown,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.preTranslated,
              pretranslatedName: GlobalSnackbar.requireL10n.errorLoadingHomeSection,
            ),
            id: collectionSection.itemId,
          ),
          tracks: [],
        );
      }
      // source for collections has item added, otherwise all 3 sources are identical
      final source = QueueItemSource.rawId(
        type: QueueItemSourceType.homeScreenSection,
        name: QueueItemSourceName(
          type: QueueItemSourceNameType.homeScreenSection,
          localizationParameter: section.presetType?.name,
          pretranslatedName: section.getTitle(GlobalSnackbar.requireL10n),
        ),
        item: item,
        id: section.id,
      );
      final resolvedSort = SortAndFilterController.resolveOffline(
        ref,
        collectionSection.contentType,
        section.sortConfig,
      );

      // TODO this is a pretty horrible abuse of the contentType field.  Refactor storage method?
      if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.artist) {
        return Artist(
          item,
          source: source,
          sortConfig: resolvedSort,
          type: ArtistChildType.fromContentType(collectionSection.contentType),
          library: collectionSection.libraryId,
        );
      } else if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.genre) {
        return Genre(
          item,
          source: source,
          sortConfig: resolvedSort,
          type: GenreChildType.fromContentType(collectionSection.contentType),
          library: collectionSection.libraryId,
        );
      }
      final playable = FinampPlayableDto.fromItem(item, source: source, sortOverride: resolvedSort);
      switch (playable) {
        case FinampDisplayable<FinampPlayable> displayable:
          return displayable;
        case Track():
        case InstantMix():
          throw UnsupportedError("Invalid home section collection $playable");
      }
    case QueuesHomeSection():
      final source = QueueItemSource.rawId(
        type: QueueItemSourceType.homeScreenSection,
        name: QueueItemSourceName(
          type: QueueItemSourceNameType.homeScreenSection,
          localizationParameter: section.presetType?.name,
          pretranslatedName: section.getTitle(GlobalSnackbar.requireL10n),
        ),
        id: section.id,
      );
      return LatestQueues(sortConfig: ResolvedSortConfig.skipResolving(section.sortConfig), source: source);
  }
}

@riverpod
Future<PlayableSlice> getPlayerSlice(
  Ref ref, {
  required FinampPlayable item,
  required int startingOffset,
  int? limit,
}) async {
  switch (item) {
    case FinampUnpagedPlayable<Track>():
      final items = (await ref.watch(getChildTracksProvider(item: item).future)).map((x) => x.item).toList();
      return PlayableSlice(
        items: items,
        startingIndex: startingOffset,
        source: item.source,
        shuffleState: SliceShuffleState.linear,
      );
    case Track():
      return PlayableSlice(
        items: [item.item],
        startingIndex: 0,
        source: item.source,
        shuffleState: SliceShuffleState.linear,
      );
    case InstantMix():
      throw UnsupportedError("Music screen should not be including instant mix.");
    case MusicScreenPlayable<FinampPlayableDto>():
      bool hardLimit = true;
      if (limit == null) {
        limit = ref.watch(finampSettingsProvider.trackShuffleItemCount);
        hardLimit = false;
      }
      int preTracks = 0;
      // If we are working directly with tracks, add some extra to flesh out the previous tracks section
      // TODO merge all this into _getPagedchildTracks so we can get pretracks in other scenarios?
      if (item is MusicScreenPlayable<Track>) {
        preTracks = min(min(20, (limit! / 10.0).ceil()), startingOffset);
      }

      final items = await _getPagedChildTracks(
        ref,
        item: item,
        startingChild: startingOffset - preTracks,
        trackLimit: limit! + preTracks,
        hardLimit: hardLimit,
      );

      return PlayableSlice(
        items: items,
        startingIndex: preTracks,
        source: item.source,
        shuffleState: SliceShuffleState.linear,
      );
    case PlayableQueue():
      // TODO: add special queue slice
      throw UnimplementedError();
    case FinampUnpagedDisplayable<FinampPlayableDto> displayable:
      final children = await ref.watch(getChildItemsProvider(item: displayable).future);
      final output = <BaseItemDto>[];
      // TODO should we be adding any/all of the pretracks?
      // TODO load tracks directly?  I think that might cause a sort mismatch, though.
      for (final child in children.safeSliceByLength(startingOffset)) {
        output.addAll(await _flattenToTracks(ref, item: child));
        if (limit != null && output.length > limit) {
          break;
        }
      }
      return PlayableSlice(
        items: limit == null ? output : output.slice(0, min(limit, output.length)),
        startingIndex: 0,
        source: item.source,
        shuffleState: SliceShuffleState.linear,
      );
  }
}

Future<List<BaseItemDto>> _getPagedChildTracks(
  Ref ref, {
  required MusicScreenPlayable<FinampPlayableDto> item,
  required int startingChild,
  required int trackLimit,
  required bool hardLimit,
}) async {
  // Drop normal child size by half to reduce the odds of undershooting.  Clamps to a minimum expected child size of one.
  int childLimit = (trackLimit / min(1.0, item.normalChildSize / 2.0)).ceil();
  // Keep page provider alive even though we only read its notifier.
  ref.listen(pagedContentProvider(item), (_, _) {});
  final pager = ref.read(pagedContentProvider(item).notifier);
  final children = await pager.loadSlice(startingChild, childLimit);
  final output = <BaseItemDto>[];
  for (final rawChild in children) {
    // We require a MusicScreenPlayable<FinampPlayableItem> as input, so all children are guaranteed to be FinampPlayableItems.
    // pagedContentProvider is not generic so it can't propagate this constraint, so we must cast
    final child = rawChild as FinampPlayableDto;
    output.addAll(await _flattenToTracks(ref, item: child));
    if (output.length > trackLimit) {
      break;
    }
  }
  return output.slice(0, hardLimit ? min(trackLimit, output.length) : null);
}

Future<List<BaseItemDto>> _flattenToTracks(Ref ref, {required FinampPlayableDto item}) async {
  switch (item) {
    case FinampUnpagedDisplayable<Track> unpagged:
      final tracks = await getChildTracks(ref, item: unpagged);
      return tracks.map((x) => x.item).toList();
    case Track track:
      return [track.item];
    case InstantMix():
      throw UnsupportedError("Music screen should not be including instant mix.");
    case FinampUnpagedDisplayable<FinampPlayableDto> displayable:
      // TODO should artists/genres be doing direct requests?  How could we handle sorting?
      final children = await ref.watch(getChildItemsProvider(item: displayable).future);
      final output = <BaseItemDto>[];
      for (final child in children) {
        output.addAll(await _flattenToTracks(ref, item: child));
      }
      return output;
  }
}

// Riverpod providers do not seem to currently support generics, so I've just duplicated this provider for all relevant types.

@riverpod
Future<List<Track>> getChildTracks(Ref ref, {required FinampUnpagedDisplayable<Track> item}) async {
  switch (item) {
    case Album():
      final items = await ref.watch(getAlbumOrPlaylistTracksProvider(item.item).future);
      // TODO handle playable vs non-playable tracks better.  Maybe track + playableTrack types?
      return items.$2.map((baseItem) => Track(baseItem)).toList();
    case AlbumDisc():
      return item.tracks.map((baseItem) => Track(baseItem)).toList();
    case PrecalculatedPlayable():
      return item.tracks.map((baseItem) => Track(baseItem)).toList();
    case Playlist():
      final items = await ref.watch(getSortedPlaylistTracksProvider(item.item, item.sortConfig).future);
      return items.$2.map((baseItem) => Track(baseItem)).toList();
    /*case GenericPlayableItem():
      final items = await loadChildTracksFromBaseItem(item: item.item, sortConfig: item.sortConfig);
      return items.map((baseItem) => Track(baseItem, source: item.source)).toList();*/
    case Artist<Track>():
      assert(item.type == ArtistChildType.tracks);
      final children = await ref.watch(
        getArtistTracksProvider(
          artist: item.item,
          libraryFilter: item.library,
          genreFilter: item.sortConfig.genreFilter?.id,
          onlyFavorites: item.sortConfig.favoritesFilter,
        ).future,
      );
      return children.map<Track>((child) => Track(child)).toList();
    case Genre<Track>():
      assert(item.type == GenreChildType.tracks);
      final sort = item.sortConfig.copyWithGenre(item.item);
      final playable = MusicScreenPlayable(
        tab: ContentType.tracks,
        library: item.library,
        source: item.source,
        sortConfig: sort,
      );
      // TODO something smarter?  But if the genre has more than 999 tracks, we probably shouldn't be loading them anyway.
      // should we make genres paged?
      // Keep page provider alive even though we only read its notifier.
      ref.listen(pagedContentProvider(playable), (_, _) {});
      return (await ref.read(pagedContentProvider(playable).notifier).loadSlice(0, 9999)).cast<Track>();
  }
}

@riverpod
Future<List<FinampPlayableDto>> getChildItems(
  Ref ref, {
  required FinampUnpagedDisplayable<FinampPlayableDto> item,
}) async {
  switch (item) {
    case FinampUnpagedDisplayable<Track>():
      return await ref.watch(getChildTracksProvider(item: item).future);
    case JellyfinCollection():
      final children = await ref.watch(getJellyfinCollectionProvider(item.item, item.sortConfig).future) ?? [];
      return children.map<FinampPlayableDto>((child) => FinampPlayableDto.fromItem(child)).toList();
    case Artist<FinampPlayableDto>():
      switch (item.type) {
        case ArtistChildType.tracks:
          throw UnsupportedError("This is expected to be a FinampUnpagedDisplayable<Track>()");
        case ArtistChildType.albumsFromArtist:
          final children = await ref.watch(
            getArtistAlbumsProvider(
              artist: item.item,
              libraryFilter: item.library,
              genreFilter: item.sortConfig.genreFilter?.id,
              sortBy: item.sortConfig.sortBy,
              sortOrder: item.sortConfig.sortOrder,
            ).future,
          );
          return children.map<FinampPlayableDto>((child) => Album.fromItem(child)).toList();
        case ArtistChildType.appearsOnAlbums:
          final children = await ref.watch(
            getPerformingArtistAlbumsProvider(
              artist: item.item,
              libraryFilter: item.library,
              genreFilter: item.sortConfig.genreFilter?.id,
              sortBy: item.sortConfig.sortBy,
              sortOrder: item.sortConfig.sortOrder,
            ).future,
          );
          return children.map<FinampPlayableDto>((child) => Album.fromItem(child)).toList();
      }
    case Genre<FinampPlayableDto>():
      assert(item.type != GenreChildType.tracks);
      final sort = item.sortConfig.copyWithGenre(item.item);
      final playable = MusicScreenPlayable(
        tab: switch (item.type) {
          GenreChildType.tracks => throw UnsupportedError(
            "This request should have been a FinampUnpagedDisplayable<Track>",
          ),
          GenreChildType.albums => ContentType.albums,
          // TODO could we supply genericArtists here?  I don't believe that type can resolve, currently.
          GenreChildType.artists => ContentType.performingArtists,
          GenreChildType.playlists => ContentType.playlists,
        },
        library: item.library,
        source: item.source,
        sortConfig: sort,
      );
      // Keep page provider alive even though we only read its notifier.
      ref.listen(pagedContentProvider(playable), (_, _) {});
      return (await ref.watch(pagedContentProvider(playable).notifier).loadSlice(0, 9999)).cast<FinampPlayableDto>();
  }
}

@riverpod
Future<List<FinampDisplayableOrPlayable>> getChildren(
  Ref ref, {
  required FinampUnpagedDisplayable<FinampDisplayableOrPlayable> item,
}) async {
  switch (item) {
    case FinampUnpagedDisplayable<Track>():
      // TODO figure out how to get refreshing working for non MusicScreenPlayables
      // Maybe we could have a refresh provider that takes a DisplayableOrPlayable and gets watched by everyone?
      return await ref.watch(getChildTracksProvider(item: item).future);
    case FinampUnpagedDisplayable<FinampPlayableDto>():
      return await ref.watch(getChildItemsProvider(item: item).future);
    case LatestQueues():
      final queuesBox = Hive.box<FinampStorableQueueInfo>("Queues");
      var queueMap = queuesBox.toMap();
      queueMap.remove("latest");
      var queueList = queueMap.values.toList();
      queueList.sort((x, y) {
        return switch (item.sortConfig.sortBy) {
          SortBy.dateCreated || SortBy.datePlayed => x.creation.compareTo(y.creation),
          // SortBy.runtime => x.runtime.compareTo(y.runtime), //TODO add support for sorting by runtime
          _ => 0,
        };
      });
      if (item.sortConfig.sortOrder == SortOrder.descending) {
        queueList = queueList.reversed.toList();
      }
      return queueList.map((x) => PlayableQueue(queue: x, source: item.source)).toList();
  }
}
