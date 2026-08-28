import 'dart:async';

import 'package:finamp/components/curated_item_filter_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'jellyfin_api_helper.dart';
import 'music_screen_provider.dart';

part 'genre_screen_provider.g.dart';

@riverpod
Future<(List<BaseItemDto>, int, CuratedItemSelectionType, Set<CuratedItemSelectionType>?)> genreCuratedItems(
  Ref ref,
  BaseItemDto parent,
  BaseItemDtoType baseItemType,
  BaseItemDto? library,
) async {
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
  final bool autoSwitchItemCurationTypeEnabled = ref.watch(finampSettingsProvider.autoSwitchItemCurationType);
  final Set<CuratedItemSelectionType> disabledFilters = {};
  final genreCuratedItemSectionFilterOrder = ref.watch(finampSettingsProvider.genreItemSectionFilterChipOrder);
  CuratedItemSelectionType currentSelectionType = handleOfflineFallbackOption(
    isOffline: isOffline,
    currentFilter: (baseItemType == BaseItemDtoType.artist)
        ? ref.watch(finampSettingsProvider.genreCuratedItemSelectionTypeArtists)
        : (baseItemType == BaseItemDtoType.album)
        ? ref.watch(finampSettingsProvider.genreCuratedItemSelectionTypeAlbums)
        : ref.watch(finampSettingsProvider.genreCuratedItemSelectionTypeTracks),
    filterListFor: baseItemType,
    customFilterOrder: genreCuratedItemSectionFilterOrder,
  );
  final defaultArtistType = ref.watch(finampSettingsProvider.defaultArtistType);
  final artistInfoForType = (defaultArtistType == ArtistType.albumArtist)
      ? BaseItemDtoType.album
      : BaseItemDtoType.track;

  Future<(List<BaseItemDto>, int)> fetchItems(CuratedItemSelectionType selectionType) async {
    if (isOffline) {
      final result = await getCuratedItemsOffline(
        ref: ref,
        parent: parent,
        genreCuratedItemSelectionType: selectionType,
        baseItemType: baseItemType,
        library: library,
        artistInfoForType: (baseItemType == BaseItemDtoType.artist) ? artistInfoForType : null,
      );
      return (result.$1, result.$2);
    } else {
      final result = await getCuratedItemsOnline(
        parent: parent,
        genreCuratedItemSelectionType: selectionType,
        baseItemType: baseItemType,
        library: library,
        sortBySecondary: (baseItemType == BaseItemDtoType.album) ? "PremiereDate,SortName" : "SortName",
        artistType: (baseItemType == BaseItemDtoType.artist) ? defaultArtistType : null,
      );
      return (result.$1, result.$2);
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
  var filteredResult = filterResult(result.$1, currentSelectionType);

  while (autoSwitchItemCurationTypeEnabled &&
      filteredResult.isEmpty &&
      (currentSelectionType == CuratedItemSelectionType.favorites ||
          currentSelectionType == CuratedItemSelectionType.mostPlayed ||
          currentSelectionType == CuratedItemSelectionType.recentlyPlayed)) {
    // Add the currentSelectionType to a Set of disabled types
    disabledFilters.add(currentSelectionType);
    // Get next Fallback
    CuratedItemSelectionType newSelectionType = getFallbackFilterOption(
      isOffline: isOffline,
      currentType: currentSelectionType,
      filterListFor: baseItemType,
      customFilterOrder: genreCuratedItemSectionFilterOrder,
      disabledFilters: disabledFilters,
    );
    // Break if we are cycling without new options
    if (newSelectionType == currentSelectionType) break;
    // Call fetchItems again with the newSelectionType
    currentSelectionType = newSelectionType;
    result = await fetchItems(currentSelectionType);
    filteredResult = filterResult(result.$1, currentSelectionType);
  }

  return (filteredResult, result.$2, currentSelectionType, disabledFilters);
}

Future<(List<BaseItemDto>, int)> getCuratedItemsOnline({
  required BaseItemDto parent,
  required CuratedItemSelectionType genreCuratedItemSelectionType,
  required BaseItemDtoType baseItemType,
  BaseItemDto? library,
  String? sortBySecondary,
  ArtistType? artistType,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final sortBy = genreCuratedItemSelectionType.getSortBy();
  ContentType tabType = switch (baseItemType) {
    BaseItemDtoType.album => ContentType.albums,
    BaseItemDtoType.artist => ContentType.performingArtists,
    _ => ContentType.tracks,
  };
  int itemCount;

  final fetchedItems = await jellyfinApiHelper.getItemsWithTotalRecordCount(
    parentItem: library,
    genreFilter: parent.id,
    sortBy: sortBy.jellyfinName(tabType),
    sortOrder: "Descending",
    isFavorite: (genreCuratedItemSelectionType == CuratedItemSelectionType.favorites) ? true : null,
    limit: 5,
    includeItemTypes: baseItemType.jellyfinName,
    artistType: (baseItemType == BaseItemDtoType.artist) ? artistType : null,
  );
  // Set the Item Count
  if (genreCuratedItemSelectionType == CuratedItemSelectionType.favorites) {
    // When we filter the favorites, we have to make an additional request to get the correct number
    // otherwise we would only get the totalRecordCount of Favorites of that genre
    final fetchedItemCountWithoutFavorites = await jellyfinApiHelper.getItemsWithTotalRecordCount(
      parentItem: library,
      genreFilter: parent.id,
      limit: 1,
      includeItemTypes: baseItemType.jellyfinName,
      artistType: (baseItemType == BaseItemDtoType.artist) ? artistType : null,
    );
    itemCount = fetchedItemCountWithoutFavorites.totalRecordCount;
  } else {
    itemCount = fetchedItems.totalRecordCount;
  }
  return (fetchedItems.items ?? [], itemCount);
}

Future<(List<BaseItemDto>, int)> getCuratedItemsOffline({
  required Ref ref,
  required BaseItemDto parent,
  required CuratedItemSelectionType genreCuratedItemSelectionType,
  required BaseItemDtoType baseItemType,
  BaseItemDto? library,
  BaseItemDtoType? artistInfoForType,
}) async {
  // The "Most Played" functionality is still here, just in case we find a solution on
  // how we can integrate it properly. But as in the current implementation it might return
  // outdated data, getCuratedItemsOffline currently never gets called with mostPlayed
  final downloadsService = GetIt.instance<DownloadsService>();
  final sortBy = genreCuratedItemSelectionType.getSortBy();

  final listener = GetIt.instance<DownloadsService>().offlineDeletesStream.listen((_) => ref.invalidateSelf());
  ref.onDispose(() => listener.cancel());

  final List<DownloadStub> fetchedItems = (baseItemType == BaseItemDtoType.track)
      ? await downloadsService.getAllTracks(
          viewFilter: library?.id,
          nullableViewFilters: ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
          onlyFavorites: (genreCuratedItemSelectionType == CuratedItemSelectionType.favorites)
              ? ref.watch(finampSettingsProvider.trackOfflineFavorites)
              : false,
          genreFilter: parent.id,
        )
      : await downloadsService.getAllCollections(
          includeItemTypes: [baseItemType],
          fullyDownloaded: ref.watch(finampSettingsProvider.onlyShowFullyDownloaded),
          viewFilter: (baseItemType == BaseItemDtoType.album) ? library?.id : null,
          childViewFilter: (baseItemType != BaseItemDtoType.album && baseItemType != BaseItemDtoType.playlist)
              ? library?.id
              : null,
          nullableViewFilters:
              (baseItemType == BaseItemDtoType.album) &&
              ref.watch(finampSettingsProvider.showDownloadsWithUnknownLibrary),
          onlyFavorites: (genreCuratedItemSelectionType == CuratedItemSelectionType.favorites)
              ? ref.watch(finampSettingsProvider.trackOfflineFavorites)
              : false,
          infoForType: (baseItemType == BaseItemDtoType.artist) ? artistInfoForType : null,
          genreFilter: parent.id,
        );
  var items = fetchedItems.map((e) => e.baseItem).nonNulls.toList();
  var itemCount = items.length;
  items = sortItems(items, sortBy, SortOrder.descending);
  items = items.take(5).toList();
  // When we filter the favorites, we have to make an additional request to get the correct number
  // otherwise we would only get the count of Favorites of that genre
  if (genreCuratedItemSelectionType == CuratedItemSelectionType.favorites) {
    final List<DownloadStub> allFetchedItems = (baseItemType == BaseItemDtoType.track)
        ? await downloadsService.getAllTracks(
            nullableViewFilters: ref.read(finampSettingsProvider.showDownloadsWithUnknownLibrary),
            genreFilter: parent.id,
          )
        : await downloadsService.getAllCollections(
            includeItemTypes: [baseItemType],
            fullyDownloaded: ref.read(finampSettingsProvider.onlyShowFullyDownloaded),
            infoForType: (baseItemType == BaseItemDtoType.artist) ? artistInfoForType : null,
            genreFilter: parent.id,
          );
    var allItems = allFetchedItems.map((e) => e.baseItem).nonNulls.toList();
    itemCount = allItems.length;
  }
  return (items, itemCount);
}
