import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/extensions/list.dart';
import 'package:finamp/extensions/localizations.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/album_screen_provider.dart';
import 'package:finamp/services/artist_content_provider.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'item_by_id_provider.dart';
import 'item_helper.dart';
import 'jellyfin_api_helper.dart';

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
      case MusicScreenPlayable<FinampPlayableItem>():
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

    return PagingState(
      pages: output == null ? null : [output],
      keys: output == null ? null : [0],
      isLoading: isLoading,
      hasNextPage: hasNextPage,
      error: error,
    );
  }

  PagingState<int, FinampDisplayableOrPlayable> _buildPaged(MusicScreenPlayable<FinampPlayableItem> request) {
    final List<List<FinampDisplayableOrPlayable>> pages = [];
    final List<int> keys = [];
    final List<LoadHomeSectionItemsProvider> providers = [];
    bool isLoading = false;
    bool hasNextPage = true;
    Object? error;

    int offset = 0;
    for (int i = 0; i < _pageSizes.length; i++) {
      final provider = loadHomeSectionItemsProvider(
        sectionInfo: request.section,
        startIndex: offset,
        limit: _pageSizes[i],
      );
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

    return PagingState(
      pages: pages.isEmpty ? null : pages,
      keys: keys.isEmpty ? null : keys,
      isLoading: isLoading,
      hasNextPage: hasNextPage,
      error: error,
    );
  }

  void newPage({int pageSize = musicScreenPageSize}) {
    // The pagination tends to generate multiple requests at once, so block all but the initial one.  The exception is
    // while loading the first, undersized page, we allow a second request through immediately to potentially finish
    // loading a proper page's worth faster.
    if (!state.isLoading || _pageSizes.length < 2) {
      _pageSizes.add(pageSize);
      ref.invalidateSelf();
    }
  }

  void fetchHomeScreenItems() {
    // The pagination tends to generate multiple requests at once, so block all but the initial one.  The exception is
    // while loading the first, undersized page, we allow a second request through immediately to potentially finish
    // loading a proper page's worth faster.
    if (_pageSizes.isEmpty) {
      _pageSizes.add(homeScreenSectionItemLimit);
      ref.invalidateSelf();
    }
  }

  void refresh() {
    _pageSizes = [];
    ref.invalidateSelf();
    // Delay invalidation of page providers until after we stop depending on them
    // to avoid immediate rebuild of all.
    final oldProviders = _dependencies;
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

// TODO this should take a MusicScreenPlayable.  Maybe return them too?  Also, why is this keepAlive?
@Riverpod(keepAlive: true)
Future<List<BaseItemDto>?> loadHomeSectionItems(
  Ref ref, {
  required HomeScreenSectionConfiguration sectionInfo,
  required int startIndex,
  required int limit,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  if (ref.watch(finampSettingsProvider.isOffline)) {
    return loadHomeSectionItemsOffline(ref: ref, sectionInfo: sectionInfo, startIndex: startIndex, limit: limit);
  }

  switch (sectionInfo.type) {
    case HomeScreenSectionType.tabView:
      BaseItemId libraryId;
      if (sectionInfo.itemId == allLibraryPlaceholder) {
        throw UnimplementedError();
      } else if (sectionInfo.itemId == currentLibraryPlaceholder) {
        final nullableLibraryId = ref.watch<BaseItemId?>(
          FinampUserHelper.finampCurrentUserProvider.select((value) => value?.currentView?.id),
        );
        if (nullableLibraryId == null) {
          return [];
        } else {
          libraryId = nullableLibraryId;
        }
      } else {
        libraryId = sectionInfo.itemId as BaseItemId;
      }

      // TODO refactor so we only need to provide the id?
      final library = await ref.watch(itemByIdProvider(libraryId).future);
      if (library == null) {
        return [];
      }
      final genreFilter = sectionInfo.sortAndFilterConfiguration.filters.firstWhereOrNull(
        (x) => x.type == ItemFilterType.genreFilter,
      );
      final searchFilter = sectionInfo.sortAndFilterConfiguration.filters.firstWhereOrNull(
        (x) => x.type == ItemFilterType.searchTerm,
      );
      return jellyfinApiHelper.getItems(
        libraryFilter: library,
        parentItem: sectionInfo.contentType == ContentType.playlists ? null : library,
        includeItemTypes: [sectionInfo.contentType.itemType?.jellyfinName].join(","),
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
                  throw UnimplementedError(), //TODO properly handle the "NameStartsWith" filter in the API helper
                ItemFilterType.genreFilter => null,
                ItemFilterType.searchTerm => null,
                ItemFilterType.isUnplayed => "IsUnplayed",
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
        artistType: switch (sectionInfo.contentType) {
          ContentType.albumArtists => ArtistType.albumArtist,
          ContentType.performingArtists => ArtistType.artist,
          _ => null,
        },
        genreFilter: genreFilter?.extraBaseItem.id,
      );
    case HomeScreenSectionType.collection:
      // TODO should tabviews be collections with library parents?  Or does that just make our job harder?
      // TODO we need to actually respect limit/offset for playback and display to work
      final baseItem = await ref.watch(itemByIdProvider(sectionInfo.itemId! as BaseItemId).future);
      if (baseItem == null) {
        return [];
      }
      switch (BaseItemDtoType.fromItem(baseItem)) {
        case BaseItemDtoType.artist:
          // This collection type currently does not support offsets.
          if (startIndex > 0) {
            return [];
          }
          // TODO allow filters and whatnot to be applied?
          return ref.watch(getArtistTracksProvider(artist: baseItem).future);
        case BaseItemDtoType.genre:
          // This collection type currently does not support offsets.
          if (startIndex > 0) {
            return [];
          }
          return ref.watch(
            loadHomeSectionItemsProvider(
              sectionInfo: HomeScreenSectionConfiguration(
                type: HomeScreenSectionType.tabView,
                contentType: ContentType.tracks,
                sortAndFilterConfiguration: sectionInfo.sortAndFilterConfiguration.copyWith(genreFilter: baseItem),
                itemId: sectionInfo.itemId,
              ),
              startIndex: startIndex,
              limit: limit,
            ).future,
          );
        case BaseItemDtoType.album:
        case BaseItemDtoType.playlist:
          // This collection type currently does not support offsets.
          if (startIndex > 0) {
            return [];
          }
          // Only show playable tracks in home screen sections
          return ref
              .watch(getSortedPlaylistTracksProvider(baseItem, sectionInfo.sortAndFilterConfiguration).future)
              .then((x) => x.$2);
        // TODO make real collection provider when removing collection section type code in refactor.
        case BaseItemDtoType.collection:
          return jellyfinApiHelper.getItems(
            parentItem: baseItem,
            recursive: false, //!!! prevent loading tracks and albums from inside the collection items
            sortBy: sectionInfo.sortAndFilterConfiguration.sortBy.jellyfinName(sectionInfo.contentType),
            sortOrder: sectionInfo.sortAndFilterConfiguration.sortOrder.toString(),
            filters: sectionInfo.sortAndFilterConfiguration.filters
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
            includeItemTypes: sectionInfo.contentType.itemType?.jellyfinName,
            startIndex: startIndex,
            limit: limit,
          );
        case _:
          throw UnimplementedError();
      }
    case HomeScreenSectionType.queues:
      throw UnimplementedError("Queue sections should be handled directly");
  }
}

Future<List<BaseItemDto>?> loadHomeSectionItemsOffline({
  required Ref ref,
  required HomeScreenSectionConfiguration sectionInfo,
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

  BaseItemId? libraryId;
  if (sectionInfo.itemId == allLibraryPlaceholder) {
    libraryId = null;
  } else if (sectionInfo.itemId == currentLibraryPlaceholder) {
    libraryId = ref.watch<BaseItemId?>(
      FinampUserHelper.finampCurrentUserProvider.select((value) => value?.currentView?.id),
    );
    if (libraryId == null) {
      return [];
    }
  } else {
    libraryId = sectionInfo.itemId as BaseItemId;
  }

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
      if (sectionInfo.contentType == ContentType.tracks) {
        // tracks are not stored as collections, so we need to get them differently
        offlineItems = await downloadsService.getAllTracks(
          nameFilter: searchFilter?.extraString.trim(),
          viewFilter: libraryId,
          nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
          onlyFavorites: sectionInfo.sortAndFilterConfiguration.filters.any(
            (filter) => filter.type == ItemFilterType.isFavorite,
          ),
          genreFilter: genreFilter?.extraBaseItem.id,
        );
      } else {
        offlineItems = await downloadsService.getAllCollections(
          nameFilter: searchFilter?.extraString.trim(),
          includeItemTypes: [
            sectionInfo.contentType.itemType ?? BaseItemDtoType.album,
          ], //FIXME support allowing multiple types
          // TODO use the filter config for this instead of global(several places)?
          fullyDownloaded: ref.watch(finampSettingsProvider.onlyShowFullyDownloaded),
          viewFilter: libraryId,
          childViewFilter: [ContentType.albums, ContentType.playlists].contains(sectionInfo.contentType)
              ? null
              : libraryId,
          nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
          onlyFavorites: sectionInfo.sortAndFilterConfiguration.filters.any(
            (filter) => filter.type == ItemFilterType.isFavorite,
          ),
          infoForType: switch (sectionInfo.contentType) {
            ContentType.albumArtists => BaseItemDtoType.album,
            ContentType.performingArtists => BaseItemDtoType.track,
            _ => null,
          },
          genreFilter: sectionInfo.contentType == ContentType.playlists ? null : genreFilter?.extraBaseItem.id,
        );
      }
      break;
    case HomeScreenSectionType.collection:
      // TODO rearrange stuff.  This is all copied from online version except collection handling.
      final baseItem = ref.watch(itemByIdProvider(libraryId!)).valueOrNull;
      if (baseItem == null) {
        return [];
      }
      switch (BaseItemDtoType.fromItem(baseItem)) {
        case BaseItemDtoType.artist:
          // This collection type currently does not support offsets.
          if (startIndex > 0) {
            return [];
          }
          // TODO allow filters and whatnot to be applied?
          return ref.watch(getArtistTracksProvider(artist: baseItem).future);
        case BaseItemDtoType.genre:
          // This collection type currently does not support offsets.
          if (startIndex > 0) {
            return [];
          }
          return ref.watch(
            loadHomeSectionItemsProvider(
              sectionInfo: HomeScreenSectionConfiguration(
                type: HomeScreenSectionType.tabView,
                contentType: ContentType.tracks,
                sortAndFilterConfiguration: sectionInfo.sortAndFilterConfiguration.copyWith(genreFilter: baseItem),
                itemId: sectionInfo.itemId,
              ),
              startIndex: startIndex,
              limit: limit,
            ).future,
          );
        case BaseItemDtoType.album:
        case BaseItemDtoType.playlist:
          // This collection type currently does not support offsets.
          if (startIndex > 0) {
            return [];
          }
          // Only show playable tracks in home screen sections
          return ref
              .watch(getSortedPlaylistTracksProvider(baseItem, sectionInfo.sortAndFilterConfiguration).future)
              .then((x) => x.$2);
        case BaseItemDtoType.collection:
          // TODO I don't think the downloads system can actually handle collections?
          offlineItems = await downloadsService.getAllCollections(
            relatedTo: baseItem,
            fullyDownloaded: sectionInfo.sortAndFilterConfiguration.filters.any(
              (filter) => filter.type == ItemFilterType.isFullyDownloaded,
            ),
            //TODO collections are cross-library - should we really filter by library here?
            viewFilter: libraryId,
            childViewFilter: null,
            nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
            onlyFavorites:
                sectionInfo.sortAndFilterConfiguration.filters.any(
                  (filter) => filter.type == ItemFilterType.isFavorite,
                ) &&
                ref.watch(finampSettingsProvider.trackOfflineFavorites),
          );
        case _:
          throw UnimplementedError();
      }
    case HomeScreenSectionType.queues:
      throw UnimplementedError("Queue sections should be handled directly");
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

  if (items.isNotEmpty && genreFilter != null && sectionInfo.contentType == ContentType.playlists) {
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
          throw UnimplementedError(
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
  final context = GlobalSnackbar.materialAppScaffoldKey.currentContext!;
  switch (section.type) {
    case HomeScreenSectionType.tabView:
      final source = QueueItemSource.rawId(
        type: QueueItemSourceType.homeScreenSection,
        name: QueueItemSourceName(
          type: QueueItemSourceNameType.homeScreenSection,
          localizationParameter: section.presetType?.name,
          pretranslatedName: section.getTitle(context),
        ),
        id: section.toLocalisedString(context),
      );
      return MusicScreenPlayable(
        tab: section.contentType,
        library: section.itemId,
        source: source,
        sortConfig: section.sortAndFilterConfiguration,
      );
    case HomeScreenSectionType.collection:
      final item = await ref.watch(itemByIdProvider(section.itemId as BaseItemId).future);
      // TODO better source
      if (item == null) {
        return PrecalculatedPlayable(
          source: QueueItemSource(
            type: QueueItemSourceType.unknown,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.preTranslated,
              pretranslatedName: context.l10n.errorLoadingHomeSection,
            ),
            id: section.itemId as BaseItemId,
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
          pretranslatedName: section.getTitle(context),
        ),
        item: item,
        id: section.toLocalisedString(context),
      );
      switch (BaseItemDtoType.fromItem(item)) {
        case BaseItemDtoType.album:
          return Album(item, source: source);
        case BaseItemDtoType.playlist:
          return Playlist(item, source: source, sortConfig: section.sortAndFilterConfiguration);
        case BaseItemDtoType.noItem:
        case BaseItemDtoType.artist:
        case BaseItemDtoType.genre:
        case BaseItemDtoType.track:
        case BaseItemDtoType.library:
        case BaseItemDtoType.folder:
        case BaseItemDtoType.musicVideo:
        case BaseItemDtoType.audioBook:
        case BaseItemDtoType.tvEpisode:
        case BaseItemDtoType.video:
        case BaseItemDtoType.movie:
        case BaseItemDtoType.trailer:
        case BaseItemDtoType.collection:
        case BaseItemDtoType.unknown:
          throw UnimplementedError();
      }
    case HomeScreenSectionType.queues:
      final source = QueueItemSource.rawId(
        type: QueueItemSourceType.homeScreenSection,
        name: QueueItemSourceName(
          type: QueueItemSourceNameType.homeScreenSection,
          localizationParameter: section.presetType?.name,
          pretranslatedName: section.getTitle(context),
        ),
        id: section.toLocalisedString(context),
      );
      return LatestQueues(sortConfig: section.sortAndFilterConfiguration, source: source);
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
    case MusicScreenPlayable<FinampPlayableItem>():
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
  }
}

Future<List<BaseItemDto>> _getPagedChildTracks(
  Ref ref, {
  required MusicScreenPlayable<FinampPlayableItem> item,
  required int startingChild,
  required int trackLimit,
  required bool hardLimit,
}) async {
  // Drop normal child size by half to reduce the odds of undershooting.  Clamps to a minimum expected child size of one.
  int childLimit = (trackLimit / min(1.0, item.normalChildSize / 2.0)).ceil();
  final pager = ref.read(pagedContentProvider(item).notifier);
  final children = await pager.loadSlice(startingChild, childLimit);
  final output = <BaseItemDto>[];
  for (final rawChild in children) {
    // We require a MusicScreenPlayable<FinampPlayableItem> as input, so all children are guaranteed to be FinampPlayableItems.
    final child = rawChild as FinampPlayableItem;
    switch (child) {
      case FinampUnpagedDisplayable<Track> unpagged:
        final tracks = await getChildTracks(ref, item: unpagged);
        output.addAll(tracks.map((x) => x.item));
      case Track track:
        output.add(track.item);
      case InstantMix():
        throw UnsupportedError("Music screen should not be including instant mix.");
    }
    if (output.length > trackLimit) {
      break;
    }
  }
  return output.slice(0, hardLimit ? min(trackLimit, output.length) : null);
}

@riverpod
Future<List<Track>> getChildTracks(Ref ref, {required FinampUnpagedDisplayable<Track> item}) async {
  switch (item) {
    case Album():
      final items = await ref.watch(getAlbumOrPlaylistTracksProvider(item.item).future);
      // TODO handle playable vs non-playable tracks better.  Maybe track + playableTrack types?
      return items.$2.map((baseItem) => Track(baseItem, source: item.source)).toList();
    case AlbumDisc():
      return item.tracks.map((baseItem) => Track(baseItem, source: item.source)).toList();
    case PrecalculatedPlayable():
      return item.tracks.map((baseItem) => Track(baseItem, source: item.source)).toList();
    case Playlist():
      final items = await ref.watch(getSortedPlaylistTracksProvider(item.item, item.sortConfig).future);
      return items.$2.map((baseItem) => Track(baseItem, source: item.source)).toList();
    case GenericPlayableItem():
      final items = await loadChildTracksFromBaseItem(item: item.item, sortConfig: item.sortConfig);
      return items.map((baseItem) => Track(baseItem, source: item.source)).toList();
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
