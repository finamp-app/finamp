import 'dart:convert';

import 'package:finamp/services/album_screen_provider.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'audio_service_helper.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api_helper.dart';
import 'queue_service.dart';
import 'android_auto_helper.dart';
import 'item_helper.dart';
import 'artist_content_provider.dart';

final _carPlayLogger = Logger("CarPlay");

class CarPlayHelper {
  ConnectionStatusTypes connectionStatus = ConnectionStatusTypes.unknown;
  final FlutterCarplay _flutterCarplay = FlutterCarplay();

  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _downloadsService = GetIt.instance<DownloadsService>();
  final providerRef = GetIt.instance<ProviderContainer>();

  ProviderSubscription? _userSubscription;

  /// Check if a user is currently logged in
  bool get isUserLoggedIn => _finampUserHelper.currentUser != null;

  void setupCarplay() {
    _flutterCarplay.addListenerOnConnectionChange(onConnectionChange);

    // Listen for user login/logout changes and refresh CarPlay template
    _userSubscription = providerRef.listen(
      FinampUserHelper.finampCurrentUserProvider,
      (previous, next) {
        _carPlayLogger.info("User state changed, refreshing CarPlay template");
        setCarplayRootTemplate();
      },
    );

    setCarplayRootTemplate();
  }

  void disposeCarplay() {
    _userSubscription?.close();
    _flutterCarplay.removeListenerOnConnectionChange();
  }

  void onConnectionChange(ConnectionStatusTypes status) {
    if (status == ConnectionStatusTypes.connected) {
    }
  }

  // getTabItems is based on AndroidAutoHelper.getBaseItems() but using BaseItemDto 
  // Incomplete! 
  Future<List<BaseItemDto>> getTabItems ({required TabContentType tabContentType}) async { 
    // limit amount so it doesn't crash / take forever on large libraries 
    const onlineModeLimit = 250;
    const offlineModeLimit = 1000;

    final sortBy = FinampSettingsHelper.finampSettings.getTabSortBy(tabContentType);
    final sortOrder = FinampSettingsHelper.finampSettings.getSortOrder(tabContentType);
    
    // If we are in offline mode, display all matching downloaded parents 
    if (FinampSettingsHelper.finampSettings.isOffline) {
      List<BaseItemDto> baseItems = [];
      for (final downloadedParent in await _downloadsService.getAllCollections()) {
        if (baseItems.length >= offlineModeLimit) break;
        if (downloadedParent.baseItem != null && downloadedParent.baseItemType == tabContentType.itemType) {
          baseItems.add(downloadedParent.baseItem!);
        }
      }
      return sortItems(baseItems, sortBy, sortOrder);
    }
    
    // Fetch the online version if we can't get the offline versions
    final items = await _jellyfinApiHelper.getItems(
      parentItem: tabContentType.itemType == BaseItemDtoType.playlist ? null : _finampUserHelper.currentUser?.currentView,
      includeItemTypes: tabContentType.itemType.idString, 
      sortBy: 
          sortBy.jellyfinName(tabContentType) ?? 
          (tabContentType == TabContentType.tracks ? "Album,Sortname" : "Sortname"),
      sortOrder: tabContentType == TabContentType.tracks ? null : sortOrder.toString(),
      limit: onlineModeLimit,
    );
    return items ?? [];
  }

