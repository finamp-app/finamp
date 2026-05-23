import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'audio_service_helper.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api_helper.dart';
import 'music_screen_provider.dart';
import 'queue_service.dart';

class AndroidAutoSearchQuery {
  String rawQuery;
  Map<String, dynamic>? extras;

  AndroidAutoSearchQuery(this.rawQuery, this.extras);
}

class AndroidAutoHelper {
  static final _androidAutoHelperLogger = Logger("AndroidAutoHelper");

  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _downloadsService = GetIt.instance<DownloadsService>();

  // actively remembered search query because Android Auto doesn't give us the extras during a regular search (e.g. clicking the "Search Results" button on the player screen after a voice search)
  AndroidAutoSearchQuery? _lastSearchQuery;

  void setLastSearchQuery(AndroidAutoSearchQuery? searchQuery) {
    _lastSearchQuery = searchQuery;
  }

  AndroidAutoSearchQuery? get lastSearchQuery => _lastSearchQuery;

  Future<BaseItemDto?> getParentFromId(BaseItemId parentId) async {
    final downloadedParent = await _downloadsService.getCollectionInfo(id: parentId);
    if (downloadedParent != null) {
      return downloadedParent.baseItem;
    } else if (FinampSettingsHelper.finampSettings.isOffline) {
      return null;
    }

    return await _jellyfinApiHelper.getItemById(parentId);
  }

  Future<List<BaseItemDto>> getBaseItems(MediaItemId itemId) async {
    // limit amount so it doesn't crash / take forever on large libraries
    const onlineModeLimit = 250;
    const offlineModeLimit = 1000;

    final sortBy = FinampSettingsHelper.finampSettings.getTabSortBy(itemId.contentType);
    final sortOrder = FinampSettingsHelper.finampSettings.getSortOrder(itemId.contentType);

    // if we are in offline mode and in root parent/collection, display all matching downloaded parents
    if (FinampSettingsHelper.finampSettings.isOffline && itemId.parentType == MediaItemParentType.rootCollection) {
      List<BaseItemDto> baseItems = [];
      for (final downloadedParent in await _downloadsService.getAllCollections()) {
        if (baseItems.length >= offlineModeLimit) break;
        if (downloadedParent.baseItem != null && downloadedParent.baseItemType == itemId.contentType.itemType) {
          baseItems.add(downloadedParent.baseItem!);
        }
      }
      return sortItems(baseItems, sortBy, sortOrder);
    }

    // use downloaded parent only in offline mode
    // otherwise we only play downloaded tracks from albums/collections, not all of them
    // downloaded tracks will be played from device when resolving them to media items
    if (FinampSettingsHelper.finampSettings.isOffline && itemId.parentType == MediaItemParentType.collection) {
      if (itemId.contentType == ContentType.genres) {
        final genreBaseItem = await getParentFromId(itemId.itemId!);

        final List<BaseItemDto> genreAlbums = (await _downloadsService.getAllCollections(
          includeItemTypes: [BaseItemDtoType.album],
          relatedTo: genreBaseItem,
        )).toList().map((e) => e.baseItem).whereNotNull().toList();
        genreAlbums.sort((a, b) => (a.premiereDate ?? "").compareTo(b.premiereDate ?? ""));
        return genreAlbums;
      } else if (itemId.contentType.isArtist) {
        final artistBaseItem = await getParentFromId(itemId.itemId!);

        final List<BaseItemDto> artistAlbums = (await _downloadsService.getAllCollections(
          includeItemTypes: [BaseItemDtoType.album],
          relatedTo: artistBaseItem,
        )).toList().map((e) => e.baseItem).whereNotNull().toList();
        artistAlbums.sort((a, b) => (a.premiereDate ?? "").compareTo(b.premiereDate ?? ""));

        final List<BaseItemDto> allTracks = [];
        for (var album in artistAlbums) {
          allTracks.addAll(await _downloadsService.getCollectionTracks(album, playable: true));
        }
        return allTracks;
      } else {
        var downloadedParent = await _downloadsService.getCollectionInfo(id: itemId.itemId);
        if (downloadedParent != null && downloadedParent.baseItem != null) {
          final downloadedItems = await _downloadsService.getCollectionTracks(downloadedParent.baseItem!);
          if (downloadedItems.length >= offlineModeLimit) {
            downloadedItems.removeRange(offlineModeLimit, downloadedItems.length - 1);
          }

          // only sort items if we are not playing them
          return _isPlayable(contentType: itemId.contentType)
              ? downloadedItems
              : sortItems(downloadedItems, sortBy, sortOrder);
        }
      }
    }

    // fetch the online version if we can't get offline version

    // select the item type that each parent holds
    BaseItemDtoType includeItemTypes;
    if (itemId.parentType == MediaItemParentType.collection) {
      // if we are browsing a root library. e.g. browsing the list of all albums or artists
      switch (itemId.contentType) {
        case ContentType.albums:
          // get an album's tracks
          includeItemTypes = ContentType.tracks.itemType!;
          break;
        case ContentType.genericArtists:
        case ContentType.albumArtists:
        case ContentType.performingArtists:
          // get an artist's albums
          includeItemTypes = ContentType.albums.itemType!;
          break;
        case ContentType.playlists:
          // get a playlist's tracks
          includeItemTypes = ContentType.tracks.itemType!;
          break;
        case ContentType.genres:
          // get a genre's albums
          includeItemTypes = ContentType.albums.itemType!;
          break;
        default:
          // if we don't have one of these categories, we are probably dealing with stray tracks
          includeItemTypes = ContentType.tracks.itemType!;
          break;
      }
    } else {
      // get the root library
      includeItemTypes = itemId.contentType.itemType!;
    }

    // if parent id is defined, use that to get items.
    // otherwise, use the current view as fallback to ensure we get the correct items.
    final parentItem = itemId.parentType == MediaItemParentType.collection
        ? BaseItemDto(id: itemId.itemId!, type: itemId.contentType.itemType?.jellyfinName)
        : (itemId.contentType == ContentType.playlists ? null : _finampUserHelper.currentUser?.currentView);

    final items = await _jellyfinApiHelper.getItems(
      parentItem: parentItem,
      sortBy: includeItemTypes == BaseItemDtoType.track
          ? "ParentIndexNumber,IndexNumber,${sortBy.jellyfinName(itemId.contentType)}"
          : sortBy.jellyfinName(itemId.contentType),
      sortOrder: includeItemTypes == BaseItemDtoType.track ? null : sortOrder.toString(),
      includeItemTypes: includeItemTypes.jellyfinName,
      limit: onlineModeLimit,
    );
    return items ?? [];
  }

