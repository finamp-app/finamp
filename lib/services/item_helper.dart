import 'dart:math';

import 'package:collection/collection.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/album_screen_provider.dart';
import 'package:finamp/services/artist_content_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

Future<List<BaseItemDto>> loadChildTracks({
  required PlayableItem item,
  BaseItemDto? genreFilter,
  bool shuffleGenreAlbums = false,
}) {
  switch (item) {
    case AlbumDisc():
      return Future.value(item.tracks);
    case BaseItemDto():
      if (shuffleGenreAlbums) {
        return loadChildTracksFromShuffledGenreAlbums(baseItem: item);
      }
      return loadChildTracksFromBaseItem(baseItem: item, genreFilter: genreFilter);
  }
}

Future<List<BaseItemDto>> loadChildTracksFromBaseItem({
  required BaseItemDto baseItem,
  BaseItemDto? genreFilter,
  bool onlyFavorites = false,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final settings = FinampSettingsHelper.finampSettings;
  final ref = GetIt.instance<ProviderContainer>();

  final Future<List<BaseItemDto>?> newItemsFuture;

  if (settings.isOffline) {
    newItemsFuture = loadChildTracksOffline(baseItem: baseItem, genreFilter: genreFilter, onlyFavorites: onlyFavorites);
  } else {
    switch (BaseItemDtoType.fromItem(baseItem)) {
      case BaseItemDtoType.track:
        newItemsFuture = Future.value([baseItem]);
        break;
      case BaseItemDtoType.album:
        newItemsFuture = ref
            .read(getAlbumOrPlaylistTracksProvider(baseItem).future)
            .then((value) => value.$2); // get playable tracks
      case BaseItemDtoType.playlist:
        newItemsFuture = ref
            .read(getSortedPlaylistTracksProvider(baseItem, genreFilter: genreFilter).future)
            .then((value) => value.$2); // get playable tracks
        break;
      case BaseItemDtoType.artist:
        newItemsFuture = ref.read(
          getArtistTracksProvider(
            artist: baseItem,
            libraryFilter: finampUserHelper.currentUser?.currentView,
            genreFilter: genreFilter,
            onlyFavorites: onlyFavorites,
          ).future,
        );
        break;
      case BaseItemDtoType.genre:
        newItemsFuture = jellyfinApiHelper.getItems(
          parentItem: finampUserHelper.currentUser?.currentView,
          includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
          limit: FinampSettingsHelper.finampSettings.trackShuffleItemCount,
          genreFilter: baseItem,
          isFavorite: onlyFavorites,
          sortBy: "Random", // important, as we load limited tracks and otherwise would always get the same
        );
        break;
      default:
        newItemsFuture = jellyfinApiHelper.getItems(
          parentItem: baseItem,
          includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
          sortBy: "ParentIndexNumber,IndexNumber,SortName",
          sortOrder: null,
          genreFilter: genreFilter,
          isFavorite: onlyFavorites,
          // filters: settings.onlyShowFavorites ? "IsFavorite" : null,
        );
    }
  }

  final List<BaseItemDto>? newItems = await newItemsFuture;

  if (newItems == null) {
    GlobalSnackbar.message(
      (scaffold) => AppLocalizations.of(scaffold)!.couldNotLoad(BaseItemDtoType.fromItem(baseItem).name),
    );
    return [];
  }

  if (BaseItemDtoType.fromItem(baseItem) == BaseItemDtoType.artist) {
    return sortArtistTracks(newItems);
  }

  return newItems;
}

List<BaseItemDto> groupItems({
  required List<BaseItemDto> items,
  required String? Function(BaseItemDto) groupListBy,
  bool manuallyShuffle = false,
}) {
  var albums = items.groupListsBy(groupListBy).values.toList();
  if (manuallyShuffle) {
    albums = albums..shuffle();
  }
  return albums.flattened.toList();
}

Future<List<BaseItemDto>?> loadChildTracksOffline({
  required BaseItemDto baseItem,
  int? limit,
  BaseItemDto? genreFilter,
  bool onlyFavorites = false,
}) async {
  final downloadsService = GetIt.instance<DownloadsService>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final settings = FinampSettingsHelper.finampSettings;

  List<BaseItemDto> items;

  switch (BaseItemDtoType.fromItem(baseItem)) {
    case BaseItemDtoType.track:
      items = [baseItem];
      break;
    case BaseItemDtoType.genre:
      items = (await downloadsService.getAllTracks(
        viewFilter: finampUserHelper.currentUser?.currentView?.id,
        genreFilter: baseItem,
        nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
        onlyFavorites: onlyFavorites,
      )).map((e) => e.baseItem!).toList();
      items.shuffle();
      if (items.length - 1 > settings.trackShuffleItemCount) {
        items = items.sublist(0, settings.trackShuffleItemCount);
      }
      break;
    case BaseItemDtoType.playlist:
      items = await GetIt.instance<ProviderContainer>()
          .read(getSortedPlaylistTracksProvider(baseItem, genreFilter: genreFilter).future)
          .then((value) => value.$2); // get playable tracks
    case BaseItemDtoType.artist:
      items = await GetIt.instance<ProviderContainer>().read(
        getArtistTracksProvider(
          artist: baseItem,
          libraryFilter: finampUserHelper.currentUser?.currentView,
          genreFilter: genreFilter,
          onlyFavorites: onlyFavorites,
        ).future,
      );
      items = sortArtistTracks(items);
      break;
    default:
      items = await downloadsService.getCollectionTracks(baseItem, playable: true, genreFilter: genreFilter);
      break;
  }

  return (limit != null ? items.take(limit) : items).toList();
}

Future<List<BaseItemDto>> loadChildTracksFromShuffledGenreAlbums({required BaseItemDto baseItem}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();
  final ref = GetIt.instance<ProviderContainer>();
  final settings = FinampSettingsHelper.finampSettings;

  List<BaseItemDto> newItems = [];

  // We fetch as many albums as the track limit allows (just in case there are only singles)
  // but we have to apply a fixed upper limit of 200 albums as we could get
  // a 414 error (request uri too long) in step 2 (fetching the tracks) otherwise.
  final albumLimit = min(settings.trackShuffleItemCount, 200);
  int totalTrackLimit = settings.trackShuffleItemCount;

  if (settings.isOffline) {
    // Offline Mode
    List<DownloadStub> fetchedGenreAlbums = await downloadsService.getAllCollections(
      baseTypeFilter: BaseItemDtoType.album,
      fullyDownloaded: ref.read(finampSettingsProvider.onlyShowFullyDownloaded),
      viewFilter: finampUserHelper.currentUser?.currentView?.id,
      childViewFilter: finampUserHelper.currentUser?.currentView?.id,
      nullableViewFilters: ref.read(finampSettingsProvider.showDownloadsWithUnknownLibrary),
      genreFilter: baseItem,
    );
    var genreAlbums = fetchedGenreAlbums.map((e) => e.baseItem).nonNulls.toList();
    genreAlbums = sortItems(genreAlbums, SortBy.random, SortOrder.descending);
    genreAlbums = genreAlbums.take(albumLimit).toList();

    // Load Tracks of Albums
    for (final album in genreAlbums) {
      // We stop if the totalTrackLimit is reached
      if (totalTrackLimit <= 0) break;

      List<BaseItemDto> playableAlbumTracks = await downloadsService.getCollectionTracks(album, playable: true);
      if (playableAlbumTracks.isEmpty) continue;

      // We don't add the album if it would exceed the totalTrackLimit
      if (totalTrackLimit - playableAlbumTracks.length < 0) break;

      // Add the tracks and decrease the total limit
      newItems.addAll(playableAlbumTracks);
      totalTrackLimit -= playableAlbumTracks.length;
    }
  } else {
    // Online Mode
    List<BaseItemDto>? genreAlbums =
        await jellyfinApiHelper.getItems(
          parentItem: finampUserHelper.currentUser?.currentView,
          includeItemTypes: [BaseItemDtoType.album.jellyfinName].join(","),
          limit: albumLimit,
          genreFilter: baseItem,
          sortBy: "Random", // important, as we load limited albums and otherwise would always get the same
        ) ??
        [];

    List<BaseItemId> albumIds = genreAlbums.map((album) => album.id).toList();

    // Load Tracks of Albums
    List<BaseItemDto>? newAlbumTracks =
        await jellyfinApiHelper.getItems(
          albumIds: albumIds,
          includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
          sortBy: "Album,ParentIndexNumber,IndexNumber,SortName",
          // here we fetch one additional track to later check if the last album fits perfectly in the limit or if it exceeds it and has to be removed:
          limit: totalTrackLimit + 1,
        ) ??
        [];

    // Check if we exceeded the totalTrackLimit
    if (newAlbumTracks.length > totalTrackLimit) {
      final trimmedAlbumIds = List<BaseItemId>.from(albumIds);

      while (newAlbumTracks.length > totalTrackLimit && trimmedAlbumIds.isNotEmpty) {
        // Get the last albumId
        final lastAlbumId = trimmedAlbumIds.removeLast();
        // Remove all tracks that belong to this album
        newAlbumTracks.removeWhere((track) => track.albumId == lastAlbumId);
      }
    }

    // Add the tracks and decrease the total limit
    newItems.addAll(newAlbumTracks);
  }

  if (newItems.isEmpty) {
    GlobalSnackbar.message(
      (scaffold) => AppLocalizations.of(scaffold)!.couldNotLoad(BaseItemDtoType.fromItem(baseItem).name),
    );
  }

  return newItems;
}