  // Fetch artist tracks directly via API, bypassing Riverpod providers
  Future<List<BaseItemDto>> getArtistTracks(BaseItemDto artist) async {
    if (FinampSettingsHelper.finampSettings.isOffline) {
      // Offline: Get all downloaded albums and filter by artist, then get tracks
      final allAlbums = await _downloadsService.getAllCollections();
      final List<BaseItemDto> tracks = [];
      for (final downloadedParent in allAlbums) {
        if (downloadedParent.baseItem != null &&
            downloadedParent.baseItemType == BaseItemDtoType.album) {
          final album = downloadedParent.baseItem!;
          // Check if album belongs to this artist
          if (album.albumArtist == artist.name ||
              album.albumArtists?.any((aa) => aa.id == artist.id) == true) {
            tracks.addAll(await _downloadsService.getCollectionTracks(album, playable: true));
          }
        }
      }
      return tracks;
    }

    // Online: Direct API call for artist's tracks
    final tracks = await _jellyfinApiHelper.getItems(
      parentItem: artist,
      includeItemTypes: "Audio",
      sortBy: "Album,ParentIndexNumber,IndexNumber,SortName",
      limit: 250,
    );
    return tracks ?? [];
  }

  // playFromBaseItem is based on AndroidAutoHelper.playFromMediaId but using BaseItemDto
  Future<void> playItem(BaseItemDto item, {int? index = 0, FinampPlaybackOrder? order = FinampPlaybackOrder.linear}) async {
    final queueService = GetIt.instance<QueueService>();

    final childItems = await loadChildTracksFromBaseItem(baseItem: item);

    await queueService.startPlayback(
      items: childItems,
      source: QueueItemSource.fromBaseItem(item),
      order: order,
      startingIndex: order == FinampPlaybackOrder.linear ? index : null,
    );
  }

  // Play a list of tracks as an ad-hoc queue (for tracks without a parent container)
  Future<void> playTracksAsQueue(
    List<BaseItemDto> tracks,
    {int? index = 0, FinampPlaybackOrder? order = FinampPlaybackOrder.linear, String? sourceName}
  ) async {
    final queueService = GetIt.instance<QueueService>();

    await queueService.startPlayback(
      items: tracks,
      source: QueueItemSource.rawId(
        type: QueueItemSourceType.allTracks,
        name: QueueItemSourceName(
          type: QueueItemSourceNameType.preTranslated,
          pretranslatedName: sourceName ?? "Tracks",
        ),
        id: "carplay-tracks-${DateTime.now().millisecondsSinceEpoch}",
      ),
      order: order,
      startingIndex: order == FinampPlaybackOrder.linear ? index : null,
    );
  }

  // CarPlay Control
  Future<void> setCarplayRootTemplate() async {
    // Check if user is logged in first
    if (!isUserLoggedIn) {
      _carPlayLogger.info("User not logged in, showing login prompt on CarPlay");
      await _showLoginRequiredTemplate();
      return;
    }

    List<MediaItem> rootItems = await GetIt.instance<MusicPlayerBackgroundTask>().getChildren(AudioService.browsableRootId);
    CPListSection librarySection = CPListSection(
      items: []);

    for (final item in rootItems) {
      librarySection.items.add(CPListItem(
        text: item.title,
        onPress: (complete, self) {
          final parentId = MediaItemId.fromJson(jsonDecode(item.id) as Map<String, dynamic>);

          switch(parentId.contentType) {
            case TabContentType.albums:
            case TabContentType.playlists:
            case TabContentType.genres: showAlbumsTemplate(tabType: parentId.contentType);
            case TabContentType.artists: showArtistsTemplate();
            case TabContentType.tracks: showTracksTemplate();
          }
          complete();
        }
      ));
    }

    await FlutterCarplay.setRootTemplate(
      rootTemplate: CPTabBarTemplate(
        templates: [
          CPListTemplate(
            sections: [],
            title: 'Home',
            emptyViewTitleVariants: ['Home'],
            emptyViewSubtitleVariants: [
              'Home not yet implemented.'
            ],
            systemIcon: 'music.note.house',
          ),
          CPListTemplate(
            sections: [],
            title: 'Recent',
            emptyViewTitleVariants: ['Recent'],
            emptyViewSubtitleVariants: [
              'Recent not yet implemented.'
            ],
            systemIcon: 'clock',
          ),
          CPListTemplate(
            sections: [],
            title: 'Search',
            emptyViewTitleVariants: ['Search'],
            emptyViewSubtitleVariants: [
              'Search not yet implemented.'
            ],
            systemIcon: 'magnifyingglass',
          ),
          CPListTemplate(
            sections: [
            librarySection
            ],
            title: 'Library',
            emptyViewTitleVariants: ['Library'],
            emptyViewSubtitleVariants: [
              'Library not yet implemented.'
            ],
            systemIcon: 'play.square.stack',
          ),
        ],
      ),
    );

    await _flutterCarplay.forceUpdateRootTemplate();
  }

