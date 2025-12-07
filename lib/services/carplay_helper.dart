import 'dart:convert';
import 'dart:ffi';

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
  // logger?

  ConnectionStatusTypes connectionStatus = ConnectionStatusTypes.unknown;
  final FlutterCarplay _flutterCarplay = FlutterCarplay();

  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _downloadsService = GetIt.instance<DownloadsService>();
  final providerRef = GetIt.instance<ProviderContainer>();

  void setupCarplay() { 
    _flutterCarplay.addListenerOnConnectionChange(onConnectionChange);
    setCarplayRootTemplate();
  }

  void disposeCarplay() { 
    _flutterCarplay.removeListenerOnConnectionChange();
  }

  void onConnectionChange(ConnectionStatusTypes status) {
    if (status == ConnectionStatusTypes.connected) {
    }
  }

  // getTabItems is based on AndroidAutoHelper.getBaseItems() but using BaseItemDto 
  // Incomplete! 
  Future<List<BaseItemDto>> getTabItems (TabContentType tabContentType) async { 
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

  // CarPlay Control
  Future<void> setCarplayRootTemplate() async { 
    List<MediaItem> rootItems = await GetIt.instance<MusicPlayerBackgroundTask>().getChildren(AudioService.browsableRootId);
    CPListSection librarySection = CPListSection(
      items: []);

    for (final item in rootItems) {
      librarySection.items.add(CPListItem(
        text: item.title,
        onPress: (complete, self) {
          final parentId = MediaItemId.fromJson(jsonDecode(item.id) as Map<String, dynamic>);

          switch(parentId.contentType) {
            case TabContentType.albums: showAlbumsTemplate(parentId);
            case TabContentType.artists: showArtistsTemplate(item);
            case TabContentType.playlists:
            case TabContentType.genres:
            case TabContentType.tracks: 
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
              // CPListSection(
              //   items: [
              //     CPListItem(
              //       text: "Albums", 
              //       onPress: (complete, self) {
              //         complete();
              //       }),
              //     CPListItem(text: "Artists"),
              //     CPListItem(text: "Playlists"),
              //     CPListItem(text: "Genres"),
              //     CPListItem(text: "Tracks"),
              //   ]
              // ),
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

  Future<void> showAlbumsTemplate(MediaItemId parent) async { 
    // Fetch child items of root navigation 
    List<BaseItemDto> mediaItems = await getTabItems(TabContentType.albums);
    // List<MediaItem> childItems = await _androidAutoHelper.getMediaItems(parentId);
  
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

  Future<void> showArtistsTemplate(MediaItem parent) async { 
    // Fetch child items of this type 
    List<BaseItemDto> mediaItems = await getTabItems(TabContentType.artists);

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
    List<BaseItemDto> artistTracks = await loadChildTracksFromBaseItem(baseItem: parent);
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

    for(final item in mostPlayedList) {
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;
      topTracks.items.add(CPListItem(
        text: item.name ?? "Unknown Name", // TODO localization
        image: imageUri.toString(),
        onPress: (complete, self) async {
          complete();
        }));
    }
    artistTemplate.sections.add(topTracks);

    for(final item in recentlyPlayedList) {
      final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;
      recentlyPlayed.items.add(CPListItem(
        text: item.name ?? "Unknown Name", // TODO localization
        image: imageUri.toString(),
        onPress: (complete, self) async {
          complete();
        }));
    }
    artistTemplate.sections.add(recentlyPlayed);

    await FlutterCarplay.push(template: artistTemplate);
  }
}