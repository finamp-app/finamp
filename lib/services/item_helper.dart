import 'package:collection/collection.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../menus/track_menu.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../screens/genre_screen.dart';
import '../screens/music_screen.dart';
import 'music_screen_provider.dart';

// TODO remove this and use getSliceProvider for all cases.
Future<List<BaseItemDto>> loadChildTracksFromBaseItem({
  required BaseItemDto item,
  required ResolvedSortConfig sortConfig,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final settings = FinampSettingsHelper.finampSettings;
  final ref = GetIt.instance<ProviderContainer>();

  final Future<List<BaseItemDto>?> newItemsFuture;

  if (settings.isOffline) {
    newItemsFuture = loadChildTracksOffline(item: item, sortConfig: sortConfig);
  } else {
    switch (BaseItemDtoType.fromItem(item)) {
      case BaseItemDtoType.track:
        newItemsFuture = Future.value([item]);
        break;
      case BaseItemDtoType.album:
        newItemsFuture = ref
            .read(getAlbumOrPlaylistTracksProvider(item).future)
            .then((value) => value.$2); // get playable tracks
      case BaseItemDtoType.playlist:
        newItemsFuture = ref
            .read(getSortedPlaylistTracksProvider(item, sortConfig).future)
            .then((value) => value.$2); // get playable tracks
        break;
      case BaseItemDtoType.artist:
        newItemsFuture = ref.read(
          getArtistTracksProvider(
            artist: item,
            libraryFilter: finampUserHelper.currentUser?.currentViewId,
            genreFilter: sortConfig.genreFilter?.id,
          ).future,
        );
        break;
      case BaseItemDtoType.genre:
        newItemsFuture = jellyfinApiHelper.getItems(
          parentItem: finampUserHelper.currentUser?.currentView,
          includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
          limit: FinampSettingsHelper.finampSettings.trackShuffleItemCount,
          genreFilter: item.id,
          sortBy: "Random", // important, as we load limited tracks and otherwise would always get the same
        );
        break;
      default:
        newItemsFuture = jellyfinApiHelper.getItems(
          parentItem: item,
          includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
          sortBy: "ParentIndexNumber,IndexNumber,SortName",
          sortOrder: null,
          genreFilter: sortConfig.genreFilter?.id,
          // filters: settings.onlyShowFavorites ? "IsFavorite" : null,
        );
    }
  }

  final List<BaseItemDto>? newItems = await newItemsFuture;

  if (newItems == null) {
    GlobalSnackbar.message(
      (scaffold) => AppLocalizations.of(scaffold)!.couldNotLoad(BaseItemDtoType.fromItem(item).name),
    );
    return [];
  }

  if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.artist) {
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
  required BaseItemDto item,
  int? limit,
  required ResolvedSortConfig sortConfig,
}) async {
  final downloadsService = GetIt.instance<DownloadsService>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final settings = FinampSettingsHelper.finampSettings;

  List<BaseItemDto> items;

  switch (BaseItemDtoType.fromItem(item)) {
    case BaseItemDtoType.track:
      items = [item];
      break;
    case BaseItemDtoType.genre:
      items = (await downloadsService.getAllTracks(
        viewFilter: finampUserHelper.currentUser?.currentView?.id,
        genreFilter: item.id,
        nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
      )).map((e) => e.baseItem!).toList();
      items.shuffle();
      if (items.length - 1 > settings.trackShuffleItemCount) {
        items = items.sublist(0, settings.trackShuffleItemCount);
      }
      break;
    case BaseItemDtoType.playlist:
      items = await GetIt.instance<ProviderContainer>()
          .read(getSortedPlaylistTracksProvider(item, sortConfig).future)
          .then((value) => value.$2); // get playable tracks
    case BaseItemDtoType.artist:
      items = await GetIt.instance<ProviderContainer>().read(
        getArtistTracksProvider(
          artist: item,
          libraryFilter: finampUserHelper.currentUser?.currentViewId,
          genreFilter: sortConfig.genreFilter?.id,
        ).future,
      );
      items = sortArtistTracks(items);
      break;
    default:
      items = await downloadsService.getCollectionTracks(item, playable: true, genreFilter: sortConfig.genreFilter?.id);
      break;
  }

  return (limit != null ? items.take(limit) : items).toList();
}

//TODO only push a route if the item is not already open in the current route (e.g. if we're showing an album menu from the album screen, we shouldn't push another album screen for the same album) but close the menu instead
void openItemPage(BaseItemDto item, NavigatorState navigator, {bool showTracks = false}) {
  if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.track) {
    if (showTracks) {
      showModalTrackMenu(context: navigator.context, item: item);
    }
    return;
  } else if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.collection) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    navigator.push(
      MaterialPageRoute<MusicScreen>(
        builder: (context) => MusicScreen(
          singleTabConfig: HomeScreenSectionConfiguration(
            base: CollectionHomeSection(
              itemId: item.id,
              libraryId: finampUserHelper.currentUser!.currentViewId!,
              contentType: ContentType.mixed,
            ),
            customSectionTitle: item.name ?? AppLocalizations.of(context)!.unknownName,
            sortConfig: SortAndFilterConfiguration.defaultSort,
          ),
        ),
      ),
    );
    return;
  }
  final targetRoute = switch (BaseItemDtoType.fromItem(item)) {
    BaseItemDtoType.album => AlbumScreen.routeName,
    BaseItemDtoType.playlist => AlbumScreen.routeName,
    BaseItemDtoType.genre => GenreScreen.routeName,
    BaseItemDtoType.artist => ArtistScreen.routeName,
    _ => AlbumScreen.routeName,
  };
  navigator.pushNamed(targetRoute, arguments: item);
}