  Future<List<MediaItem>> getRecentItems() async {
    final queueService = GetIt.instance<QueueService>();
    //TODO this should ideally list recent queues (the restorable ones), or items from the home screen
    try {
      final recentItems = queueService.peekQueue(previous: 5);
      final List<MediaItem> recentMediaItems = [];
      for (final item in recentItems) {
        final mediaItem = await queueService.generateMediaItem(
          item.baseItem,
          parentType: MediaItemParentType.collection,
          isPlayable: _isPlayable,
        );
        recentMediaItems.add(mediaItem);
      }
      return recentMediaItems;
    } catch (err) {
      _androidAutoHelperLogger.severe("Error while getting recent items:", err);
      return [];
    }
  }

  Future<List<MediaItem>> searchItems(AndroidAutoSearchQuery searchQuery) async {
    final queueService = GetIt.instance<QueueService>();

    try {
      final searchFuture = Future.wait([
        _searchPlaylists(searchQuery, limit: 3),
        _searchTracks(searchQuery, limit: 5),
        _searchAlbums(searchQuery, limit: 5),
        _searchArtists(searchQuery, limit: 3),
        _searchGenres(searchQuery, limit: 3),
      ]);

      final [playlistResults, trackResults, albumResults, artistResults, genreResults] = await searchFuture;

      final List<BaseItemDto> allSearchResults = playlistResults
          .followedBy(trackResults)
          .followedBy(albumResults)
          .followedBy(artistResults)
          .followedBy(genreResults)
          .toList();

      final List<MediaItem> mediaItems = [];

      for (final item in allSearchResults) {
        final mediaItem = await queueService.generateMediaItem(
          item,
          parentType: MediaItemParentType.collection,
          parentId: item.parentId,
          isPlayable: _isPlayable,
        );

        // assign a group hint based on the item type, so Android Auto can group search results by type
        switch (item.type) {
          case "Audio":
            mediaItem.extras?["android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT"] =
                GlobalSnackbar.requireL10n.tracks;
            break;
          case "MusicAlbum":
            mediaItem.extras?["android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT"] =
                GlobalSnackbar.requireL10n.albums;
            break;
          case "MusicArtist":
            mediaItem.extras?["android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT"] =
                GlobalSnackbar.requireL10n.artists;
            break;
          case "MusicGenre":
            mediaItem.extras?["android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT"] =
                GlobalSnackbar.requireL10n.genres;
            break;
          case "Playlist":
            mediaItem.extras?["android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT"] =
                GlobalSnackbar.requireL10n.playlists;
            break;
          default:
            break;
        }
        mediaItems.add(mediaItem);
      }
      return mediaItems;
    } catch (err, trace) {
      _androidAutoHelperLogger.severe("Error while searching: ${err.toString()}", err, trace);
      return [];
    }
  }