  /// Shows a template prompting the user to log in via the Finamp app
  Future<void> _showLoginRequiredTemplate() async {
    await FlutterCarplay.setRootTemplate(
      rootTemplate: CPListTemplate(
        sections: [],
        title: 'Finamp',
        emptyViewTitleVariants: ['Please Log In'],
        emptyViewSubtitleVariants: [
          'Open the Finamp app on your phone to log in to your Jellyfin server.'
        ],
        systemIcon: 'person.crop.circle.badge.exclamationmark',
      ),
    );

    await _flutterCarplay.forceUpdateRootTemplate();
  }

  Future<void> showPlaylistTemplate(BaseItemDto parent) async {
    List<BaseItemDto> mediaItems = await loadChildTracksFromBaseItem(baseItem: parent);
    // final (alltracks, mediaItems) = await GetIt.instance<ProviderContainer>().read(getAlbumOrPlaylistTracksProvider(parent).future);

    CPListSection playlistSection = CPListSection(items: []);

    // Add shuffle play to top 
    playlistSection.items.add(CPListItem(
      text: "Shuffle Play", 
      onPress: (complete, self) async { 
        await playItem(parent, order: FinampPlaybackOrder.shuffled);
        complete();
      },
    ));

    mediaItems.asMap().forEach((index, item) { 
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;

      playlistSection.items.add(CPListItem(
        text: item.name ?? "Unknown Track", // Todo localization
        detailText: item.artists?.join(", ") ?? item.albumArtist,
        image: imageUri.toString(),
        onPress: (complete, self) async {
          await playItem(parent, index: index);
          complete();
        },
      ));
    });

    CPListTemplate playlistTemplate = CPListTemplate(
      sections: [
        playlistSection,
      ], 
      systemIcon: 'gear');
  
    await FlutterCarplay.push(template: playlistTemplate);
  }

  Future<void> showAlbumsTemplate({required TabContentType tabType}) async { 
    // Fetch child items of root navigation 
    List<BaseItemDto> mediaItems = await getTabItems(tabContentType: tabType);
  
    CPListSection albumsSection = CPListSection(items: []);

    for (final item in mediaItems) { 
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;
      
      albumsSection.items.add(CPListItem(
        text: item.name ?? "Unknown", // Todo localization
        detailText: item.artists?.join(", ") ?? item.albumArtist,
        image: imageUri?.toString(),
        onPress: (complete, self) async {
          await showPlaylistTemplate(item);
          complete();
        }
        ));
    }

    CPListTemplate albumsTemplate = CPListTemplate(
      sections: [
        albumsSection,
      ], 
      systemIcon: 'gear');
  
    await FlutterCarplay.push(template: albumsTemplate);
  }

  Future<void> showTracksTemplate() async {
    // Fetch tracks from library
    List<BaseItemDto> mediaItems = await getTabItems(tabContentType: TabContentType.tracks);

    CPListSection tracksSection = CPListSection(items: []);

    // Add shuffle play option at top
    tracksSection.items.add(CPListItem(
      text: "Shuffle All",
      onPress: (complete, self) async {
        await playTracksAsQueue(mediaItems, order: FinampPlaybackOrder.shuffled, sourceName: "All Tracks");
        complete();
      },
    ));

    mediaItems.asMap().forEach((index, item) {
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;

      tracksSection.items.add(CPListItem(
        text: item.name ?? "Unknown Track",
        detailText: item.artists?.join(", ") ?? item.albumArtist,
        image: imageUri?.toString(),
        onPress: (complete, self) async {
          await playTracksAsQueue(mediaItems, index: index, sourceName: "All Tracks");
          complete();
        },
      ));
    });

    CPListTemplate tracksTemplate = CPListTemplate(
      sections: [tracksSection],
      systemIcon: 'music.note',
    );

    await FlutterCarplay.push(template: tracksTemplate);
  }

