import 'dart:async';

import 'package:finamp/components/curated_item_filter_row.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'music_screen_provider.dart';

part 'artist_content_provider.g.dart';

// Get the Tracks Section content of an artist
@riverpod
Future<(List<BaseItemDto>, CuratedItemSelectionType, Set<CuratedItemSelectionType>?)> getArtistTracksSection(
  Ref ref, {
  required BaseItemDto artist,
  BaseItemDto? libraryFilter,
  BaseItemId? genreFilter,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
  final bool autoSwitchItemCurationTypeEnabled = ref.watch(finampSettingsProvider.autoSwitchItemCurationType);
  final Set<CuratedItemSelectionType> disabledFilters = {};
  final artistCuratedItemSectionFilterOrder = ref.watch(finampSettingsProvider.artistItemSectionFilterChipOrder);
  CuratedItemSelectionType currentSelectionType = handleOfflineFallbackOption(
    isOffline: isOffline,
    currentFilter: ref.watch(finampSettingsProvider.artistCuratedItemSelectionType),
    filterListFor: BaseItemDtoType.track,
    customFilterOrder: artistCuratedItemSectionFilterOrder,
  );
  // If Tracks Section is disabled, we return an empty list
  if (!ref.watch(finampSettingsProvider.showArtistsTracksSection)) {
    return (<BaseItemDto>[], currentSelectionType, null);
  }

  // Get Items
  Future<List<BaseItemDto>> fetchItems(CuratedItemSelectionType selectionType) async {
    final sortBy = selectionType.getSortBy();
    if (isOffline) {
      // In Offline Mode:
      // We already fetch all tracks for the playback,
      // and as in offline mode this is much faster,
      // we just sort them and only return the first 5 items.
      final onlyFavorites = (selectionType == CuratedItemSelectionType.favorites);
      final List<BaseItemDto> allArtistTracks = await ref.watch(
        getArtistTracksProvider(
          artist: artist,
          libraryFilter: libraryFilter?.id,
          genreFilter: genreFilter,
          onlyFavorites: onlyFavorites,
        ).future,
      );
      var items = sortItems(allArtistTracks, sortBy, SortOrder.descending);
      items = items.take(5).toList();
      return items;
    } else {
      // In Online Mode:
      final List<BaseItemDto>? topAlbumArtistTracks = await jellyfinApiHelper.getItems(
        libraryFilter: libraryFilter?.id,
        parentItem: artist,
        genreFilter: genreFilter,
        artistType: ArtistType.albumArtist,
        sortBy: sortBy.jellyfinName(ContentType.tracks),
        sortOrder: SortOrder.descending.name,
        isFavorite: (selectionType == CuratedItemSelectionType.favorites) ? true : null,
        limit: 5,
        includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
      );
      // For everything except Favorites we can re-use the data from the other provider
      // The other provider would not limit the favorites but run a separate call anyway
      // so we would get a lot of overhead and therefore we are just doing it right here
      final List<BaseItemDto>? topPerformingArtistTracks = (selectionType != CuratedItemSelectionType.favorites)
          ? await ref.watch(
              getPerformingArtistTracksProvider(
                artist: artist,
                libraryFilter: libraryFilter?.id,
                genreFilter: genreFilter,
              ).future,
            )
          : await jellyfinApiHelper.getItems(
              libraryFilter: libraryFilter?.id,
              parentItem: artist,
              genreFilter: genreFilter,
              artistType: ArtistType.artist,
              sortBy: sortBy.jellyfinName(ContentType.tracks),
              sortOrder: SortOrder.descending.name,
              isFavorite: true,
              limit: 5,
              includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
            );

      final Map<String, BaseItemDto> distinctMap = {
        for (final track in [...?topAlbumArtistTracks, ...?topPerformingArtistTracks]) track.id.toString(): track,
      };

      final List<BaseItemDto> distinctTracks = distinctMap.values.toList();
      var items = sortItems(distinctTracks, sortBy, SortOrder.descending);
      items = items.take(5).toList();
      return items;
    }
  }

  List<BaseItemDto> filterResult(List<BaseItemDto> result, CuratedItemSelectionType curatedItemType) {
    if (curatedItemType == CuratedItemSelectionType.mostPlayed) {
      return result.where((s) => (s.userData?.playCount ?? 0) > 0).take(5).toList();
    } else if (curatedItemType == CuratedItemSelectionType.recentlyPlayed) {
      return result.where((s) => s.userData?.lastPlayedDate != null).take(5).toList();
    } else {
      return result.take(5).toList();
    }
  }

  var result = await fetchItems(currentSelectionType);
  var filteredResult = filterResult(result, currentSelectionType);

  while (autoSwitchItemCurationTypeEnabled &&
      filteredResult.isEmpty &&
      (currentSelectionType == CuratedItemSelectionType.favorites ||
          currentSelectionType == CuratedItemSelectionType.mostPlayed ||
          currentSelectionType == CuratedItemSelectionType.recentlyPlayed)) {
    // Add the currentSelectionType to a Set of disabled types
    disabledFilters.add(currentSelectionType);
    // Get next fallback
    CuratedItemSelectionType newSelectionType = getFallbackFilterOption(
      isOffline: isOffline,
      currentType: currentSelectionType,
      filterListFor: BaseItemDtoType.track,
      customFilterOrder: artistCuratedItemSectionFilterOrder,
      disabledFilters: disabledFilters,
    );
    // Break if we are cycling without new options
    if (newSelectionType == currentSelectionType) break;
    // Call fetchItems again with the newSelectionType
    currentSelectionType = newSelectionType;
    result = await fetchItems(currentSelectionType);
    filteredResult = filterResult(result, currentSelectionType);
  }

  return (filteredResult, currentSelectionType, disabledFilters);
}

// Get Albums where the artist is an album artist
@riverpod
Future<List<BaseItemDto>> getArtistAlbums(
  Ref ref, {
  required BaseItemDto artist,
  LibraryId? libraryFilter,
  BaseItemId? genreFilter,
  SortBy sortBy = SortBy.premiereDate,
  SortOrder sortOrder = SortOrder.ascending,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
  // Get Items
  if (isOffline) {
    // In Offline Mode:
    // Get Albums where artist is Album Artist sorted by Premiere Date
    List<BaseItemDto> artistAlbums = (await downloadsService.getAllCollections(
      viewFilter: libraryFilter?.resolve(ref),
      childViewFilter: null,
      nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
      includeItemTypes: [BaseItemDtoType.album],
      relatedTo: artist,
      artistType: ArtistType.albumArtist,
      genreFilter: genreFilter,
    )).map((e) => e.baseItem).nonNulls.toList();
    artistAlbums = sortItems(artistAlbums, sortBy, sortOrder);
    return artistAlbums;
  } else {
    // In Online Mode:
    // Get Albums where artist is Album Artist sorted by Premiere Date
    final List<BaseItemDto>? artistAlbums = await jellyfinApiHelper.getItems(
      libraryFilter: libraryFilter?.resolve(ref),
      parentItem: artist,
      genreFilter: genreFilter,
      sortBy: sortBy.jellyfinName(ContentType.albums),
      sortOrder: sortOrder.name,
      includeItemTypes: [BaseItemDtoType.album.jellyfinName].join(","),
      artistType: ArtistType.albumArtist,
    );
    return artistAlbums ?? [];
  }
}

// Get Albums with tracks in it on which the artist is a performing artist
// (note that this also might include albums where the artist is album artist as well,
// so we have to filter this list later for the appears on section to exclude those)
@riverpod
Future<List<BaseItemDto>> getPerformingArtistAlbums(
  Ref ref, {
  required BaseItemDto artist,
  LibraryId? libraryFilter,
  BaseItemId? genreFilter,
  SortBy sortBy = SortBy.premiereDate,
  SortOrder sortOrder = SortOrder.ascending,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
  // Get Items
  if (isOffline) {
    // In Offline Mode:
    // Get Albums where artist is Performing Artist sorted by Premiere Date
    List<BaseItemDto> performingArtistAlbums = (await downloadsService.getAllCollections(
      viewFilter: libraryFilter?.resolve(ref),
      childViewFilter: null,
      nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
      includeItemTypes: [BaseItemDtoType.album],
      relatedTo: artist,
      artistType: ArtistType.artist,
      genreFilter: genreFilter,
    )).map((e) => e.baseItem).nonNulls.toList();
    performingArtistAlbums = sortItems(performingArtistAlbums, sortBy, sortOrder);
    return sortArtistTracks(performingArtistAlbums);
  } else {
    // In Online Mode:
    // Get Albums where artist is Performing Artist sorted by Premiere Date
    final List<BaseItemDto>? performingArtistAlbums = await jellyfinApiHelper.getItems(
      libraryFilter: libraryFilter?.resolve(ref),
      parentItem: artist,
      genreFilter: genreFilter,
      sortBy: sortBy.jellyfinName(ContentType.albums),
      sortOrder: sortOrder.name,
      includeItemTypes: [BaseItemDtoType.album.jellyfinName].join(","),
      artistType: ArtistType.artist,
    );
    return performingArtistAlbums ?? [];
  }
}

// Fetch every performing artist track
// (note that this intentionally also includes tracks
// where the artist is also an album artist)
@riverpod
Future<List<BaseItemDto>> getPerformingArtistTracks(
  Ref ref, {
  required BaseItemDto artist,
  LibraryId? libraryFilter,
  BaseItemId? genreFilter,
  bool onlyFavorites = false,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);

  // Get Items
  if (isOffline) {
    // In Offline Mode:
    final List<BaseItemDto> performingArtistTracks = [];
    // Fetch every album where the artist is a performing artist
    final List<BaseItemDto> allPerformingArtistAlbums = await ref.watch(
      getPerformingArtistAlbumsProvider(artist: artist, libraryFilter: libraryFilter, genreFilter: genreFilter).future,
    );
    // Loop through the albums and add the tracks
    for (var album in allPerformingArtistAlbums) {
      final performingArtistAlbumTracks = await downloadsService.getCollectionTracks(
        album,
        playable: true,
        onlyFavorites: onlyFavorites,
      );
      // Now we remove every track where the artist is NOT an performing artist...
      final filteredPerformingArtistTracks = performingArtistAlbumTracks.where((track) {
        return track.artistItems?.any((artist) => artist.id == artist.id) ?? false;
      });
      // and add the tracks to the list
      performingArtistTracks.addAll(filteredPerformingArtistTracks);
    }
    return performingArtistTracks;
  } else {
    // In Online Mode:
    final List<BaseItemDto>? allPerformingArtistTracks = await jellyfinApiHelper.getItems(
      libraryFilter: libraryFilter?.resolve(ref),
      parentItem: artist,
      genreFilter: genreFilter,
      sortBy: SortBy.premiereDate.jellyfinName(ContentType.tracks),
      includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
      artistType: ArtistType.artist,
      isFavorite: (onlyFavorites == true) ? true : null,
    );
    return allPerformingArtistTracks ?? [];
  }
}

// Get all Tracks for playback
@riverpod
Future<List<BaseItemDto>> getArtistTracks(
  Ref ref, {
  required BaseItemDto artist,
  LibraryId? libraryFilter,
  BaseItemId? genreFilter,
  bool onlyFavorites = false,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();
  final isOffline = ref.watch(finampSettingsProvider.isOffline);
  // Get Items
  if (isOffline) {
    // In Offline Mode:
    // First fetch every album of the album artist
    final List<BaseItemDto> allAlbumArtistAlbums = await ref.watch(
      getArtistAlbumsProvider(artist: artist, libraryFilter: libraryFilter, genreFilter: genreFilter).future,
    );
    // Then add the tracks of every album
    final List<BaseItemDto> sortedTracks = [];
    for (var album in allAlbumArtistAlbums) {
      sortedTracks.addAll(
        await downloadsService.getCollectionTracks(album, playable: true, onlyFavorites: onlyFavorites),
      );
    }
    // Fetch every performing artist track
    final List<BaseItemDto> allPerformingArtistTracks = await ref.watch(
      getPerformingArtistTracksProvider(
        artist: artist,
        libraryFilter: libraryFilter,
        genreFilter: genreFilter,
        onlyFavorites: onlyFavorites,
      ).future,
    );
    // Filter out the tracks already added through album artist albums
    final existingIds = sortedTracks.map((t) => t.id).toSet();
    final List<BaseItemDto> allPerformingArtistTracksFiltered = allPerformingArtistTracks
        .where((track) => !existingIds.contains(track.id))
        .toList();
    // Add the remaining tracks
    sortedTracks.addAll(allPerformingArtistTracksFiltered);
    // And return the tracks
    return sortedTracks;
  } else {
    // In Online Mode:
    // Fetch every album artist track
    final allAlbumArtistTracksResponse = await jellyfinApiHelper.getItems(
      libraryFilter: libraryFilter?.resolve(ref),
      parentItem: artist,
      genreFilter: genreFilter,
      sortBy: SortBy.premiereDate.jellyfinName(ContentType.tracks),
      includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
      artistType: ArtistType.albumArtist,
    );
    // Get all performing artist tracks
    final List<BaseItemDto> allPerformingArtistTracks = await ref.watch(
      getPerformingArtistTracksProvider(
        artist: artist,
        libraryFilter: libraryFilter,
        genreFilter: genreFilter,
        onlyFavorites: onlyFavorites,
      ).future,
    );
    // We now remove albumartist tracks from performance artist tracks to avoid duplicates
    final allAlbumArtistTracks = allAlbumArtistTracksResponse ?? [];
    final allPerformingTracks = allPerformingArtistTracks;
    final albumArtistTrackIds = allAlbumArtistTracks.map((item) => item.id).toSet();
    final filteredPerformingTracks = allPerformingTracks
        .where((performingTrack) => !albumArtistTrackIds.contains(performingTrack.id))
        .toList();
    // combine and return
    final combinedTracks = [...allAlbumArtistTracks, ...filteredPerformingTracks];
    return combinedTracks;
  }
}
