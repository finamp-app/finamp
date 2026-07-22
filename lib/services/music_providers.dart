import 'dart:math';

import 'package:collection/collection.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../components/global_snackbar.dart';
import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import '../models/music_models.dart';
import '../models/music_slices.dart';
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
      final resolvedSort = SortAndFilterController.resolveOfflineWithoutFallback(
        ref,
        tabSection.contentType,
        section.sortConfig,
      );
      if (resolvedSort == null) {
        return UnavailableHomeSectionPlayable(source: source, section: section);
      }
      return MusicScreenPlayable(
        tab: tabSection.contentType,
        library: tabSection.libraryId,
        source: source,
        sortConfig: resolvedSort,
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
      final resolvedSort = SortAndFilterController.resolveOfflineWithoutFallback(
        ref,
        collectionSection.contentType,
        section.sortConfig,
      );
      if (resolvedSort == null) {
        return UnavailableHomeSectionPlayable(source: source, section: section);
      }

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
Future<PlayableSlice> getPlayableSlice(
  Ref ref, {
  required FinampPlayable item,
  required int startingOffset,
  int? limit,
}) async {
  switch (item) {
    case FinampUnpagedPlayable<Track>():
      final items = (await ref.watch(getChildTracksProvider(item: item).future)).map((x) => x.item).toList();
      return BasePlayableSlice(
        items: items,
        startingIndex: startingOffset,
        source: item.source,
        shuffleState: SliceShuffleState.linear,
      );
    case Track():
      return BasePlayableSlice(
        items: [item.item],
        startingIndex: 0,
        source: item.source,
        shuffleState: SliceShuffleState.linear,
      );
    case InstantMix():
      throw UnsupportedError("Music screen should not be including instant mix.");
    case FinampPagedPlayable<FinampPlayableDto>():
      bool hardLimit = true;
      if (limit == null) {
        limit = ref.watch(finampSettingsProvider.trackShuffleItemCount);
        hardLimit = false;
      }
      int preTracks = 0;
      // If we are working directly with tracks, add some extra to flesh out the previous tracks section
      // TODO merge all this into _getPagedchildTracks so we can get pretracks in other scenarios?
      if (item is FinampPagedPlayable<Track>) {
        preTracks = min(min(20, (limit! / 10.0).ceil()), startingOffset);
      }

      final trackLimit = limit! + preTracks;
      // Drop normal child size by half to reduce the odds of undershooting.  Clamps to a minimum expected child size of one.
      int childLimit = (trackLimit / max(1.0, item.normalChildSize / 2.0)).ceil();
      // Keep page provider alive even though we only read its notifier.
      ref.listen(pagedContentProvider(item), (_, _) {});
      final pager = ref.read(pagedContentProvider(item).notifier);
      final (children, childFuture) = pager.loadSlice(startingOffset - preTracks, childLimit);

      // We require a MusicScreenPlayable<FinampPlayableItem> as input, so all children are guaranteed to be FinampPlayableDtos.
      // pagedContentProvider is not generic so it can't propagate this constraint, so we must cast
      return _fetchFromChildren(
        ref,
        item,
        children.cast<FinampPlayableDto>().toList(),
        childFuture?.then((x) => x.cast<FinampPlayableDto>()),
        0,
        trackLimit,
        preTracks,
        hardLimit,
      );
    case PlayableQueue():
      // TODO: add special queue slice
      throw UnimplementedError();
    case FinampUnpagedDisplayable<FinampPlayableDto> displayable:
      final children = await ref.watch(getChildItemsProvider(item: displayable).future);
      return _fetchFromChildren(ref, item, children, null, startingOffset, limit, 0, true);
  }
}

Future<PlayableSlice> _fetchFromChildren(
  Ref ref,
  FinampPlayable item,
  List<FinampPlayableDto> children,
  Future<List<FinampPlayableDto>>? childFuture,
  int startingChild,
  int? limit,
  int preTracks,
  bool hardLimit,
) async {
  final precacheOutput = <BaseItemDto>[];
  // If all children are tracks, we can just add every available child during the precache
  // phase instead of delaying to the resolve phase.
  bool avoidFlattening = item is! FinampDisplayable<Track>;
  int precachedChildren = 0;
  bool exhaustedChildren = true;
  final precacheLimit = preTracks + 3;
  for (int i = min(startingChild, children.length); i <= children.length; i++) {
    if (precacheOutput.length >= precacheLimit && (avoidFlattening || i == children.length)) {
      exhaustedChildren = false;
      break;
    }
    if (i == children.length && childFuture != null) {
      children.addAll(await childFuture);
      childFuture = null;
    }
    if (i == children.length) {
      break;
    }
    precacheOutput.addAll(
      await _flattenToTracks(ref, item: children[i], limit: limit == null ? null : limit - precacheOutput.length),
    );
    precachedChildren++;
  }

  if (exhaustedChildren || (limit != null && precacheOutput.length >= limit)) {
    final returnedItems = limit == null || !hardLimit
        ? precacheOutput
        : precacheOutput.slice(0, min(limit, precacheOutput.length));
    return BasePlayableSlice(
      items: returnedItems,
      startingIndex: preTracks.clamp(0, max(0, returnedItems.length - 1)),
      source: item.source,
      shuffleState: SliceShuffleState.linear,
    );
  }

  return PreCachedPlayableSlice(
    source: item.source,
    shuffleState: SliceShuffleState.linear,
    cachedTracks: precacheOutput,
    // We are guaranteed to have reached enough pretracks if we make it to this point.
    startingOffset: preTracks,
    fetchTracks: Future.sync(() async {
      final futureLimit = limit == null ? null : limit - precacheOutput.length;
      final output = <BaseItemDto>[];
      for (int i = min(startingChild + precachedChildren, children.length); i <= children.length; i++) {
        if (futureLimit != null && output.length > futureLimit) {
          break;
        }
        if (i == children.length && childFuture != null) {
          children.addAll(await childFuture!);
          childFuture = null;
        }
        if (i == children.length) {
          break;
        }
        output.addAll(
          await _flattenToTracks(ref, item: children[i], limit: futureLimit == null ? null : -output.length),
        );
      }
      return futureLimit == null || !hardLimit ? output : output.slice(0, min(futureLimit, output.length));
    }),
    combineTracks: true,
  );
}

@riverpod
Future<PlayableSlice> getAlbumShuffledPlayerSlice(Ref ref, {required FinampPlayable item}) async {
  assert(item is Genre || item is Artist || (item is FinampSortable<Album> && item is FinampPlayable));
  final albumPlayable =
      switch (item) {
            FinampSortable<Album>() => item,
            Artist artist => Artist(
              artist.item,
              sortConfig: SortAndFilterConfiguration.defaultSort,
              // Only track types should get through to here
              type: ArtistChildType.appearsOnAlbums,
              library: artist.library,
            ),
            Genre genre => Genre(
              genre.item,
              sortConfig: SortAndFilterConfiguration.defaultSort,
              type: GenreChildType.albums,
              library: genre.library,
            ),
            _ => throw UnsupportedError("Cannot shuffle albums of $item"),
          }
          as FinampSortable<Album>;
  final shuffledPlayable =
      albumPlayable.copyWith(
            SortAndFilterController.resolveOffline(
              ref,
              ContentType.albums,
              albumPlayable.sortConfig.copyWith(sortBy: SortBy.random),
            ),
          )
          as FinampPlayable;
  final slice = await ref.watch(getPlayableSliceProvider(item: shuffledPlayable, startingOffset: 0).future);
  return slice.markPreshuffled();
  // return GroupedPlayableSlice(parent: slice, groupBy: (element) => element.albumId?.toString());
}

Future<List<BaseItemDto>> _flattenToTracks(Ref ref, {required FinampPlayableDto item, required int? limit}) async {
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
        output.addAll(await _flattenToTracks(ref, item: child, limit: limit == null ? null : limit - output.length));
        if (limit != null && output.length > limit) {
          break;
        }
      }
      return output;
    case Genre<FinampPlayableDto>():
      // Keep page provider alive even though we only read its notifier.
      ref.listen(pagedContentProvider(item), (_, _) {});
      final pager = ref.read(pagedContentProvider(item).notifier);
      final (children, childFuture) = pager.loadSlice(
        0,
        limit ?? FinampSettingsHelper.finampSettings.trackShuffleItemCount,
      );
      if ((limit == null || children.length < limit) && childFuture != null) {
        children.addAll(await childFuture);
      }
      // The children of a FinampPlayableDto should always be more FinampPlayableDtos
      return children.map((x) => (x as FinampPlayableDto).item).toList();
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