  Future<void> showArtistsTemplate() async {
    // Fetch child items of this type
    List<BaseItemDto> mediaItems = await getTabItems(tabContentType: TabContentType.artists);

    CPListSection artistsSection = CPListSection(items: []);

    for (final item in mediaItems) { 
      artistsSection.items.add(CPListItem(
        text: item.name ?? "Unknown Name", // TODO localization for this
        onPress: (complete, self) async {
          await showArtistTemplate(item);
          complete();
        }
        ));
    }

    CPListTemplate albumsTemplate = CPListTemplate(
      sections: [
        artistsSection,
      ], 
      systemIcon: 'gear');
  
    await FlutterCarplay.push(template: albumsTemplate);
  }
  
  Future<void> showArtistTemplate(BaseItemDto parent) async {
    // Declare template and sections 
    CPListTemplate artistTemplate = CPListTemplate(sections: [], systemIcon: 'gear');
    CPListSection artistAlbums = CPListSection(header: "Albums", items: []);
    CPListSection topTracks = CPListSection(header: "Top Tracks", items: []);
    CPListSection recentlyPlayed = CPListSection(header: "Recently Played", items: []); 

    // Fetch items for sections 
    List<BaseItemDto> artistAlbumsList = await GetIt.instance<ProviderContainer>().read(getArtistAlbumsProvider(parent, _finampUserHelper.currentUser?.currentView, null).future);
    List<BaseItemDto> artistTracks = await getArtistTracks(parent);
    final mostPlayedList = artistTracks.where((s) => (s.userData?.playCount ?? 0) > 0).take(5).toList(); 
    final recentlyPlayedList = artistTracks.where((s) => s.userData?.lastPlayedDate != null).take(5).toList();
    // final (topTracksAsync, artistCuratedItemSelectionType, newDisabledTrackFilters) = await GetIt.instance<ProviderContainer>()
    //   .read(getArtistTracksSectionProvider(parent, _finampUserHelper.currentUser?.currentView, null).future);

    // Populate sections 
    for(final item in artistAlbumsList) { 
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;

      artistAlbums.items.add(CPListItem(
        text: item.name ?? "Unknown Name", // TODO localization 
        image: imageUri.toString(),
        onPress: (complete, self) async {
          await showPlaylistTemplate(item);
          complete();
        }));
    }
    artistTemplate.sections.add(artistAlbums);

    for (var i = 0; i < mostPlayedList.length; i++) {
      final item = mostPlayedList[i];
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;
      topTracks.items.add(CPListItem(
        text: item.name ?? "Unknown Name",
        image: imageUri.toString(),
        onPress: (complete, self) async {
          await playTracksAsQueue(mostPlayedList, index: i, sourceName: "${parent.name} - Top Tracks");
          complete();
        }));
    }
    artistTemplate.sections.add(topTracks);

    for (var i = 0; i < recentlyPlayedList.length; i++) {
      final item = recentlyPlayedList[i];
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;
      recentlyPlayed.items.add(CPListItem(
        text: item.name ?? "Unknown Name",
        image: imageUri.toString(),
        onPress: (complete, self) async {
          await playTracksAsQueue(recentlyPlayedList, index: i, sourceName: "${parent.name} - Recently Played");
          complete();
        }));
    }
    artistTemplate.sections.add(recentlyPlayed);

    await FlutterCarplay.push(template: artistTemplate);
  }
}