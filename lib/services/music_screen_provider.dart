import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'item_by_id_provider.dart';
import 'jellyfin_api_helper.dart';

part 'music_screen_provider.g.dart';

const musicScreenPageSize = 100;
const homeScreenSectionItemLimit = 20;
const slicePretracks = 20;

final class MusicScreenRequest {
  MusicScreenRequest({
    required SortAndFilterConfiguration filter,
    required this.library,
    required TabContentType tabType,
  }) : config = HomeScreenSectionConfiguration(
         type: HomeScreenSectionType.tabView,
         contentType: tabType,
         sortAndFilterConfiguration: filter,
       );

  final BaseItemDto? library;
  final HomeScreenSectionConfiguration config;

  MusicScreenRequest.home({required this.config, required this.library});

  @override
  bool operator ==(Object other) {
    return other is MusicScreenRequest && other.config == config && other.library == library;
  }

  @override
  int get hashCode => Object.hash(config, library);
}

class PlayableSlice {
  const PlayableSlice({required this.items, required this.startingIndex});
  final List<BaseItemDto> items;
  final int startingIndex;
}

@riverpod
class MusicScreenContent extends _$MusicScreenContent {
  int _pageCount = 0;
  List<LoadHomeSectionItemsProvider> _dependancies = [];

  @override
  PagingState<int, BaseItemDto> build(MusicScreenRequest request) {
    final List<List<BaseItemDto>> pages = [];
    final List<int> keys = [];
    final List<LoadHomeSectionItemsProvider> providers = [];
    bool isLoading = false;
    bool hasNextPage = true;
    Object? error;

    int offset = 0;
    for (int i = 0; i < _pageCount; i++) {
      // Use small initial page to potentially reuse existing items
      // TODO maybe check exists instead?  Make home screen provider use full size pages?
      // Does using small pages actually decrease home screen loading times?
      int pageSize = i == 0 ? homeScreenSectionItemLimit : musicScreenPageSize;
      final itemsProviderInstance = loadHomeSectionItemsProvider(
        sectionInfo: request.config,
        library: request.library,
        startIndex: offset,
        limit: pageSize,
      );
      providers.add(itemsProviderInstance);

      final page = ref.watch(itemsProviderInstance).unwrapPrevious();
      if (page is AsyncData) {
        if (page.value != null) {
          pages.add(page.value!);
          keys.add(offset);
          if (page.value!.length < pageSize) {
            hasNextPage = false;
          }
        }
      } else if (page is AsyncLoading) {
        /*if (page.value != null) {
          pages.add(page.value!);
          keys.add(offset);
          if (page.value!.length < pageSize) {
            hasNextPage = false;
          }
        }*/
        isLoading = true;
      } else if (page is AsyncError) {
        error = page.error;
      }
      offset += pageSize;
    }

    _dependancies = providers;

    return PagingState(
      pages: pages.isEmpty ? null : pages,
      keys: keys.isEmpty ? null : keys,
      isLoading: isLoading,
      hasNextPage: hasNextPage,
      error: error,
    );
  }

  void newPage() {
    // Only load one page at once
    if (!state.isLoading) {
      _pageCount++;
      ref.invalidateSelf();
    }
  }

  void refresh() {
    _pageCount = 0;
    ref.invalidateSelf();
    // Delay invalidation of page providers until after we stop depending on them
    // to avoid immediate rebuild of all.
    final oldProviders = _dependancies;
    listenSelf((_, _) {
      for (var provider in oldProviders) {
        ref.invalidate(provider);
      }
    });
  }