  Future<void> playFromSearch(AndroidAutoSearchQuery searchQuery) async {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final audioServiceHelper = GetIt.instance<AudioServiceHelper>();
    final queueService = GetIt.instance<QueueService>();

    if (searchQuery.rawQuery.isEmpty) {
      return await shuffleAllTracks();
    }

    BaseItemDtoType? itemType = ContentType.tracks.itemType;
    String? enhancedQuery;
    bool searchForPlaylists = false;

    if (searchQuery.extras?["android.intent.extra.album"] != null &&
        searchQuery.extras?["android.intent.extra.artist"] != null &&
        searchQuery.extras?["android.intent.extra.title"] != null) {
      // if all metadata is provided, search for track
      itemType = ContentType.tracks.itemType;
      enhancedQuery = searchQuery.extras?["android.intent.extra.title"] as String?;
    } else if (searchQuery.extras?["android.intent.extra.album"] != null &&
        searchQuery.extras?["android.intent.extra.artist"] != null &&
        searchQuery.extras?["android.intent.extra.title"] == null) {
      // if only album is provided, search for album
      itemType = ContentType.albums.itemType;
      enhancedQuery = searchQuery.extras?["android.intent.extra.album"] as String?;
    } else if (searchQuery.extras?["android.intent.extra.artist"] != null &&
        searchQuery.extras?["android.intent.extra.title"] == null) {
      // if only artist is provided, search for artist
      itemType = ContentType.performingArtists.itemType;
      enhancedQuery = searchQuery.extras?["android.intent.extra.artist"] as String?;
    } else {
      // if no metadata is provided, search for tracks *and* playlists, preferring playlists
      searchForPlaylists = true;
    }

    _androidAutoHelperLogger.info(
      "Searching for: $itemType that matches query '${enhancedQuery ?? searchQuery.rawQuery}'${searchForPlaylists ? ", including (and preferring) playlists" : ""}",
    );

    final searchTerm = searchForPlaylists
        ? searchQuery.rawQuery.trim()
        : // always use the raw query for searching playlists
          enhancedQuery?.trim() ?? searchQuery.rawQuery.trim();

    if (searchForPlaylists) {
      try {
        List<BaseItemDto>? searchResult;

        if (FinampSettingsHelper.finampSettings.isOffline) {
          List<DownloadStub>? offlineItems = await _downloadsService.getAllCollections(
            nameFilter: searchTerm,
            includeItemTypes: [BaseItemDtoType.playlist],
            fullyDownloaded: false,
            viewFilter: finampUserHelper.currentUser?.currentView?.id,
            childViewFilter: null,
            nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
            onlyFavorites: false,
          );

          searchResult = offlineItems.map((e) => e.baseItem).whereNotNull().toList();
        } else {
          searchResult = await jellyfinApiHelper.getItems(
            parentItem: null, // always use global playlists
            includeItemTypes: ContentType.playlists.itemType?.jellyfinName,
            searchTerm: searchTerm,
            startIndex: 0,
            limit: 1,
          );
        }

        if (searchResult?.isNotEmpty ?? false) {
          final playlist = searchResult![0];

          List<BaseItemDto>? items;

          if (FinampSettingsHelper.finampSettings.isOffline) {
            items = await _downloadsService.getCollectionTracks(playlist, playable: true);
          } else {
            items = await _jellyfinApiHelper.getItems(
              parentItem: playlist,
              includeItemTypes: ContentType.tracks.itemType?.jellyfinName,
              sortBy: "ParentIndexNumber,IndexNumber,SortName",
              sortOrder: "Ascending",
              limit: 200,
            );
          }

          _androidAutoHelperLogger.info("Playing playlist: ${playlist.name} (${items?.length} tracks)");

          await queueService.startPlayback(
            items: items ?? [],
            source: QueueItemSource(
              type: QueueItemSourceType.playlist,
              name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: playlist.name),
              id: playlist.id,
              item: playlist,
            ),
            order: FinampPlaybackOrder
                .linear, //TODO add a setting that sets the default (because Android Auto doesn't give use the prompt as an extra), or use the current order?
          );
        } else {
          _androidAutoHelperLogger.warning("No playlists found for query: ${enhancedQuery ?? searchQuery.rawQuery}");
        }
      } catch (e) {
        _androidAutoHelperLogger.warning("Couldn't search for playlists: $e");
      }
    }

