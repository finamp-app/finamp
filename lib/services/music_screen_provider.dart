import 'dart:async';

import 'package:collection/collection.dart';
import 'package:finamp/extensions/list.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
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
import 'music_providers.dart';

part 'music_screen_provider.g.dart';

const musicScreenPageSize = 100;
const homeScreenSectionItemLimit = 20;

@riverpod
class PagedContent extends _$PagedContent {
  List<int> _pageSizes = [];
  List<ProviderBase<Object?>> _dependencies = [];

  @override
  PagingState<int, FinampDisplayableOrPlayable> build(FinampDisplayable<FinampDisplayableOrPlayable> request) {
    switch (request) {
      case FinampUnpagedDisplayable():
        return _buildUnpaged(request);
      case MusicScreenPlayable<FinampPlayableDto>():
        return _buildPaged(request);
    }
  }

  PagingState<int, FinampDisplayableOrPlayable> _buildUnpaged(FinampUnpagedDisplayable request) {
    if (_pageSizes.isEmpty) {
      return PagingState(pages: null, keys: null, isLoading: false, hasNextPage: true, error: null);
    }
    final provider = getChildrenProvider(item: request);
    final page = ref.watch(provider).unwrapPrevious();

    List<FinampDisplayableOrPlayable>? output;
    bool isLoading = false;
    bool hasNextPage = true;
    Object? error;

    if (page is AsyncData) {
      if (page.value != null) {
        output = page.value!;
        hasNextPage = false;
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

    _dependencies = [provider];

    return PagingState<int, FinampDisplayableOrPlayable>(
      pages: output == null ? null : [output],
      keys: output == null ? null : [0],
      isLoading: isLoading,
      hasNextPage: hasNextPage,
      error: error,
    );
  }

  PagingState<int, FinampDisplayableOrPlayable> _buildPaged(MusicScreenPlayable<FinampPlayableDto> request) {
    final List<List<FinampDisplayableOrPlayable>> pages = [];
    final List<int> keys = [];
    final List<LoadHomeSectionItemsProvider> providers = [];
    bool isLoading = false;
    bool hasNextPage = true;
    Object? error;

    int offset = 0;
    for (int i = 0; i < _pageSizes.length; i++) {
      final provider = loadHomeSectionItemsProvider(request: request, startIndex: offset, limit: _pageSizes[i]);
      providers.add(provider);

      final page = ref.watch(provider).unwrapPrevious();

      if (page is AsyncData) {
        if (page.value != null) {
          pages.add(page.value!.map((x) => request.buildChild(x)).toList());
          keys.add(offset);
          if (page.value!.length < _pageSizes[i]) {
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
      offset += _pageSizes[i];
    }

    _dependencies = providers;

    return PagingState<int, FinampDisplayableOrPlayable>(
      pages: pages.isEmpty ? null : pages,
      keys: keys.isEmpty ? null : keys,
      isLoading: isLoading,
      hasNextPage: hasNextPage,
      error: error,
    );
  }

  void newPage({int pageSize = musicScreenPageSize}) {
    if (!state.isLoading) {
      _pageSizes.add(pageSize);
      ref.invalidateSelf();
    }
  }

  void fetchHomeScreenItems() {
    // The pagination tends to generate multiple requests at once, so block all but the initial one.  The exception is
    // while loading the first, undersized page, we allow a second request through immediately to potentially finish
    // loading a proper page's worth faster.
    Future<void>.microtask(() {
      if (_pageSizes.isEmpty) {
        _pageSizes.add(homeScreenSectionItemLimit);
        ref.invalidateSelf();
      }
    });
  }

  void refresh() {
    _pageSizes = [];
    ref.invalidateSelf();
    // Delay invalidation of page providers until after we stop depending on them
    // to avoid immediate rebuild of all.
    final oldProviders = _dependencies;
    _dependencies = [];
    listenSelf((_, _) {
      for (var provider in oldProviders) {
        ref.invalidate(provider);
      }
    });
  }

  // TODO optimize for fast response, like play all on home screen?
  // Maybe we add a followup Future to PlayableSlice, and if we already have the starting item in cache (we should)
  // then immediately return a slice with the rest in that future for the caller to add to queue later.
  Future<List<FinampDisplayableOrPlayable>> loadSlice(int startingIndex, int limit) async {
    // capture local request for type casting
    final request = this.request;
    // TODO wait for current active loads to complete.  Do error response?
    final preCached = state.items ?? [];
    // hasNextPage should always be false if we have any items from a non-pagable, but lets make extra sure.
    final doLoads = state.hasNextPage && (request is FinampUnpagedDisplayable || preCached.isEmpty);

    final queueEndTarget = startingIndex + limit;
    if (preCached.length >= queueEndTarget) {
      return preCached.slice(startingIndex, queueEndTarget);
    }
    List<FinampDisplayableOrPlayable> items = [];
    if (startingIndex < preCached.length) {
      items = preCached.slice(startingIndex);
    }

    if (!doLoads) {
      return items;
    }

    final loadStartOffset = startingIndex + items.length;
    final loadSize = queueEndTarget - loadStartOffset;

    // TODO break request up into pages?
    newPage(pageSize: loadSize);

    ProviderSubscription? sub;
    Completer<List<FinampDisplayableOrPlayable>?> waitForPage = Completer();
    sub = GetIt.instance<ProviderContainer>().listen<PagingState<int, FinampDisplayableOrPlayable>>(
      pagedContentProvider(request),
      (_, value) {
        if (!value.isLoading) {
          waitForPage.complete(value.items);
          sub?.close();
        }
      },
    );
    return (await waitForPage.future ?? []).safeSliceByLength(startingIndex, limit);
  }
}

@riverpod
Future<List<BaseItemDto>?> loadHomeSectionItems(
  Ref ref, {
  required MusicScreenPlayable request,
  required int startIndex,
  required int limit,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  if (ref.watch(finampSettingsProvider.isOffline)) {
    return loadHomeSectionItemsOffline(ref: ref, request: request, startIndex: startIndex, limit: limit);
  }

  final BaseItemId? libraryId;
  if (request.library == allLibraryPlaceholder) {
    libraryId = null;
  } else if (request.library == currentLibraryPlaceholder) {
    final nullableLibraryId = ref.watch<BaseItemId?>(
      FinampUserHelper.finampCurrentUserProvider.select((value) => value?.currentView?.id),
    );
    if (nullableLibraryId == null) {
      return [];
    } else {
      libraryId = nullableLibraryId;
    }
  } else {
    libraryId = request.library as BaseItemId;
  }

  // TODO refactor so we only need to provide the id?
  BaseItemDto? library;
  if (libraryId != null) {
    library = await ref.watch(itemByIdProvider(libraryId).future);
    if (library == null) {
      return [];
    }
  }

  final genreFilter = request.sortConfig.filters.firstWhereOrNull((x) => x.type == ItemFilterType.genreFilter);
  final searchFilter = request.sortConfig.filters.firstWhereOrNull((x) => x.type == ItemFilterType.searchTerm);
  return jellyfinApiHelper.getItems(
    libraryFilter: library?.id,
    parentItem: request.tab == ContentType.playlists ? null : library,
    includeItemTypes: [request.tab.itemType?.jellyfinName].join(","),
    sortBy: request.sortConfig.sortBy.jellyfinName(request.tab),
    sortOrder: request.sortConfig.sortOrder.toString(),
    searchTerm: searchFilter?.extraString.trim(),
    filters: request.sortConfig.filters
        .map(
          (filter) => switch (filter.type) {
            ItemFilterType.isFavorite => "IsFavorite",
            ItemFilterType.isFullyDownloaded => null, // only applicable for offline mode
            // ItemFilterType.startsWithCharacter => "NameStartsWith: ${filter.value}",
            ItemFilterType.startsWithCharacter =>
              throw UnimplementedError(), //TODO properly handle the "NameStartsWith" filter in the API helper
            ItemFilterType.genreFilter => null,
            ItemFilterType.searchTerm => null,
            ItemFilterType.isUnplayed => "IsUnplayed",
          },
        )
        .nonNulls
        .join(","),
    startIndex: request.sortConfig.sortBy == SortBy.random ? 0 : startIndex,
    limit: limit,
    //isFavorite:
    //(widget.tabContentType.itemType == BaseItemDtoType.genre &&
    //    sortAndFilterConfig.filters.any((filter) => filter.type == ItemFilterType.isFavorite))
    //     ? true
    //    : null,
    artistType: switch (request.tab) {
      ContentType.albumArtists => ArtistType.albumArtist,
      ContentType.performingArtists => ArtistType.artist,
      _ => null,
    },
    genreFilter: genreFilter?.extraBaseItem.id,
  );
}

Future<List<BaseItemDto>?> loadHomeSectionItemsOffline({
  required Ref ref,
  required MusicScreenPlayable request,
  int startIndex = 0,
  int limit = 10,
}) async {
  final downloadsService = GetIt.instance<DownloadsService>();

  List<DownloadStub> offlineItems;
  List<BaseItemDto> items;

  final searchFilter = request.sortConfig.filters.firstWhereOrNull((x) => x.type == ItemFilterType.searchTerm);
  final genreFilter = request.sortConfig.filters.firstWhereOrNull((x) => x.type == ItemFilterType.genreFilter);

  BaseItemId? libraryId;
  if (request.library == allLibraryPlaceholder) {
    libraryId = null;
  } else if (request.library == currentLibraryPlaceholder) {
    libraryId = ref.watch<BaseItemId?>(
      FinampUserHelper.finampCurrentUserProvider.select((value) => value?.currentView?.id),
    );
    if (libraryId == null) {
      return [];
    }
  } else {
    libraryId = request.library as BaseItemId;
  }

  //FIXME this seems to also return metadata-only albums which don't have any downloaded children
  if (request.tab == ContentType.tracks) {
    // tracks are not stored as collections, so we need to get them differently
    offlineItems = await downloadsService.getAllTracks(
      nameFilter: searchFilter?.extraString.trim(),
      viewFilter: libraryId,
      nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
      onlyFavorites: request.sortConfig.filters.any((filter) => filter.type == ItemFilterType.isFavorite),
      genreFilter: genreFilter?.extraBaseItem.id,
    );
  } else {
    offlineItems = await downloadsService.getAllCollections(
      nameFilter: searchFilter?.extraString.trim(),
      includeItemTypes: [request.tab.itemType ?? BaseItemDtoType.album], //FIXME support allowing multiple types
      // TODO use the filter config for this instead of global(several places)?
      fullyDownloaded: ref.watch(finampSettingsProvider.onlyShowFullyDownloaded),
      viewFilter: libraryId,
      childViewFilter: [ContentType.albums, ContentType.playlists].contains(request.tab) ? null : libraryId,
      nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
      onlyFavorites: request.sortConfig.filters.any((filter) => filter.type == ItemFilterType.isFavorite),
      infoForType: switch (request.tab) {
        ContentType.albumArtists => BaseItemDtoType.album,
        ContentType.performingArtists => BaseItemDtoType.track,
        _ => null,
      },
      genreFilter: request.tab == ContentType.playlists ? null : genreFilter?.extraBaseItem.id,
    );
  }

  items = offlineItems.map((e) => e.baseItem).nonNulls.toList();

  var sortBy = request.sortConfig.sortBy;
  // PlayCount and Last Played are not representative in Offline Mode
  // so we disable it and overwrite it with the Sort Name if it was selected
  if (sortBy == SortBy.playCount || sortBy == SortBy.datePlayed) {
    sortBy = SortBy.sortName;
  }
  items = sortItems(items, sortBy, request.sortConfig.sortOrder);

  // Playlists use different genreIds due to their cross-library functionality.
  // In Online Mode, the api still returns correct data, but in Offline Mode,
  // we only have genres with their "libraryId" but playlists with their
  // "cross-library-genreIds", so we won't get any results. Therefore,
  // we have to load all playlists and manually filter by genreName.

  if (items.isNotEmpty && genreFilter != null && request.tab == ContentType.playlists) {
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
            return a.artists!.sortedBy((e) => e).join(", ").compareTo(b.artists!.sortedBy((e) => e).join(", "));
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
        case SortBy.productionYear:
          final dateA = a.productionYear;
          final dateB = b.productionYear;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        case SortBy.budget:
        case SortBy.revenue:
        case SortBy.defaultOrder:
          return 0;
        case SortBy.random:
          throw UnsupportedError(
            "SortBy.random is handled outside this switch as per-comparison logic does not produce a good shuffle",
          );
      }
    });
  }

  return sortOrder == SortOrder.descending ? itemsToSort.reversed.toList() : itemsToSort;
}

// This function helps to sort artist tracks in order they appear in the album list
// There are scenarios where cached provider-data might return a shuffled resultset, I guess,
// so this function should definitely sort all artist tracks always the same
List<BaseItemDto> sortArtistTracks(List<BaseItemDto> items) {
  int compareNullable<T extends Comparable<dynamic>>(T? a, T? b, {bool nullsFirst = false}) {
    if (a == null && b == null) return 0;
    if (a == null) return nullsFirst ? -1 : 1;
    if (b == null) return nullsFirst ? 1 : -1;
    return a.compareTo(b);
  }

  int compareAlbum(String? a, String? b) {
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
    final dateCompare = compareNullable<DateTime>(dateA, dateB, nullsFirst: true);
    if (dateCompare != 0) return dateCompare;
    // 2. Album (numbers first)
    final albumCompare = compareAlbum(a.album, b.album);
    if (albumCompare != 0) return albumCompare;
    // 3. ParentIndexNumber
    final parentIndexCompare = compareNullable<int>(a.parentIndexNumber, b.parentIndexNumber);
    if (parentIndexCompare != 0) return parentIndexCompare;
    // 4. IndexNumber
    final indexCompare = compareNullable<int>(a.indexNumber, b.indexNumber);
    if (indexCompare != 0) return indexCompare;
    // 5. SortName
    return compareNullable<String>(a.sortName, b.sortName);
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

@riverpod
Future<List<BaseItemDto>?> getJellyfinCollection(
  Ref ref,
  BaseItemDto collection,
  SortAndFilterConfiguration sortConfig,
) async {
  if (ref.watch(finampSettingsProvider.isOffline)) {
    // TODO I don't think the downloads system can actually handle collections?
    final stubs = await GetIt.instance<DownloadsService>().getAllCollections(
      relatedTo: collection,
      fullyDownloaded: sortConfig.filters.any((filter) => filter.type == ItemFilterType.isFullyDownloaded),
      //TODO collections are cross-library - should we really filter by library here?
      //viewFilter: libraryId,
      childViewFilter: null,
      nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
      onlyFavorites:
          sortConfig.filters.any((filter) => filter.type == ItemFilterType.isFavorite) &&
          ref.watch(finampSettingsProvider.trackOfflineFavorites),
    );
    return stubs.map((x) => x.baseItem).nonNulls.toList();
  } else {
    return GetIt.instance<JellyfinApiHelper>().getItems(
      parentItem: collection,
      recursive: false, //!!! prevent loading tracks and albums from inside the collection items
      sortBy: sortConfig.sortBy.jellyfinName(null),
      sortOrder: sortConfig.sortOrder.toString(),
      filters: sortConfig.filters
          .map(
            (filter) => switch (filter.type) {
              ItemFilterType.isFavorite => "IsFavorite",
              ItemFilterType.isFullyDownloaded => null, // only applicable for offline mode
              // ItemFilterType.startsWithCharacter => "NameStartsWith: ${filter.value}",
              ItemFilterType.startsWithCharacter =>
                throw UnimplementedError(), //TODO properly handle the "NameStartsWith" filter in the API helper
              ItemFilterType.genreFilter => throw UnimplementedError(),
              ItemFilterType.searchTerm => throw UnimplementedError(),
              ItemFilterType.isUnplayed => "IsUnplayed",
            },
          )
          .nonNulls
          .join(","),
      // TODO allow filtering collection child types?
      //includeItemTypes: sectionInfo.contentType.itemType?.jellyfinName,
    );
  }
}