  // TODO optimize for fast response, like play all on home screen?
  // Maybe we add a followup Future to PlayableSlice, and if we already have the starting item in cache (we should)
  // then immediately return a slice with the rest in that future for the caller to add to queue later.
  Future<PlayableSlice> loadSlice(int startingIndex) async {
    // TODO wait for current active loads to complete.  Do error response?
    final preCached = state.items ?? [];
    final doLoads = state.hasNextPage;

    final queueEndTarget = startingIndex + FinampSettingsHelper.finampSettings.trackShuffleItemCount;
    final queueStartOffset = max(startingIndex - slicePretracks, 0);
    final queuePretracks = startingIndex - queueStartOffset;
    if (preCached.length >= queueEndTarget) {
      return PlayableSlice(items: preCached.slice(queueStartOffset, queueEndTarget), startingIndex: queuePretracks);
    }
    List<BaseItemDto> items = [];
    if (queueStartOffset < preCached.length) {
      items = preCached.slice(queueStartOffset);
    }

    if (!doLoads) {
      return PlayableSlice(items: items, startingIndex: queuePretracks);
    }
    final loadStartOffset = queueStartOffset + items.length;
    final loadSize = queueEndTarget - loadStartOffset;
    // TODO paginate?
    final loadedItems = await ref.read(
      loadHomeSectionItemsProvider(
        sectionInfo: request.config,
        library: request.library,
        startIndex: loadStartOffset,
        limit: loadSize,
      ).future,
    );
    return PlayableSlice(items: items + (loadedItems ?? []), startingIndex: queuePretracks);
  }
}

