import 'dart:convert';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'audio_service_helper.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api_helper.dart';
import 'queue_service.dart';
import 'item_helper.dart';
import 'artist_content_provider.dart';

/// Helper to access localized strings without a BuildContext.
/// Uses the global scaffold key's context for localization.
AppLocalizations get _l10n =>
    AppLocalizations.of(GlobalSnackbar.materialAppScaffoldKey.currentContext!)!;

final _carPlayLogger = Logger("CarPlay");

/// Maximum items to fetch from server for CarPlay lists.
/// Keeps UI responsive and avoids memory issues on car displays.
const _carPlayOnlineLimit = 250;

/// Maximum items to show in offline mode for CarPlay lists.
/// Higher than online since no network latency, but still limited for performance.
const _carPlayOfflineLimit = 1000;

class CarPlayHelper {
  ConnectionStatusTypes connectionStatus = ConnectionStatusTypes.unknown;
  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  bool _isPushingPageUpdate = false;

  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _downloadsService = GetIt.instance<DownloadsService>();
  final providerRef = GetIt.instance<ProviderContainer>();

  ProviderSubscription? _userSubscription;

  bool get isUserLoggedIn => _finampUserHelper.currentUser != null;

  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _queueService = GetIt.instance<QueueService>();

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

    // Defer initial template setup until after the first frame is rendered.
    // This ensures GlobalSnackbar's context is available for localization.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      setCarplayRootTemplate();
    });
  }

  void disposeCarplay() {
    _userSubscription?.close();
    _flutterCarplay.removeListenerOnConnectionChange();
  }

  void onConnectionChange(ConnectionStatusTypes status) {
    if (status == ConnectionStatusTypes.connected) {
    }
  }

  List<CPListSection> _groupItemsIntoSections(
    List<BaseItemDto> items,
    CPListItem Function(BaseItemDto item, int index) itemBuilder,
  ) {
    Map<String, List<CPListItem>> grouped = {};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final name = item.name ?? "";
      String letter = name.isNotEmpty ? name[0].toUpperCase() : "#";
      if (!RegExp(r'[A-Z]').hasMatch(letter)) {
        letter = "#";
      }

      grouped.putIfAbsent(letter, () => []);
      grouped[letter]!.add(itemBuilder(item, i));
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == "#") return 1;
      if (b == "#") return -1;
      return a.compareTo(b);
    });

    return sortedKeys.map((letter) => CPListSection(
      header: letter,
      items: grouped[letter]!,
    )).toList();
  }

  Future<List<BaseItemDto>> getTabItems ({required TabContentType tabContentType}) async {
    final sortBy = FinampSettingsHelper.finampSettings.getTabSortBy(tabContentType);
    final sortOrder = FinampSettingsHelper.finampSettings.getSortOrder(tabContentType);
    
    // If we are in offline mode, display all matching downloaded parents 
    if (FinampSettingsHelper.finampSettings.isOffline) {
      List<BaseItemDto> baseItems = [];
      for (final downloadedParent in await _downloadsService.getAllCollections()) {
        if (baseItems.length >= _carPlayOfflineLimit) break;
        if (downloadedParent.baseItem != null && downloadedParent.baseItemType == tabContentType.itemType) {
          baseItems.add(downloadedParent.baseItem!);
        }
      }
      return sortItems(baseItems, sortBy, sortOrder);
    }
    
    // Fetch the online version if we can't get the offline versions
    final items = await _jellyfinApiHelper.getItems(
      parentItem: tabContentType.itemType == BaseItemDtoType.playlist ? null : _finampUserHelper.currentUser?.currentView,
      includeItemTypes: tabContentType.itemType.jellyfinName,
      sortBy: sortBy.jellyfinName(tabContentType),
      sortOrder: tabContentType == TabContentType.tracks ? null : sortOrder.toString(),
      limit: _carPlayOnlineLimit,
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
              (album.albumArtists?.any((aa) => aa.id == artist.id) ?? false)) {
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
      limit: _carPlayOnlineLimit,
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
          pretranslatedName: sourceName ?? _l10n.tracks,
        ),
        id: "carplay-tracks-${DateTime.now().millisecondsSinceEpoch}",
      ),
      order: order,
      startingIndex: order == FinampPlaybackOrder.linear ? index : null,
    );
  }

  Future<void> shuffleAllTracks() async {
    _carPlayLogger.info("Starting shuffle all tracks");
    await _audioServiceHelper.shuffleAll(onlyShowFavorites: false);
  }

  Future<void> startInstantMix() async {
    // Build a pool of albums from two sources for variety:
    // - Frequently played albums
    // - Random albums
    // Then pick a random album to seed the instant mix.
    _carPlayLogger.info("Starting instant mix");

    if (FinampSettingsHelper.finampSettings.isOffline) {
      // Offline: instant mix not available, fallback to shuffle
      await shuffleAllTracks();
      return;
    }

    final List<BaseItemDto> albumPool = [];

    // Get 5 most frequently played albums
    final frequentAlbums = await _jellyfinApiHelper.getItems(
      parentItem: _finampUserHelper.currentUser?.currentView,
      includeItemTypes: "MusicAlbum",
      sortBy: "PlayCount",
      sortOrder: "Descending",
      limit: 5,
    );
    if (frequentAlbums != null) {
      albumPool.addAll(frequentAlbums);
    }

    // Get 5 random albums for discovery
    final randomAlbums = await _jellyfinApiHelper.getItems(
      parentItem: _finampUserHelper.currentUser?.currentView,
      includeItemTypes: "MusicAlbum",
      sortBy: "Random",
      limit: 5,
    );
    if (randomAlbums != null) {
      // Avoid duplicates
      for (final album in randomAlbums) {
        if (!albumPool.any((a) => a.id == album.id)) {
          albumPool.add(album);
        }
      }
    }

    if (albumPool.isNotEmpty) {
      final randomAlbum = albumPool[DateTime.now().millisecondsSinceEpoch % albumPool.length];
      _carPlayLogger.info("Starting instant mix from: ${randomAlbum.name}");
      await _audioServiceHelper.startInstantMixForItem(randomAlbum);
    } else {
      // Fallback to shuffle all if we can't get any albums
      await shuffleAllTracks();
    }
  }

  Future<List<BaseItemDto>> getRecentlyAddedAlbums({int limit = 10}) async {
    if (FinampSettingsHelper.finampSettings.isOffline) {
      // Offline: get downloaded albums
      final allAlbums = await _downloadsService.getAllCollections();
      final albums = allAlbums
          .where((d) => d.baseItemType == BaseItemDtoType.album && d.baseItem != null)
          .map((d) => d.baseItem!)
          .take(limit)
          .toList();
      return albums;
    }

    final albums = await _jellyfinApiHelper.getItems(
      parentItem: _finampUserHelper.currentUser?.currentView,
      includeItemTypes: "MusicAlbum",
      sortBy: "DateCreated",
      sortOrder: "Descending",
      limit: limit,
    );
    return albums ?? [];
  }

  List<FinampQueueItem> getRecentPlays({int limit = 5}) {
    return _queueService.peekQueue(previous: limit);
  }

  Future<List<CPListSection>> _buildHomeSections() async {
    List<CPListSection> sections = [];

    CPListSection quickActionsSection = CPListSection(
      items: [
        CPListItem(
          text: _l10n.shuffleAll,
          onPress: (complete, self) async {
            await shuffleAllTracks();
            complete();
          },
        ),
        CPListItem(
          text: _l10n.startMix,
          onPress: (complete, self) async {
            await startInstantMix();
            complete();
          },
        ),
      ],
    );
    sections.add(quickActionsSection);

    final recentPlays = getRecentPlays(limit: 5);
    if (recentPlays.isNotEmpty) {
      CPListSection recentPlaysSection = CPListSection(
        header: _l10n.recentlyPlayed,
        items: [],
      );

      for (final queueItem in recentPlays) {
        final baseItem = queueItem.baseItem;
        final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: baseItem, maxHeight: 200, maxWidth: 200))).uri;

        recentPlaysSection.items.add(CPListItem(
          text: baseItem.name ?? _l10n.unknown,
          detailText: baseItem.artists?.join(", ") ?? baseItem.albumArtist,
          image: imageUri?.toString(),
          onPress: (complete, self) async {
            await _queueService.startPlayback(
              items: [baseItem],
              source: QueueItemSource(
                type: QueueItemSourceType.nextUp,
                name: QueueItemSourceName(
                  type: QueueItemSourceNameType.preTranslated,
                  pretranslatedName: baseItem.name ?? _l10n.tracks,
                ),
                id: baseItem.id,
                item: baseItem,
              ),
              order: FinampPlaybackOrder.linear,
            );
            complete();
          },
        ));
      }

      if (recentPlaysSection.items.isNotEmpty) {
        sections.add(recentPlaysSection);
      }
    }

    final recentlyAdded = await getRecentlyAddedAlbums(limit: 3);
    _carPlayLogger.info("Got ${recentlyAdded.length} recently added albums");
    if (recentlyAdded.isNotEmpty) {
      CPListSection recentlyAddedSection = CPListSection(
        header: _l10n.recentlyAdded,
        items: [],
      );

      for (final album in recentlyAdded) {
        final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: album, maxHeight: 200, maxWidth: 200))).uri;

        recentlyAddedSection.items.add(CPListItem(
          text: album.name ?? _l10n.unknownAlbum,
          detailText: album.albumArtist,
          image: imageUri?.toString(),
          onPress: (complete, self) async {
            await showPlaylistTemplate(album);
            complete();
          },
        ));
      }

      sections.add(recentlyAddedSection);
    }

    return sections;
  }

  Future<void> setCarplayRootTemplate() async {
    // Check if user is logged in first
    if (!isUserLoggedIn) {
      _carPlayLogger.info("User not logged in, showing login prompt on CarPlay");
      await _showLoginRequiredTemplate();
      return;
    }

    final homeSections = await _buildHomeSections();

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
            sections: homeSections,
            title: _l10n.home,
            emptyViewTitleVariants: [_l10n.home],
            emptyViewSubtitleVariants: [_l10n.notAvailable],
            systemIcon: 'music.note.house',
          ),
          CPListTemplate(
            sections: [],
            title: _l10n.search,
            emptyViewTitleVariants: [_l10n.voiceSearch],
            emptyViewSubtitleVariants: [_l10n.carPlaySiriHint],
            systemIcon: 'mic',
          ),
          CPListTemplate(
            sections: [librarySection],
            title: _l10n.library,
            emptyViewTitleVariants: [_l10n.library],
            emptyViewSubtitleVariants: [_l10n.emptyFilteredListTitle],
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
        title: _l10n.finamp,
        emptyViewTitleVariants: [_l10n.login],
        emptyViewSubtitleVariants: [_l10n.carPlayLoginPrompt],
        systemIcon: 'person.crop.circle.badge.exclamationmark',
      ),
    );

    await _flutterCarplay.forceUpdateRootTemplate();
  }

  Future<void> showPlaylistTemplate(BaseItemDto parent) async {
    if (_isPushingPageUpdate) return;
    _isPushingPageUpdate = true;
    try {
      List<BaseItemDto> mediaItems = await loadChildTracksFromBaseItem(baseItem: parent);

      CPListSection playlistSection = CPListSection(items: []);

      playlistSection.items.add(CPListItem(
        text: _l10n.shuffleButtonLabel,
        onPress: (complete, self) async {
          await playItem(parent, order: FinampPlaybackOrder.shuffled);
          complete();
        },
      ));

      mediaItems.asMap().forEach((index, item) {
        final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;

        playlistSection.items.add(CPListItem(
          text: item.name ?? _l10n.unknownName,
          detailText: item.artists?.join(", ") ?? item.albumArtist,
          image: imageUri?.toString(),
          onPress: (complete, self) async {
            await playItem(parent, index: index);
            complete();
          },
        ));
      });

      CPListTemplate playlistTemplate = CPListTemplate(
        sections: [playlistSection],
        systemIcon: 'gear',
      );

      await FlutterCarplay.push(template: playlistTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  Future<void> showAlbumsTemplate({required TabContentType tabType}) async {
    if (_isPushingPageUpdate) return;
    _isPushingPageUpdate = true;
    try {
      List<BaseItemDto> mediaItems = await getTabItems(tabContentType: tabType);

      final sections = _groupItemsIntoSections(mediaItems, (item, index) {
        final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;

        return CPListItem(
          text: item.name ?? _l10n.unknown,
          detailText: item.artists?.join(", ") ?? item.albumArtist,
          image: imageUri?.toString(),
          onPress: (complete, self) async {
            await showPlaylistTemplate(item);
            complete();
          },
        );
      });

      CPListTemplate albumsTemplate = CPListTemplate(
        sections: sections,
        systemIcon: 'square.stack',
      );

      await FlutterCarplay.push(template: albumsTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  Future<void> showTracksTemplate() async {
    if (_isPushingPageUpdate) return;
    _isPushingPageUpdate = true;
    try {
      List<BaseItemDto> tracks;
      if (FinampSettingsHelper.finampSettings.isOffline) {
        tracks = await getTabItems(tabContentType: TabContentType.tracks);
        if (tracks.length > _carPlayOnlineLimit) {
          tracks = tracks.sublist(0, _carPlayOnlineLimit);
        }
      } else {
        tracks = await _jellyfinApiHelper.getItems(
          parentItem: _finampUserHelper.currentUser?.currentView,
          includeItemTypes: "Audio",
          sortBy: "SortName",
          limit: _carPlayOnlineLimit,
        ) ?? [];
      }

      CPListSection trackSection = CPListSection(items: [
        CPListItem(
          text: _l10n.shuffleAll,
          onPress: (complete, self) async {
            await shuffleAllTracks();
            complete();
          },
        ),
      ]);

      for (int i = 0; i < tracks.length; i++) {
        final item = tracks[i];
        final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;

        trackSection.items.add(CPListItem(
          text: item.name ?? _l10n.unknownName,
          detailText: item.artists?.join(", ") ?? item.albumArtist,
          image: imageUri?.toString(),
          onPress: (complete, self) async {
            await playTracksAsQueue(tracks, index: i, sourceName: _l10n.tracks);
            complete();
          },
        ));
      }

      CPListTemplate tracksTemplate = CPListTemplate(
        sections: [trackSection],
        systemIcon: 'music.note',
      );

      await FlutterCarplay.push(template: tracksTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  Future<void> showArtistsTemplate() async {
    if (_isPushingPageUpdate) return;
    _isPushingPageUpdate = true;
    try {
      List<BaseItemDto> artists;
      if (FinampSettingsHelper.finampSettings.isOffline) {
        artists = await getTabItems(tabContentType: TabContentType.artists);
        if (artists.length > _carPlayOnlineLimit) {
          artists = artists.sublist(0, _carPlayOnlineLimit);
        }
      } else {
        artists = await _jellyfinApiHelper.getItems(
          parentItem: _finampUserHelper.currentUser?.currentView,
          includeItemTypes: "MusicArtist",
          sortBy: "SortName",
          limit: _carPlayOnlineLimit,
        ) ?? [];
      }

      CPListSection artistSection = CPListSection(items: []);

      for (final item in artists) {
        artistSection.items.add(CPListItem(
          text: item.name ?? _l10n.unknownName,
          onPress: (complete, self) async {
            await showArtistTemplate(item);
            complete();
          },
        ));
      }

      CPListTemplate artistsTemplate = CPListTemplate(
        sections: [artistSection],
        systemIcon: 'person.2',
      );

      await FlutterCarplay.push(template: artistsTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }
  
  Future<void> showArtistTemplate(BaseItemDto parent) async {
    if (_isPushingPageUpdate) return;
    _isPushingPageUpdate = true;
    try {
      _carPlayLogger.info("Loading artist template for ${parent.name}");

      CPListTemplate artistTemplate = CPListTemplate(sections: [], systemIcon: 'gear');
      CPListSection artistAlbums = CPListSection(header: _l10n.albums, items: []);

      _carPlayLogger.fine("Fetching albums for artist ${parent.name}");
      List<BaseItemDto> artistAlbumsList = await GetIt.instance<ProviderContainer>()
          .read(getArtistAlbumsProvider(artist: parent, libraryFilter: _finampUserHelper.currentUser?.currentView).future);
      _carPlayLogger.fine("Got ${artistAlbumsList.length} albums");

      artistAlbums.items.add(CPListItem(
        text: _l10n.shuffleAll,
        onPress: (complete, self) async {
          final tracks = await getArtistTracks(parent);
          await playTracksAsQueue(tracks, order: FinampPlaybackOrder.shuffled, sourceName: parent.name ?? _l10n.unknownName);
          complete();
        },
      ));

      for (final item in artistAlbumsList) {
        final imageUri = providerRef.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri;

        artistAlbums.items.add(CPListItem(
          text: item.name ?? _l10n.unknownName,
          image: imageUri?.toString(),
          onPress: (complete, self) async {
            await showPlaylistTemplate(item);
            complete();
          },
        ));
      }
      artistTemplate.sections.add(artistAlbums);

      _carPlayLogger.info("Pushing artist template with ${artistAlbumsList.length} albums");
      await FlutterCarplay.push(template: artistTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }
}