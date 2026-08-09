import 'dart:async';

import 'package:finamp/models/finamp_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../components/MusicScreen/sort_and_filter_row.dart';
import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'jellyfin_api_helper.dart';
import 'music_screen_provider.dart';

part 'album_screen_provider.g.dart';

// Get the Tracks of an Album or Playlist
@riverpod
Future<(List<BaseItemDto>, List<BaseItemDto>)> getAlbumOrPlaylistTracks(Ref ref, BaseItemDto parent) async {
  JellyfinApiHelper jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
  List<BaseItemDto> allTracks;
  List<BaseItemDto> playableTracks;

  if (isOffline) {
    final downloadsService = GetIt.instance<DownloadsService>();
    allTracks = await downloadsService.getCollectionTracks(parent, playable: false);
    playableTracks = await downloadsService.getCollectionTracks(parent, playable: true);
  } else {
    allTracks =
        await jellyfinApiHelper.getItems(
          parentItem: parent,
          sortBy: "ParentIndexNumber,IndexNumber,SortName",
          includeItemTypes: "Audio",
        ) ??
        [];
    playableTracks = allTracks;
  }

  return (allTracks, playableTracks);
}

SortAndFilterController _defaultPlaylistSort = SortAndFilterController.trackSettings(ContentType.inPlaylist);

@riverpod
Future<(List<BaseItemDto>, List<BaseItemDto>)> getDefaultSortedPlaylistTracks(Ref ref, BaseItemDto parent) {
  final sortConfig = ref.watch(resolveSortProvider(_defaultPlaylistSort));
  return ref.watch(getSortedPlaylistTracksProvider(parent, sortConfig).future);
}

// Get sorted Tracks of a playlist
@riverpod
Future<(List<BaseItemDto>, List<BaseItemDto>)> getSortedPlaylistTracks(
  Ref ref,
  BaseItemDto parent,
  ResolvedSortConfig sortConfig,
) async {
  List<BaseItemDto> playlistAllTracksSorted;
  List<BaseItemDto> playlistPlayableTracksSorted;
  SortOrder playlistSortOrder = sortConfig.sortOrder;
  SortBy playlistSortBy = sortConfig.sortBy;
  final genreFilter = sortConfig.genreFilter;
  // TODO can we, and do we want to, support other filter config options?

  // Get Playlist Items
  final result = await ref.watch(getAlbumOrPlaylistTracksProvider(parent).future);
  final playlistAllTracks = result.$1;
  final playlistPlayableTracks = result.$2;

  if (playlistSortBy == SortBy.defaultOrder) {
    playlistAllTracksSorted = (playlistSortOrder == SortOrder.descending)
        ? playlistAllTracks.reversed.toList()
        : playlistAllTracks;
  } else {
    // Unfortunately, the Jellyfin API does not support "sortBy"
    // for the "/Playlists/{playlistId}/Items" endpoint, so we
    // use our own sortItems function for both online and offline
    final playlistAllTracksCopy = List<BaseItemDto>.from(playlistAllTracks);
    playlistAllTracksSorted = sortItems(playlistAllTracksCopy, playlistSortBy, playlistSortOrder);
  }

  // The playlist api endpoint and fully downloaded playlists do not allow
  // to filter by genre, so we have to do that manually on device
  if (genreFilter != null && BaseItemDtoType.fromItem(parent) == BaseItemDtoType.playlist) {
    playlistAllTracksSorted = playlistAllTracksSorted.where((track) {
      return track.genreItems?.any((g) => g.id == genreFilter.id) ?? false;
    }).toList();
  }

  if (sortConfig.favoritesFilter) {
    playlistAllTracksSorted = playlistAllTracksSorted.where((track) {
      return track.userData?.isFavorite ?? true;
    }).toList();
  }

  // We now have to re-create a sorted playableItems from the new items order,
  // because if we would sort both separately, they would diverge for SortBy.random
  final playlistPlayableTracksSet = playlistPlayableTracks.toSet();
  playlistPlayableTracksSorted = playlistAllTracksSorted.where((x) => playlistPlayableTracksSet.contains(x)).toList();

  return (playlistAllTracksSorted, playlistPlayableTracksSorted);
}