    try {
      // first try with any metadata we could get (could be corrected based on metadata or localizations, or just the raw query)
      List<BaseItemDto>? searchResult = await _getResults(
        searchTerm: searchTerm,
        itemTypes: [itemType].nonNulls.toList(),
      );

      if (searchResult == null || searchResult.isEmpty) {
        _androidAutoHelperLogger.warning("No search results found for search term: $searchTerm)");

        if (enhancedQuery != null) {
          // if we got additional metadata, we already tried searching with it
          // now try searching with the raw query
          searchResult = await _getResults(
            searchTerm: searchQuery.rawQuery.trim(),
            itemTypes: [itemType].nonNulls.toList(),
          );
        }

        if (searchResult == null || searchResult.isEmpty) {
          _androidAutoHelperLogger.warning(
            "No search results found for search term (raw query): ${searchQuery.rawQuery}",
          );
          return;
        }
      }

      final selectedResult = searchResult.firstWhere((element) {
        if (itemType == ContentType.tracks.itemType && searchQuery.extras?["android.intent.extra.artist"] != null) {
          return element.albumArtists?.any(
                (artist) =>
                    (artist.name?.isNotEmpty ?? false) &&
                    (searchQuery.extras?["android.intent.extra.artist"]?.toString().toLowerCase().contains(
                          artist.name?.toLowerCase() ?? "",
                        ) ??
                        false),
              ) ??
              false;
        } else if (itemType == ContentType.tracks.itemType &&
            searchQuery.extras?["android.intent.extra.artist"] != null) {
          return element.albumArtists?.any(
                (artist) =>
                    (artist.name?.isNotEmpty ?? false) &&
                    (searchQuery.extras?["android.intent.extra.artist"]?.toString().toLowerCase().contains(
                          artist.name?.toLowerCase() ?? "",
                        ) ??
                        false),
              ) ??
              false;
        } else {
          return false;
        }
      }, orElse: () => searchResult![0]);

      _androidAutoHelperLogger.info("Playing from search: ${selectedResult.name}");

      if (itemType == ContentType.albums.itemType) {
        final album = selectedResult;
        List<BaseItemDto>? items;

        if (FinampSettingsHelper.finampSettings.isOffline) {
          items = await _downloadsService.getCollectionTracks(album, playable: true);
        } else {
          items = await _jellyfinApiHelper.getItems(
            parentItem: album,
            includeItemTypes: ContentType.tracks.itemType?.jellyfinName,
            sortBy: "ParentIndexNumber,IndexNumber,SortName",
            sortOrder: "Ascending",
            limit: 200,
          );
        }
        _androidAutoHelperLogger.info("Playing album: ${album.name} (${items?.length} tracks)");

        await queueService.startPlayback(
          items: items ?? [],
          source: QueueItemSource(
            type: QueueItemSourceType.album,
            name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: album.name),
            id: album.id,
            item: album,
          ),
          order: FinampPlaybackOrder
              .linear, //TODO add a setting that sets the default (because Android Auto doesn't give use the prompt as an extra), or use the current order?
        );
      } else if (itemType == ContentType.performingArtists.itemType) {
        if (FinampSettingsHelper.finampSettings.isOffline) {
          final parentBaseItems = await getBaseItems(
            MediaItemId(
              contentType: ContentType.performingArtists,
              parentType: MediaItemParentType.collection,
              parentId: selectedResult.id,
              itemId: selectedResult.id,
            ),
          );

          await queueService.startPlayback(
            items: parentBaseItems,
            source: QueueItemSource(
              type: QueueItemSourceType.artist,
              name: QueueItemSourceName(
                type: QueueItemSourceNameType.preTranslated,
                pretranslatedName: selectedResult.name,
              ),
              id: selectedResult.id,
              item: selectedResult,
            ),
            order: FinampPlaybackOrder.linear,
          );
        } else {
          await audioServiceHelper.startInstantMixForArtists([selectedResult]).then((value) => 1);
        }
      } else {
        if (FinampSettingsHelper.finampSettings.isOffline) {
          List<DownloadStub> offlineItems;
          // If we're on the tracks tab, just get all of the downloaded items
          offlineItems = await _downloadsService.getAllTracks(
            // nameFilter: widget.searchTerm,
            viewFilter: finampUserHelper.currentUser?.currentView?.id,
            nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
          );

          var items = offlineItems.map((e) => e.baseItem).whereNotNull().toList();

          items = sortItems(
            items,
            FinampSettingsHelper.finampSettings.tabSortBy[ContentType.tracks]!,
            FinampSettingsHelper.finampSettings.tabSortOrder[ContentType.tracks]!,
          );

          final indexOfSelected = items.indexWhere((element) => element.id == selectedResult.id);

          return await queueService.startPlayback(
            items: items,
            startingIndex: indexOfSelected,
            source: QueueItemSource(
              name: const QueueItemSourceName(type: QueueItemSourceNameType.mix),
              type: QueueItemSourceType.allTracks,
              id: selectedResult.id,
              item: selectedResult,
            ),
          );
        } else {
          await audioServiceHelper.startInstantMixForItem(selectedResult).then((value) => 1);
        }
      }
    } catch (err) {
      _androidAutoHelperLogger.severe("Error while playing from search query: $err");
    }
  }

  Future<void> shuffleAllTracks() async {
    final audioServiceHelper = GetIt.instance<AudioServiceHelper>();

    try {
      await audioServiceHelper.shuffleAll(onlyShowFavorites: FinampSettingsHelper.finampSettings.onlyShowFavorites);
    } catch (err) {
      _androidAutoHelperLogger.severe("Error while shuffling all tracks", err);
    }
  }

  Future<List<MediaItem>> getMediaItems(MediaItemId itemId) async {
    final queueService = GetIt.instance<QueueService>();
    final items = await getBaseItems(itemId);
    final List<MediaItem> mediaItems = [];

    if (itemId.contentType == ContentType.tracks && itemId.parentType == MediaItemParentType.rootCollection) {
      mediaItems.add(
        MediaItem(
          id: QueueItemSourceNameType.shuffleAll.name,
          title: GlobalSnackbar.requireL10n.shuffleAll,
          playable: true,
        ),
      );
    }

    for (final item in items) {
      final mediaItem = await queueService.generateMediaItem(
        item,
        parentType: MediaItemParentType.collection,
        parentId: item.parentId,
        isPlayable: _isPlayable,
      );
      mediaItems.add(mediaItem);
    }
    return mediaItems;
  }

  Future<void> playFromMediaId(MediaItemId itemId) async {
    final audioServiceHelper = GetIt.instance<AudioServiceHelper>();
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    // queue service should be initialized by time we get here
    final queueService = GetIt.instance<QueueService>();

    // shouldn't happen, but just in case
    if (!_isPlayable(contentType: itemId.contentType)) {
      _androidAutoHelperLogger.warning(
        "Tried to play from media id with non-playable item type ${itemId.parentType.name}",
      );
      return;
    }

    if (itemId.parentType == MediaItemParentType.instantMix) {
      if (FinampSettingsHelper.finampSettings.isOffline) {
        List<DownloadStub> offlineItems;
        // If we're on the tracks tab, just get all of the downloaded items
        offlineItems = await _downloadsService.getAllTracks(
          // nameFilter: widget.searchTerm,
          viewFilter: finampUserHelper.currentUser?.currentView?.id,
          nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
        );

        var items = offlineItems.map((e) => e.baseItem).whereNotNull().toList();

        items = sortItems(
          items,
          FinampSettingsHelper.finampSettings.tabSortBy[ContentType.tracks]!,
          FinampSettingsHelper.finampSettings.tabSortOrder[ContentType.tracks]!,
        );

        final indexOfSelected = items.indexWhere((element) => element.id == itemId.itemId);

        return await queueService.startPlayback(
          items: items,
          startingIndex: indexOfSelected,
          source: QueueItemSource(
            name: const QueueItemSourceName(type: QueueItemSourceNameType.mix),
            type: QueueItemSourceType.allTracks,
            id: itemId.itemId!,
            item: items[indexOfSelected],
          ),
        );
      } else {
        return await audioServiceHelper.startInstantMixForItem(await _jellyfinApiHelper.getItemById(itemId.itemId!));
      }
    }

    if (itemId.parentType != MediaItemParentType.collection || itemId.itemId == null) {
      _androidAutoHelperLogger.warning(
        "Tried to play from media id with invalid parent type '${itemId.parentType.name}' or null id",
      );
      return;
    }
    // get all tracks of current parent
    final parentItem = await getParentFromId(itemId.itemId!);

    // start instant mix for artists
    if (itemId.contentType.isArtist) {
      if (FinampSettingsHelper.finampSettings.isOffline || parentItem == null) {
        final parentBaseItems = await getBaseItems(itemId);

        return await queueService.startPlayback(
          items: parentBaseItems,
          source: QueueItemSource(
            type: QueueItemSourceType.artist,
            name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: parentItem?.name),
            id: parentItem?.id ?? itemId.parentId!,
            item: parentItem,
          ),
          order: FinampPlaybackOrder.linear,
        );
      } else {
        return await audioServiceHelper.startInstantMixForArtists([parentItem]);
      }
    }

    final parentBaseItems = await getBaseItems(itemId);

    await queueService.startPlayback(
      items: parentBaseItems,
      source: QueueItemSource(
        type: itemId.contentType == ContentType.playlists ? QueueItemSourceType.playlist : QueueItemSourceType.album,
        name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: parentItem?.name),
        id: parentItem?.id ?? itemId.parentId!,
        item: parentItem,
      ),
    );
  }

  Future<List<BaseItemDto>> _searchTracks(AndroidAutoSearchQuery searchQuery, {int limit = 20}) async {
    List<BaseItemDto>? searchResult;

    // search for exact query first, then search for adjusted query
    // sometimes Google's adjustment might not be what we want, but sometimes it actually helps
    List<BaseItemDto>? searchResultExactQuery;
    List<BaseItemDto>? searchResultAdjustedQuery;
    try {
      searchResultExactQuery = await _getResults(
        searchTerm: searchQuery.rawQuery.trim(),
        itemTypes: [ContentType.tracks.itemType].nonNulls.toList(),
        limit: searchQuery.extras?["android.intent.extra.title"] != null ? (limit / 2).round() : limit,
      );
    } catch (e) {
      _androidAutoHelperLogger.severe("Error while searching for exact query:", e);
    }
    if (searchQuery.extras?["android.intent.extra.title"] != null) {
      try {
        searchResultAdjustedQuery = await _getResults(
          searchTerm: (searchQuery.extras!["android.intent.extra.title"] as String).trim(),
          itemTypes: [ContentType.tracks.itemType].nonNulls.toList(),
          limit: limit - (searchResultExactQuery?.length ?? 0),
        );
      } catch (e) {
        _androidAutoHelperLogger.severe("Error while searching for adjusted query:", e);
      }
    }

    searchResult = searchResultExactQuery?.followedBy(searchResultAdjustedQuery ?? []).toList() ?? [];

    final List<BaseItemDto> filteredSearchResults = [];
    // filter out duplicates
    for (final item in searchResult) {
      if (!filteredSearchResults.any((element) => element.id == item.id)) {
        filteredSearchResults.add(item);
      }
    }

    if (searchResult.isEmpty) {
      _androidAutoHelperLogger.warning(
        "No search results found for query: ${searchQuery.rawQuery} (extras: ${searchQuery.extras})",
      );
    }

    int calculateMatchQuality(BaseItemDto item, AndroidAutoSearchQuery searchQuery) {
      final title = item.name ?? "";

      final wantedTitle = searchQuery.extras?["android.intent.extra.title"]?.toString().trim();
      final wantedArtist = searchQuery.extras?["android.intent.extra.artist"]?.toString().trim();

      if (title.toLowerCase() == searchQuery.rawQuery.toLowerCase() ||
          wantedArtist != null &&
              (item.albumArtists?.any(
                    (artist) =>
                        (artist.name?.isNotEmpty ?? false) &&
                        wantedArtist.toString().toLowerCase().contains(artist.name?.toLowerCase() ?? ""),
                  ) ??
                  false)) {
        // Title matches exactly or artist matches, highest priority
        return 1;
      } else if (title == wantedTitle) {
        // Title matches, normal priority
        return 0;
      } else {
        // No exact match, lower priority
        return -1;
      }
    }

    // sort items based on match quality with extras
    filteredSearchResults.sort((a, b) {
      final aMatchQuality = calculateMatchQuality(a, searchQuery);
      final bMatchQuality = calculateMatchQuality(b, searchQuery);
      return bMatchQuality.compareTo(aMatchQuality);
    });

    return filteredSearchResults;
  }

  Future<List<BaseItemDto>> _searchAlbums(AndroidAutoSearchQuery searchQuery, {int limit = 20}) async {
    List<BaseItemDto>? searchResult;

    bool hasAlbumMetadata = searchQuery.extras?["android.intent.extra.album"] != null;

    // search for exact query first, then search for adjusted query
    // sometimes Google's adjustment might not be what we want, but sometimes it actually helps
    List<BaseItemDto>? searchResultExactQuery;
    List<BaseItemDto>? searchResultAdjustedQuery;
    try {
      searchResultExactQuery = await _getResults(
        searchTerm: searchQuery.rawQuery.trim(),
        itemTypes: [ContentType.albums.itemType].nonNulls.toList(),
        limit: hasAlbumMetadata ? (limit / 2).round() : limit,
      );
    } catch (e) {
      _androidAutoHelperLogger.severe("Error while searching for exact query:", e);
    }
    if (hasAlbumMetadata) {
      try {
        searchResultAdjustedQuery = await _getResults(
          searchTerm: (searchQuery.extras!["android.intent.extra.album"] as String).trim(),
          itemTypes: [ContentType.albums.itemType].nonNulls.toList(),
          limit: limit - (searchResultExactQuery?.length ?? 0),
        );
      } catch (e) {
        _androidAutoHelperLogger.severe("Error while searching for adjusted query:", e);
      }
    }

    searchResult = searchResultExactQuery?.followedBy(searchResultAdjustedQuery ?? []).toList() ?? [];

    final List<BaseItemDto> filteredSearchResults = [];
    // filter out duplicates
    for (final item in searchResult) {
      if (!filteredSearchResults.any((element) => element.id == item.id)) {
        filteredSearchResults.add(item);
      }
    }

    if (searchResult.isEmpty) {
      _androidAutoHelperLogger.warning(
        "No search results found for query: ${searchQuery.rawQuery} (extras: ${searchQuery.extras})",
      );
    }

    int calculateMatchQuality(BaseItemDto item, AndroidAutoSearchQuery searchQuery) {
      final title = item.name ?? "";

      final wantedAlbum = searchQuery.extras?["android.intent.extra.album"]?.toString().trim();
      final wantedArtist = searchQuery.extras?["android.intent.extra.artist"]?.toString().trim();

      if (title.toLowerCase() == searchQuery.rawQuery.toLowerCase() ||
          wantedArtist != null &&
              (item.albumArtists?.any(
                    (artist) =>
                        (artist.name?.isNotEmpty ?? false) &&
                        wantedArtist.toString().toLowerCase().contains(artist.name?.toLowerCase() ?? ""),
                  ) ??
                  false)) {
        // Title matches exactly or artist matches, highest priority
        return 1;
      } else if (title == wantedAlbum) {
        // Title matches, normal priority
        return 0;
      } else {
        // No exact match, lower priority
        return -1;
      }
    }

    // sort items based on match quality with extras
    filteredSearchResults.sort((a, b) {
      final aMatchQuality = calculateMatchQuality(a, searchQuery);
      final bMatchQuality = calculateMatchQuality(b, searchQuery);
      return bMatchQuality.compareTo(aMatchQuality);
    });

    return filteredSearchResults;
  }

  Future<List<BaseItemDto>> _searchPlaylists(AndroidAutoSearchQuery searchQuery, {int limit = 20}) async {
    List<BaseItemDto>? searchResult;

    bool hasPlaylistMetadata = searchQuery.extras?["android.intent.extra.playlist"] != null;

    // search for exact query first, then search for adjusted query
    // sometimes Google's adjustment might not be what we want, but sometimes it actually helps
    List<BaseItemDto>? searchResultExactQuery;
    List<BaseItemDto>? searchResultAdjustedQuery;
    try {
      searchResultExactQuery = await _getResults(
        searchTerm: searchQuery.rawQuery.trim(),
        itemTypes: [ContentType.playlists.itemType].nonNulls.toList(),
        limit: hasPlaylistMetadata ? (limit / 2).round() : limit,
      );
    } catch (e) {
      _androidAutoHelperLogger.severe("Error while searching for exact query:", e);
    }
    if (hasPlaylistMetadata) {
      try {
        searchResultAdjustedQuery = await _getResults(
          searchTerm: (searchQuery.extras!["android.intent.extra.playlist"] as String).trim(),
          itemTypes: [ContentType.playlists.itemType].nonNulls.toList(),
          limit: limit - (searchResultExactQuery?.length ?? 0),
        );
      } catch (e) {
        _androidAutoHelperLogger.severe("Error while searching for adjusted query:", e);
      }
    }

    searchResult = searchResultExactQuery?.followedBy(searchResultAdjustedQuery ?? []).toList() ?? [];

    final List<BaseItemDto> filteredSearchResults = [];
    // filter out duplicates
    for (final item in searchResult) {
      if (!filteredSearchResults.any((element) => element.id == item.id)) {
        filteredSearchResults.add(item);
      }
    }

    if (searchResult.isEmpty) {
      _androidAutoHelperLogger.warning(
        "No search results found for query: ${searchQuery.rawQuery} (extras: ${searchQuery.extras})",
      );
    }

    int calculateMatchQuality(BaseItemDto item, AndroidAutoSearchQuery searchQuery) {
      final title = item.name ?? "";

      final wantedPlaylist = searchQuery.extras?["android.intent.extra.playlist"]?.toString().trim();

      if (title.toLowerCase() == searchQuery.rawQuery.toLowerCase()) {
        // Title matches exactly, highest priority
        return 1;
      } else if (title == wantedPlaylist) {
        // Title matches metadata, normal priority
        return 0;
      } else {
        // No exact match, lower priority
        return -1;
      }
    }

    // sort items based on match quality with extras
    filteredSearchResults.sort((a, b) {
      final aMatchQuality = calculateMatchQuality(a, searchQuery);
      final bMatchQuality = calculateMatchQuality(b, searchQuery);
      return bMatchQuality.compareTo(aMatchQuality);
    });

    return filteredSearchResults;
  }

  Future<List<BaseItemDto>> _searchArtists(AndroidAutoSearchQuery searchQuery, {int limit = 20}) async {
    List<BaseItemDto>? searchResult;

    bool hasArtistMetadata = searchQuery.extras?["android.intent.extra.artist"] != null;

    // search for exact query first, then search for adjusted query
    // sometimes Google's adjustment might not be what we want, but sometimes it actually helps
    List<BaseItemDto>? searchResultExactQuery;
    List<BaseItemDto>? searchResultAdjustedQuery;
    try {
      searchResultExactQuery = await _getResults(
        searchTerm: searchQuery.rawQuery.trim(),
        itemTypes: [ContentType.performingArtists.itemType].nonNulls.toList(),
        limit: hasArtistMetadata ? (limit / 2).round() : limit,
      );
    } catch (e) {
      _androidAutoHelperLogger.severe("Error while searching for exact query:", e);
    }
    if (hasArtistMetadata) {
      try {
        searchResultAdjustedQuery = await _getResults(
          searchTerm: (searchQuery.extras!["android.intent.extra.artist"] as String).trim(),
          itemTypes: [ContentType.performingArtists.itemType].nonNulls.toList(),
          limit: limit - (searchResultExactQuery?.length ?? 0),
        );
      } catch (e) {
        _androidAutoHelperLogger.severe("Error while searching for adjusted query:", e);
      }
    }

    searchResult = searchResultExactQuery?.followedBy(searchResultAdjustedQuery ?? []).toList() ?? [];

    final List<BaseItemDto> filteredSearchResults = [];
    // filter out duplicates
    for (final item in searchResult) {
      if (!filteredSearchResults.any((element) => element.id == item.id)) {
        filteredSearchResults.add(item);
      }
    }

    if (searchResult.isEmpty) {
      _androidAutoHelperLogger.warning(
        "No search results found for query: ${searchQuery.rawQuery} (extras: ${searchQuery.extras})",
      );
    }

    int calculateMatchQuality(BaseItemDto item, AndroidAutoSearchQuery searchQuery) {
      final title = item.name ?? "";

      final wantedArtist = searchQuery.extras?["android.intent.extra.artist"]?.toString().trim();

      if (title.toLowerCase() == searchQuery.rawQuery.toLowerCase()) {
        // Title matches exactly, highest priority
        return 1;
      } else if (title == wantedArtist) {
        // Title matches, normal priority
        return 0;
      } else {
        // No exact match, lower priority
        return -1;
      }
    }

    // sort items based on match quality with extras
    filteredSearchResults.sort((a, b) {
      final aMatchQuality = calculateMatchQuality(a, searchQuery);
      final bMatchQuality = calculateMatchQuality(b, searchQuery);
      return bMatchQuality.compareTo(aMatchQuality);
    });

    return filteredSearchResults;
  }

  Future<List<BaseItemDto>> _searchGenres(AndroidAutoSearchQuery searchQuery, {int limit = 20}) async {
    List<BaseItemDto>? searchResult;

    bool hasGenreMetadata = searchQuery.extras?["android.intent.extra.genre"] != null;

    // search for exact query first, then search for adjusted query
    // sometimes Google's adjustment might not be what we want, but sometimes it actually helps
    List<BaseItemDto>? searchResultExactQuery;
    List<BaseItemDto>? searchResultAdjustedQuery;
    try {
      searchResultExactQuery = await _getResults(
        searchTerm: searchQuery.rawQuery.trim(),
        itemTypes: [ContentType.genres.itemType].nonNulls.toList(),
        limit: hasGenreMetadata ? (limit / 2).round() : limit,
      );
    } catch (e) {
      _androidAutoHelperLogger.severe("Error while searching for exact query:", e);
    }
    if (hasGenreMetadata) {
      try {
        searchResultAdjustedQuery = await _getResults(
          searchTerm: (searchQuery.extras!["android.intent.extra.genre"] as String).trim(),
          itemTypes: [ContentType.genres.itemType].nonNulls.toList(),
          limit: limit - (searchResultExactQuery?.length ?? 0),
        );
      } catch (e) {
        _androidAutoHelperLogger.severe("Error while searching for adjusted query:", e);
      }
    }

    searchResult = searchResultExactQuery?.followedBy(searchResultAdjustedQuery ?? []).toList() ?? [];

    final List<BaseItemDto> filteredSearchResults = [];
    // filter out duplicates
    for (final item in searchResult) {
      if (!filteredSearchResults.any((element) => element.id == item.id)) {
        filteredSearchResults.add(item);
      }
    }

    if (searchResult.isEmpty) {
      _androidAutoHelperLogger.warning(
        "No search results found for query: ${searchQuery.rawQuery} (extras: ${searchQuery.extras})",
      );
    }

    int calculateMatchQuality(BaseItemDto item, AndroidAutoSearchQuery searchQuery) {
      final title = item.name ?? "";

      final wantedGenre = searchQuery.extras?["android.intent.extra.genre"]?.toString().trim();

      if (title.toLowerCase() == searchQuery.rawQuery.toLowerCase()) {
        // Title matches exactly, highest priority
        return 1;
      } else if (title == wantedGenre) {
        // Title matches, normal priority
        return 0;
      } else {
        // No exact match, lower priority
        return -1;
      }
    }

    // sort items based on match quality with extras
    filteredSearchResults.sort((a, b) {
      final aMatchQuality = calculateMatchQuality(a, searchQuery);
      final bMatchQuality = calculateMatchQuality(b, searchQuery);
      return bMatchQuality.compareTo(aMatchQuality);
    });

    return filteredSearchResults;
  }

  Future<List<BaseItemDto>?> _getResults({
    required String searchTerm,
    required List<BaseItemDtoType> itemTypes,
    int limit = 25,
  }) async {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    List<BaseItemDto>? searchResult;

    if (FinampSettingsHelper.finampSettings.isOffline) {
      List<DownloadStub> offlineItems;

      if (itemTypes.first == ContentType.tracks.itemType) {
        // If we're on the tracks tab, just get all of the downloaded items
        // We should probably try to page this, at least if we are sorting by name
        offlineItems = await _downloadsService.getAllTracks(
          nameFilter: searchTerm,
          viewFilter: finampUserHelper.currentUser?.currentView?.id,
          nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
          onlyFavorites: false,
        );
      } else {
        offlineItems = await _downloadsService.getAllCollections(
          nameFilter: searchTerm,
          includeItemTypes: itemTypes,
          fullyDownloaded: false,
          viewFilter: itemTypes.first == ContentType.albums.itemType
              ? finampUserHelper.currentUser?.currentView?.id
              : null,
          childViewFilter:
              (itemTypes.contains(ContentType.albums.itemType) && itemTypes.contains(ContentType.playlists.itemType))
              ? finampUserHelper.currentUser?.currentView?.id
              : null,
          nullableViewFilters:
              itemTypes.first == ContentType.albums.itemType &&
              FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
          onlyFavorites: false,
        );
      }
      searchResult = offlineItems.map((e) => e.baseItem).whereNotNull().toList();
    } else {
      if (itemTypes.first == BaseItemDtoType.artist) {
        searchResult = await jellyfinApiHelper.getArtists(
          parentItem: finampUserHelper.currentUser?.currentView,
          searchTerm: searchTerm,
          startIndex: 0,
          limit: limit,
        );
      } else {
        searchResult = await jellyfinApiHelper.getItems(
          parentItem: itemTypes.contains(BaseItemDtoType.playlist) ? null : finampUserHelper.currentUser?.currentView,
          includeItemTypes: itemTypes.map((type) => type.jellyfinName).join(","),
          searchTerm: searchTerm,
          startIndex: 0,
          limit: limit, // get more than the first result so we can filter using additional metadata
        );
      }
    }

    return searchResult;
  }

  // albums, playlists, and tracks should play when clicked
  // clicking artists starts an instant mix, so they are technically playable
  // genres has subcategories, so it should be browsable but not playable
  bool _isPlayable({BaseItemDto? item, ContentType? contentType}) {
    final tabContentType = ContentType.fromItemType(item?.type ?? contentType?.itemType?.jellyfinName ?? "Audio");
    return tabContentType == ContentType.albums ||
        tabContentType == ContentType.playlists ||
        tabContentType.isArtist ||
        tabContentType == ContentType.tracks;
  }
}