@Riverpod(keepAlive: true)
Future<List<BaseItemDto>?> loadHomeSectionItems(
  Ref ref, {
  required HomeScreenSectionConfiguration sectionInfo,
  required BaseItemDto? library,
  required int startIndex,
  required int limit,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  final Future<List<BaseItemDto>?> newItemsFuture;

  if (ref.watch(finampSettingsProvider.isOffline)) {
    newItemsFuture = loadHomeSectionItemsOffline(
      ref: ref,
      sectionInfo: sectionInfo,
      library: library,
      startIndex: startIndex,
      limit: limit,
    );
    return newItemsFuture;
  }

  switch (sectionInfo.type) {
    case HomeScreenSectionType.tabView:
      final genreFilter = sectionInfo.sortAndFilterConfiguration.filters.firstWhereOrNull(
        (x) => x.type == ItemFilterType.genreFilter,
      );
      final searchFilter = sectionInfo.sortAndFilterConfiguration.filters.firstWhereOrNull(
        (x) => x.type == ItemFilterType.searchTerm,
      );
      newItemsFuture = jellyfinApiHelper.getItems(
        libraryFilter: library,
        parentItem: sectionInfo.contentType == TabContentType.playlists ? null : library!,
        includeItemTypes: [sectionInfo.contentType?.itemType?.jellyfinName].join(","),
        sortBy: sectionInfo.sortAndFilterConfiguration.sortBy.jellyfinName(sectionInfo.contentType),
        sortOrder: sectionInfo.sortAndFilterConfiguration.sortOrder.toString(),
        searchTerm: searchFilter?.extraString.trim(),
        filters: sectionInfo.sortAndFilterConfiguration.filters
            .map(
              (filter) => switch (filter.type) {
                ItemFilterType.isFavorite => "IsFavorite",
                ItemFilterType.isFullyDownloaded => null, // only applicable for offline mode
                // ItemFilterType.startsWithCharacter => "NameStartsWith: ${filter.value}",
                ItemFilterType.startsWithCharacter =>
                  null, //TODO properly handle the "NameStartsWith" filter in the API helper
                ItemFilterType.genreFilter => null,
                ItemFilterType.searchTerm => null,
              },
            )
            .nonNulls
            .join(","),
        startIndex: sectionInfo.sortAndFilterConfiguration.sortBy == SortBy.random ? 0 : startIndex,
        limit: limit,
        //isFavorite:
        //(widget.tabContentType.itemType == BaseItemDtoType.genre &&
        //    sortAndFilterConfig.filters.any((filter) => filter.type == ItemFilterType.isFavorite))
        //     ? true
        //    : null,
        // TODO how does home screen handle artist type?
        //artistType: settings.defaultArtistType,
        genreFilter: genreFilter != null ? genreFilter.extraBaseItem : null,
      );
      break;
    case HomeScreenSectionType.collection:
      final baseItem = await GetIt.instance<ProviderContainer>().read(itemByIdProvider(sectionInfo.itemId!).future);
      newItemsFuture = jellyfinApiHelper.getItems(
        parentItem: baseItem,
        recursive: false, //!!! prevent loading tracks and albums from inside the collection items
        sortBy: sectionInfo.sortAndFilterConfiguration.sortBy.jellyfinName(null),
        sortOrder: sectionInfo.sortAndFilterConfiguration.sortOrder.toString(),
        filters: sectionInfo.sortAndFilterConfiguration.filters
            .map(
              (filter) => switch (filter.type) {
                ItemFilterType.isFavorite => "IsFavorite",
                ItemFilterType.isFullyDownloaded => null, // only applicable for offline mode
                // ItemFilterType.startsWithCharacter => "NameStartsWith: ${filter.value}",
                ItemFilterType.startsWithCharacter =>
                  null, //TODO properly handle the "NameStartsWith" filter in the API helper
                ItemFilterType.genreFilter => throw UnimplementedError(),
                ItemFilterType.searchTerm => throw UnimplementedError(),
              },
            )
            .nonNulls
            .join(","),
        startIndex: startIndex,
        limit: limit,
      );
      break;
  }

  return await newItemsFuture;
}

Future<List<BaseItemDto>?> loadHomeSectionItemsOffline({
  required Ref ref,
  required HomeScreenSectionConfiguration sectionInfo,
  required BaseItemDto? library,
  int startIndex = 0,
  int limit = 10,
}) async {
  final downloadsService = GetIt.instance<DownloadsService>();

  List<DownloadStub> offlineItems;
  List<BaseItemDto> items;

  final searchFilter = sectionInfo.sortAndFilterConfiguration.filters.firstWhereOrNull(
    (x) => x.type == ItemFilterType.searchTerm,
  );
  final genreFilter = sectionInfo.sortAndFilterConfiguration.filters.firstWhereOrNull(
    (x) => x.type == ItemFilterType.genreFilter,
  );

  switch (sectionInfo.type) {
    // case HomeScreenSectionType.listenAgain:
    //   //FIXME this seems to also return metadata-only albums which don't have any downloaded children
    //   offlineItems = await downloadsService.getAllCollections(
    //     includeItemTypes: [BaseItemDtoType.album, BaseItemDtoType.playlist], //FIXME support allowing multiple types
    //     fullyDownloaded: settings.onlyShowFullyDownloaded,
    //     viewFilter: finampUserHelper.currentUser?.currentViewId,
    //     childViewFilter: null,
    //     nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
    //     onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
    //   );

    //   items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
    //   items = sortItems(items, SortBy.datePlayed, SortOrder.descending);
    //   break;

    // case HomeScreenSectionType.newlyAdded:
    //   offlineItems = await downloadsService.getAllCollections(
    //     includeItemTypes: [BaseItemDtoType.album, BaseItemDtoType.playlist], //FIXME support allowing multiple types
    //     fullyDownloaded: settings.onlyShowFullyDownloaded,
    //     viewFilter: finampUserHelper.currentUser?.currentViewId,
    //     childViewFilter: null,
    //     nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
    //     onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
    //   );
    //   items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
    //   items = sortItems(items, SortBy.dateCreated, SortOrder.descending);
    //   break;
    // case HomeScreenSectionType.favoriteArtists:
    //   offlineItems = await downloadsService.getAllCollections(
    //     includeItemTypes: [BaseItemDtoType.artist],
    //     fullyDownloaded: settings.onlyShowFullyDownloaded,
    //     viewFilter: finampUserHelper.currentUser?.currentViewId,
    //     childViewFilter: null,
    //     nullableViewFilters: false,
    //     onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
    //   );
    //   items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
    //   items = sortItems(items, SortBy.datePlayed, SortOrder.descending);
    //   break;
    case HomeScreenSectionType.tabView:
      //FIXME this seems to also return metadata-only albums which don't have any downloaded children
      if (sectionInfo.contentType == TabContentType.tracks) {
        // tracks are not stored as collections, so we need to get them differently
        offlineItems = await downloadsService.getAllTracks(
          nameFilter: searchFilter?.extraString.trim(),
          viewFilter: library?.id,
          nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
          onlyFavorites: sectionInfo.sortAndFilterConfiguration.filters.any(
            (filter) => filter.type == ItemFilterType.isFavorite,
          ),
          genreFilter: genreFilter?.extraBaseItem,
        );
      } else {
        //var artistInfoForType = (settings.defaultArtistType == ArtistType.albumArtist)
        //    ? BaseItemDtoType.album
        //    : BaseItemDtoType.track;
        offlineItems = await downloadsService.getAllCollections(
          nameFilter: searchFilter?.extraString.trim(),
          includeItemTypes: [
            sectionInfo.contentType?.itemType ?? BaseItemDtoType.album,
          ], //FIXME support allowing multiple types
          // TODO use the filter config for this instead of global(several places)?
          fullyDownloaded: ref.watch(finampSettingsProvider.onlyShowFullyDownloaded),
          viewFilter: library?.id,
          childViewFilter: [TabContentType.albums, TabContentType.playlists].contains(sectionInfo.contentType)
              ? null
              : library?.id,
          nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
          onlyFavorites: sectionInfo.sortAndFilterConfiguration.filters.any(
            (filter) => filter.type == ItemFilterType.isFavorite,
          ),
          // TODO figure out how to handle album artists(several places)
          //infoForType: (widget.tabContentType == TabContentType.artists) ? artistInfoForType : null,
          genreFilter: sectionInfo.contentType == TabContentType.playlists ? null : genreFilter?.extraBaseItem,
        );
      }
      break;
    case HomeScreenSectionType.collection:
      final baseItem = ref.watch(itemByIdProvider(sectionInfo.itemId!)).valueOrNull;
      if (baseItem == null) {
        return [];
      }
      offlineItems = await downloadsService.getAllCollections(
        relatedTo: baseItem,
        fullyDownloaded: ref.watch(finampSettingsProvider.onlyShowFullyDownloaded),
        //TODO collections are cross-library - should we really filter by library here?
        viewFilter: library?.id,
        childViewFilter: null,
        nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
        onlyFavorites:
            ref.watch(finampSettingsProvider.onlyShowFavorites) &&
            ref.watch(finampSettingsProvider.trackOfflineFavorites),
      );
      break;
  }

  items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
  var sortBy = sectionInfo.sortAndFilterConfiguration.sortBy;
  // PlayCount and Last Played are not representative in Offline Mode
  // so we disable it and overwrite it with the Sort Name if it was selected
  if (sortBy == SortBy.playCount || sortBy == SortBy.datePlayed) {
    sortBy = SortBy.sortName;
  }
  items = sortItems(items, sortBy, sectionInfo.sortAndFilterConfiguration.sortOrder);

  // Playlists use different genreIds due to their cross-library functionality.
  // In Online Mode, the api still returns correct data, but in Offline Mode,
  // we only have genres with their "libraryId" but playlists with their
  // "cross-library-genreIds", so we won't get any results. Therefore,
  // we have to load all playlists and manually filter by genreName.

  if (items.isNotEmpty && genreFilter != null && sectionInfo.contentType == TabContentType.playlists) {
    items = filterItemsByGenreName(items, genreFilter.extraBaseItem);
  }

  return items.skip(startIndex).take(limit).toList();
}

List<BaseItemDto> sortItems(List<BaseItemDto> itemsToSort, SortBy? sortBy, SortOrder? sortOrder) {
  if (sortBy == SortBy.random) {
    itemsToSort.shuffle();
  } else {
    itemsToSort.sort((a, b) {
      switch (sortBy ?? SortBy.sortName) {
        case SortBy.sortName:
          if (a.nameForSorting == null || b.nameForSorting == null) {
            // Returning 0 is the same as both being the same
            return 0;
          } else {
            return a.nameForSorting!.compareTo(b.nameForSorting!);
          }
        case SortBy.album:
          if (a.album == null || b.album == null) {
            return 0;
          } else {
            return a.album!.compareTo(b.album!);
          }
        case SortBy.albumArtist:
          if (a.albumArtist == null || b.albumArtist == null) {
            return 0;
          } else {
            return a.albumArtist!.compareTo(b.albumArtist!);
          }
        case SortBy.artist:
          if (a.artists == null || b.artists == null) {
            return 0;
          } else {
            return a.artists!.join(', ').compareTo(b.artists!.join(', '));
          }
        case SortBy.communityRating:
          if (a.communityRating == null || b.communityRating == null) {
            return 0;
          } else {
            return a.communityRating!.compareTo(b.communityRating!);
          }
        case SortBy.criticRating:
          if (a.criticRating == null || b.criticRating == null) {
            return 0;
          } else {
            return a.criticRating!.compareTo(b.criticRating!);
          }
        case SortBy.datePlayed:
          final dateA = a.userData?.lastPlayedDate == null
              ? null
              : DateTime.tryParse(a.userData!.lastPlayedDate!.trim());
          final dateB = b.userData?.lastPlayedDate == null
              ? null
              : DateTime.tryParse(b.userData!.lastPlayedDate!.trim());
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        case SortBy.dateCreated:
          final dateA = a.dateCreated == null ? null : DateTime.tryParse(a.dateCreated!.trim());
          final dateB = b.dateCreated == null ? null : DateTime.tryParse(b.dateCreated!.trim());
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        case SortBy.premiereDate:
          final dateA = a.premiereDate == null ? null : DateTime.tryParse(a.premiereDate!.trim());
          final dateB = b.premiereDate == null ? null : DateTime.tryParse(b.premiereDate!.trim());
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        case SortBy.playCount:
          if (a.userData?.playCount == null || b.userData?.playCount == null) {
            return 0;
          } else {
            return a.userData!.playCount.compareTo(b.userData!.playCount);
          }
        case SortBy.runtime:
          if (a.runTimeTicks == null || b.runTimeTicks == null) {
            return 0;
          } else {
            return a.runTimeTicks!.compareTo(b.runTimeTicks!);
          }
        // SortBy.random is handled outside this switch as per-comparison logic does not produce a good shuffle
        default:
          throw UnimplementedError("Unimplemented offline sort mode $sortBy");
      }
    });
  }

  return sortOrder == SortOrder.descending ? itemsToSort.reversed.toList() : itemsToSort;
}

// This function helps to sort artist tracks in order they appear in the album list
// There are scenarios where cached provider-data might return a shuffled resultset, I guess,
// so this function should definitely sort all artist tracks always the same
List<BaseItemDto> sortArtistTracks(List<BaseItemDto> items) {
  int _compareNullable<T extends Comparable>(T? a, T? b, {bool nullsFirst = false}) {
    if (a == null && b == null) return 0;
    if (a == null) return nullsFirst ? -1 : 1;
    if (b == null) return nullsFirst ? 1 : -1;
    return a.compareTo(b);
  }

  int _compareAlbum(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    final numRegex = RegExp(r'^(\d+)');
    final matchA = numRegex.firstMatch(a);
    final matchB = numRegex.firstMatch(b);

    if (matchA != null && matchB != null) {
      final numA = int.tryParse(matchA.group(1)!);
      final numB = int.tryParse(matchB.group(1)!);
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      }
    }
    // fallback to normal string comparison
    return a.compareTo(b);
  }

  items.sort((a, b) {
    // 1. PremiereDate
    final dateA = a.premiereDate == null ? null : DateTime.tryParse(a.premiereDate!.trim());
    final dateB = b.premiereDate == null ? null : DateTime.tryParse(b.premiereDate!.trim());
    final dateCompare = _compareNullable<DateTime>(dateA, dateB, nullsFirst: true);
    if (dateCompare != 0) return dateCompare;
    // 2. Album (numbers first)
    final albumCompare = _compareAlbum(a.album, b.album);
    if (albumCompare != 0) return albumCompare;
    // 3. ParentIndexNumber
    final parentIndexCompare = _compareNullable<int>(a.parentIndexNumber, b.parentIndexNumber);
    if (parentIndexCompare != 0) return parentIndexCompare;
    // 4. IndexNumber
    final indexCompare = _compareNullable<int>(a.indexNumber, b.indexNumber);
    if (indexCompare != 0) return indexCompare;
    // 5. SortName
    return _compareNullable<String>(a.sortName, b.sortName);
  });

  return items;
}

List<BaseItemDto> filterItemsByGenreName(List<BaseItemDto> items, BaseItemDto genreFilter) {
  if (genreFilter.name == null) return [];

  return items.where((item) {
    final assignedGenres = item.genreItems;
    if (assignedGenres == null) return false;

    return assignedGenres.any((genre) => genre.name == genreFilter.name);
  }).toList();
}
