import 'dart:convert';

import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:finamp/services/music_screen_provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:audio_service/audio_service.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api_helper.dart';
import 'audio_service_helper.dart';
import 'playback_history_service.dart';
import 'queue_service.dart';
import 'item_helper.dart';
import 'radio_service_helper.dart' as radio;

final _carPlayLogger = Logger("CarPlay");

/// Maximum items to fetch from server for CarPlay lists.
/// Keeps UI responsive and avoids memory issues on car displays.
const _carPlayOnlineLimit = 250;

/// Maximum items to show in offline mode for CarPlay lists.
/// Higher than online since no network latency, but still limited for performance.
const _carPlayOfflineLimit = 1000;

/// Image size for CarPlay artwork. 100x100 is plenty for car displays
/// and transfers much faster than 200x200.
const _carPlayImageSize = 100;

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

  int get _carPlayItemLimit =>
      FinampSettingsHelper.finampSettings.isOffline ? _carPlayOfflineLimit : _carPlayOnlineLimit;

  final _queueService = GetIt.instance<QueueService>();

  /// Resolves the image URI for a CarPlay list item via [albumImageProvider],
  /// so CarPlay shares Finamp's image cache. Returns a `file://` URI for
  /// downloaded images and a network URL otherwise.
  String? _getCarPlayImageUri(BaseItemDto item) {
    if (item.imageId == null) return null;
    return providerRef
        .read(
          albumImageProvider(AlbumImageRequest(item: item, maxHeight: _carPlayImageSize, maxWidth: _carPlayImageSize)),
        )
        .uri
        ?.toString();
  }

  void setupCarplay() {
    _flutterCarplay.addListenerOnConnectionChange(onConnectionChange);

    // Listen for user login/logout changes and refresh CarPlay template
    _userSubscription = providerRef.listen(FinampUserHelper.finampCurrentUserProvider, (previous, next) {
      _carPlayLogger.info("User state changed, refreshing CarPlay template");
      setCarplayRootTemplate();
    });

    // Defer initial template setup until after the first frame is rendered.
    // This ensures GlobalSnackbar's context is available for localization.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      setCarplayRootTemplate();
    });
  }

  void disposeCarplay() {
    _userSubscription?.close();
    _closeTemplateSubscriptions();
    _flutterCarplay.removeListenerOnConnectionChange();
  }

  void onConnectionChange(ConnectionStatusTypes status) {
    connectionStatus = status;
    if (status == ConnectionStatusTypes.connected) {
      // Resume playback if there's a loaded queue that's paused
      final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
      if (_queueService.getCurrentTrack() != null && audioHandler.paused && isUserLoggedIn) {
        _carPlayLogger.info("CarPlay connected, resuming playback");
        try {
          audioHandler.play();
          FlutterCarplay.showSharedNowPlaying();
        } catch (e) {
          _carPlayLogger.warning("Failed to resume playback on CarPlay connect: $e");
        }
      }
    }
  }

  List<CPListSection> _groupItemsIntoSections(
    List<BaseItemDto> items,
    CPListItem Function(BaseItemDto item, int index) itemBuilder,
  ) {
    Map<String, List<CPListItem>> grouped = {};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // Use nameForSorting for bucketing so diacritic items (e.g. "Ärzte")
      // land under their base letter — Jellyfin strips diacritics server-side
      // when computing sortName.
      final name = item.nameForSorting ?? item.name ?? "";
      String letter = name.isNotEmpty ? name[0].toUpperCase() : "#";
      if (!RegExp(r'[A-Z]').hasMatch(letter)) {
        letter = "#";
      }

      grouped.putIfAbsent(letter, () => []);
      grouped[letter]!.add(itemBuilder(item, i));
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == "#") return 1;
        if (b == "#") return -1;
        return a.compareTo(b);
      });

    return sortedKeys.map((letter) => CPListSection(header: letter, items: grouped[letter]!)).toList();
  }

  /// Reused across calls: every new controller leaves permanently cached sort state behind.
  final _tabSortControllers = <ContentType, SortAndFilterController>{};

  /// premiereDate ascending matches getArtistAlbumsProvider's default order. Reused like [_tabSortControllers].
  static final _artistAlbumsSortController = SortAndFilterController(
    contentType: ContentType.tracks,
    startingConfig: const SortAndFilterConfiguration(
      sortBy: SortBy.premiereDate,
      sortOrder: SortOrder.ascending,
      filters: {},
    ),
  );

  /// A library tab request with the same sort settings and offline downgrade as the main UI.
  MusicScreenPlayable _tabPlayable(ContentType tab) {
    return MusicScreenPlayable(
      tab: tab,
      library: currentLibraryPlaceholder,
      source: QueueItemSource.rawId(
        type: QueueItemSourceType.filteredList,
        name: QueueItemSourceName(
          type: QueueItemSourceNameType.preTranslated,
          pretranslatedName: tab.toLocalisedString(GlobalSnackbar.requireL10n),
        ),
        id: "carplay-${tab.name}",
      ),
      sortConfig: _tabSortControllers
          .putIfAbsent(tab, () => SortAndFilterController.trackSettings(tab))
          .resolveConfig(),
    );
  }

  /// Holds list data alive for later taps. CarPlay has no pop event, so entries release on root rebuild.
  final List<ProviderSubscription> _templateSubscriptions = [];

  void _closeTemplateSubscriptions() {
    for (final subscription in _templateSubscriptions) {
      subscription.close();
    }
    _templateSubscriptions.clear();
  }

  Future<List<BaseItemDto>> _loadPagedItems(FinampPagedPlayable<FinampPlayableDto> request, int limit) async {
    _templateSubscriptions.add(providerRef.listen(pagedContentProvider(request), (_, _) {}));
    final (cached, pending) = providerRef.read(pagedContentProvider(request).notifier).loadSlice(0, limit);
    final items = pending == null ? cached : cached + (await pending);
    if (items.isEmpty) {
      // A failed page load resolves to empty. Rethrow so it doesn't render as an empty library.
      final error = providerRef.read(pagedContentProvider(request)).error;
      if (error != null) {
        // Reset the failed pages like the main UI retry button so the next tap refetches cleanly.
        providerRef.read(pagedContentProvider(request).notifier).retry();
        throw error;
      }
    }
    // pagedContentProvider isn't generic enough to express that children here are always FinampPlayableDto.
    return items.map((x) => (x as FinampPlayableDto).item).toList();
  }

  Future<void> _startSliceFromPlayable(FinampPlayable playable, {int index = 0, bool shuffled = false}) async {
    var slice = await providerRef.read(
      getPlayableSliceProvider(item: playable, startingOffset: shuffled ? 0 : index).future,
    );
    if (shuffled) {
      slice = slice.shuffle();
    }

    await _queueService.startSlicePlayback(slice);
    await FlutterCarplay.showSharedNowPlaying();
  }

  // playFromBaseItem is based on AndroidAutoHelper.playFromMediaId but using BaseItemDto
  Future<void> playItem(BaseItemDto item, {int index = 0, FinampPlaybackOrder? order}) => _startSliceFromPlayable(
    FinampPlayableDto.fromItem(item),
    index: index,
    shuffled: order == FinampPlaybackOrder.shuffled,
  );

  /// Shuffles all tracks using the shared shuffle handler, then shows CarPlay's Now Playing screen.
  Future<void> shuffleAllTracks() async {
    _carPlayLogger.info("Starting shuffle all tracks");
    final audioServiceHelper = GetIt.instance<AudioServiceHelper>();
    await audioServiceHelper.shuffleAll(onlyShowFavorites: false, itemCount: DefaultSettings.quickShuffleItemCount);
    await FlutterCarplay.showSharedNowPlaying();
  }

  Future<void> startRadio() async {
    _carPlayLogger.info("Starting radio");

    await _queueService.stopAndClearQueue();

    if (FinampSettingsHelper.finampSettings.isOffline) {
      // Offline: instant mix not available, fallback to shuffle
      await shuffleAllTracks();
      return;
    }

    // Fetch 1 random track and start continuous radio from it.
    // This starts playback in ~1 API call instead of the previous 3.
    final randomTracks = await _jellyfinApiHelper.getItems(
      parentItem: _finampUserHelper.currentUser?.currentView,
      includeItemTypes: "Audio",
      sortBy: "Random",
      limit: 1,
    );

    if (randomTracks != null && randomTracks.isNotEmpty) {
      _carPlayLogger.info("Starting continuous radio from: ${randomTracks.first.name}");
      FinampSetters.setRadioMode(RadioMode.continuous);
      await radio.startRadioPlayback(randomTracks.first);
      await FlutterCarplay.showSharedNowPlaying();
    } else {
      // Fallback to shuffle all if we can't get any tracks
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
    final history = GetIt.instance<PlaybackHistoryService>().history;
    // history is chronological (oldest first), take last N and reverse for most-recent-first
    return history.reversed.take(limit).map((h) => h.item).toList();
  }

  Future<List<CPListSection>> _buildHomeSections() async {
    List<CPListSection> sections = [];

    CPListSection quickActionsSection = CPListSection(
      items: [
        CPListItem(
          text: GlobalSnackbar.requireL10n.shuffleAll,
          onPress: (complete, self) async {
            await shuffleAllTracks();
            complete();
          },
        ),
        CPListItem(
          text: GlobalSnackbar.requireL10n.startRadio,
          onPress: (complete, self) async {
            await startRadio();
            complete();
          },
        ),
      ],
    );
    sections.add(quickActionsSection);

    final recentPlays = getRecentPlays(limit: 5);
    if (recentPlays.isNotEmpty) {
      CPListSection recentPlaysSection = CPListSection(header: GlobalSnackbar.requireL10n.recentlyPlayed, items: []);

      for (final queueItem in recentPlays) {
        final baseItem = queueItem.baseItem;

        recentPlaysSection.items.add(
          CPListItem(
            text: baseItem.name ?? GlobalSnackbar.requireL10n.unknown,
            detailText: baseItem.artists?.join(", ") ?? baseItem.albumArtist,
            image: _getCarPlayImageUri(baseItem),
            onPress: (complete, self) async {
              if (!FinampSettingsHelper.finampSettings.isOffline) {
                final audioServiceHelper = GetIt.instance<AudioServiceHelper>();
                await audioServiceHelper.startInstantMixForItem(baseItem);
              } else {
                await _queueService.startPlayback(
                  items: [baseItem],
                  source: QueueItemSource(
                    type: QueueItemSourceType.allTracks,
                    name: QueueItemSourceName(
                      type: QueueItemSourceNameType.preTranslated,
                      pretranslatedName: baseItem.name ?? GlobalSnackbar.requireL10n.tracks,
                    ),
                    id: baseItem.id,
                    item: baseItem,
                  ),
                  order: FinampPlaybackOrder.linear,
                );
              }
              complete();
              await FlutterCarplay.showSharedNowPlaying();
            },
          ),
        );
      }

      if (recentPlaysSection.items.isNotEmpty) {
        sections.add(recentPlaysSection);
      }
    }

    final recentlyAdded = await getRecentlyAddedAlbums(limit: 3);
    _carPlayLogger.info("Got ${recentlyAdded.length} recently added albums");
    if (recentlyAdded.isNotEmpty) {
      CPListSection recentlyAddedSection = CPListSection(header: GlobalSnackbar.requireL10n.recentlyAdded, items: []);

      for (final album in recentlyAdded) {
        recentlyAddedSection.items.add(
          CPListItem(
            text: album.name ?? GlobalSnackbar.requireL10n.unknownName,
            detailText: album.albumArtist,
            image: _getCarPlayImageUri(album),
            onPress: (complete, self) async {
              await showCollectionTracksTemplate(album);
              complete();
            },
          ),
        );
      }

      sections.add(recentlyAddedSection);
    }

    return sections;
  }

  Future<void> setCarplayRootTemplate() async {
    // A root rebuild discards the navigation stack, so release its paged requests.
    _closeTemplateSubscriptions();

    // Check if user is logged in first
    if (!isUserLoggedIn) {
      _carPlayLogger.info("User not logged in, showing login prompt on CarPlay");
      await _showLoginRequiredTemplate();
      return;
    }

    // Fetch home sections and library items in parallel
    final results = await Future.wait([
      _buildHomeSections(),
      GetIt.instance<MusicPlayerBackgroundTask>().getChildren(AudioService.browsableRootId),
    ]);

    final homeSections = results[0] as List<CPListSection>;
    List<MediaItem> rootItems = results[1] as List<MediaItem>;
    CPListSection librarySection = CPListSection(items: []);

    for (final item in rootItems) {
      librarySection.items.add(
        CPListItem(
          text: item.title,
          onPress: (complete, self) {
            final parentId = MediaItemId.fromJson(jsonDecode(item.id) as Map<String, dynamic>);

            switch (parentId.contentType) {
              case ContentType.albums:
              case ContentType.playlists:
              case ContentType.genres:
              case ContentType.mixed:
                showBrowsableListTemplate(tabType: parentId.contentType);
              case ContentType.albumArtists:
              case ContentType.performingArtists:
              case ContentType.genericArtists:
                showArtistsTemplate();
              case ContentType.tracks:
              case ContentType.inPlaylist:
              case ContentType.inPerformingArtistAlbums:
              case ContentType.inAlbumArtistAlbums:
                showTracksTemplate();
              case ContentType.home:
                return complete(); // already on home, no action
            }
            complete();
          },
        ),
      );
    }

    await FlutterCarplay.setRootTemplate(
      rootTemplate: CPTabBarTemplate(
        templates: [
          CPListTemplate(
            sections: homeSections,
            title: GlobalSnackbar.requireL10n.home,
            emptyViewTitleVariants: [GlobalSnackbar.requireL10n.home],
            emptyViewSubtitleVariants: [GlobalSnackbar.requireL10n.notAvailable],
            systemIcon: 'music.note.house',
            sectionIndexEnabled: false,
          ),
          CPListTemplate(
            sections: [],
            title: GlobalSnackbar.requireL10n.search,
            emptyViewTitleVariants: [GlobalSnackbar.requireL10n.voiceSearch],
            emptyViewSubtitleVariants: [GlobalSnackbar.requireL10n.carPlaySiriHint],
            systemIcon: 'mic',
          ),
          CPListTemplate(
            sections: [librarySection],
            title: GlobalSnackbar.requireL10n.library,
            emptyViewTitleVariants: [GlobalSnackbar.requireL10n.library],
            emptyViewSubtitleVariants: [GlobalSnackbar.requireL10n.emptyFilteredListTitle],
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
        title: GlobalSnackbar.requireL10n.finamp,
        emptyViewTitleVariants: [GlobalSnackbar.requireL10n.login],
        emptyViewSubtitleVariants: [GlobalSnackbar.requireL10n.carPlayLoginPrompt],
        systemIcon: 'person.crop.circle.badge.exclamationmark',
      ),
    );

    await _flutterCarplay.forceUpdateRootTemplate();
  }

  /// Shows the tracks within a single collection (album or playlist) as a
  /// scrollable list with a shuffle button, and plays on tap.
  Future<void> showCollectionTracksTemplate(BaseItemDto parent) async {
    if (_isPushingPageUpdate) {
      _carPlayLogger.warning("Navigation dropped: already pushing page update");
      return;
    }
    _isPushingPageUpdate = true;
    try {
      // Playlists keep their native order so the tapped row is the track that plays.
      List<BaseItemDto> mediaItems = await loadChildTracksFromBaseItem(
        item: parent,
        sortConfig: SortAndFilterConfiguration.defaultForItem(parent),
      );

      CPListSection playlistSection = CPListSection(items: []);

      playlistSection.items.add(
        CPListItem(
          text: GlobalSnackbar.requireL10n.shuffleButtonLabel,
          onPress: (complete, self) async {
            await playItem(parent, order: FinampPlaybackOrder.shuffled);
            complete();
          },
        ),
      );

      mediaItems.asMap().forEach((index, item) {
        playlistSection.items.add(
          CPListItem(
            text: item.name ?? GlobalSnackbar.requireL10n.unknownName,
            detailText: item.artists?.join(", ") ?? item.albumArtist,
            image: _getCarPlayImageUri(item),
            onPress: (complete, self) async {
              await playItem(parent, index: index);
              complete();
            },
          ),
        );
      });

      CPListTemplate playlistTemplate = CPListTemplate(sections: [playlistSection], systemIcon: 'gear');

      await FlutterCarplay.push(template: playlistTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  /// Shows a browsable list of items for a library tab (albums, playlists, or
  /// genres). Tapping an item drills down: genres show their albums, albums and
  /// playlists show their tracks via [showCollectionTracksTemplate].
  Future<void> showBrowsableListTemplate({required ContentType tabType, BaseItemDto? genreFilter}) async {
    if (_isPushingPageUpdate) {
      _carPlayLogger.warning("Navigation dropped: already pushing page update");
      return;
    }
    _isPushingPageUpdate = true;
    try {
      List<BaseItemDto> mediaItems;
      if (genreFilter != null) {
        final genre = Genre(
          genreFilter,
          source: QueueItemSource.fromBaseItem(genreFilter),
          sortConfig: SortAndFilterConfiguration.defaultSort,
          type: GenreChildType.albums,
          library: currentLibraryPlaceholder,
        );
        mediaItems = await _loadPagedItems(genre, _carPlayItemLimit);
      } else {
        mediaItems = await _loadPagedItems(_tabPlayable(tabType), _carPlayItemLimit);
      }

      final sections = _groupItemsIntoSections(mediaItems, (item, index) {
        return CPListItem(
          text: item.name ?? GlobalSnackbar.requireL10n.unknown,
          detailText: item.artists?.join(", ") ?? item.albumArtist,
          image: _getCarPlayImageUri(item),
          onPress: (complete, self) async {
            if (tabType == ContentType.genres && genreFilter == null) {
              await showBrowsableListTemplate(tabType: tabType, genreFilter: item);
            } else {
              await showCollectionTracksTemplate(item);
            }
            complete();
          },
        );
      });

      CPListTemplate albumsTemplate = CPListTemplate(sections: sections, systemIcon: 'square.stack');

      await FlutterCarplay.push(template: albumsTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  Future<void> showTracksTemplate() async {
    if (_isPushingPageUpdate) {
      _carPlayLogger.warning("Navigation dropped: already pushing page update");
      return;
    }
    _isPushingPageUpdate = true;
    try {
      // Taps replay this exact request so the index resolves against the displayed pages.
      final request = _tabPlayable(ContentType.tracks);
      final tracks = await _loadPagedItems(request, _carPlayItemLimit);

      final sections = _groupItemsIntoSections(tracks, (item, index) {
        return CPListItem(
          text: item.name ?? GlobalSnackbar.requireL10n.unknownName,
          detailText: item.artists?.join(", ") ?? item.albumArtist,
          image: _getCarPlayImageUri(item),
          onPress: (complete, self) async {
            await _startSliceFromPlayable(request, index: index);
            complete();
          },
        );
      });

      // Add shuffle button at the beginning
      if (sections.isNotEmpty) {
        sections.first.items.insert(
          0,
          CPListItem(
            text: GlobalSnackbar.requireL10n.shuffleAll,
            onPress: (complete, self) async {
              await shuffleAllTracks();
              complete();
            },
          ),
        );
      }

      CPListTemplate tracksTemplate = CPListTemplate(sections: sections, systemIcon: 'music.note');

      await FlutterCarplay.push(template: tracksTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  Future<void> showArtistsTemplate() async {
    if (_isPushingPageUpdate) {
      _carPlayLogger.warning("Navigation dropped: already pushing page update");
      return;
    }
    _isPushingPageUpdate = true;
    try {
      final artists = await _loadPagedItems(_tabPlayable(ContentType.albumArtists), _carPlayItemLimit);

      final sections = _groupItemsIntoSections(artists, (item, index) {
        return CPListItem(
          text: item.name ?? GlobalSnackbar.requireL10n.unknownName,
          onPress: (complete, self) async {
            await showArtistTemplate(item);
            complete();
          },
        );
      });

      CPListTemplate artistsTemplate = CPListTemplate(sections: sections, systemIcon: 'person.2');

      await FlutterCarplay.push(template: artistsTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  Future<void> showArtistTemplate(BaseItemDto parent) async {
    if (_isPushingPageUpdate) {
      _carPlayLogger.warning("Navigation dropped: already pushing page update");
      return;
    }
    _isPushingPageUpdate = true;
    try {
      _carPlayLogger.info("Loading artist template for ${parent.name}");

      CPListTemplate artistTemplate = CPListTemplate(sections: [], systemIcon: 'gear');
      CPListSection artistAlbums = CPListSection(header: GlobalSnackbar.requireL10n.albums, items: []);

      _carPlayLogger.fine("Fetching albums for artist ${parent.name}");
      final artist = Artist(
        parent,
        source: QueueItemSource.fromBaseItem(parent),
        sortConfig: _artistAlbumsSortController.resolveConfig(),
        type: ArtistChildType.albumsFromArtist,
        library: currentLibraryPlaceholder,
      );
      final artistAlbumsList = (await providerRef.read(
        getChildrenProvider(item: artist).future,
      )).map((x) => (x as FinampPlayableDto).item).toList();
      _carPlayLogger.fine("Got ${artistAlbumsList.length} albums");

      artistAlbums.items.add(
        CPListItem(
          text: GlobalSnackbar.requireL10n.shuffleAll,
          onPress: (complete, self) async {
            await playItem(parent, order: FinampPlaybackOrder.shuffled);
            complete();
          },
        ),
      );

      for (final item in artistAlbumsList) {
        artistAlbums.items.add(
          CPListItem(
            text: item.name ?? GlobalSnackbar.requireL10n.unknownName,
            image: _getCarPlayImageUri(item),
            onPress: (complete, self) async {
              await showCollectionTracksTemplate(item);
              complete();
            },
          ),
        );
      }
      artistTemplate.sections.add(artistAlbums);

      _carPlayLogger.info("Pushing artist template with ${artistAlbumsList.length} albums");
      await FlutterCarplay.push(template: artistTemplate);
    } finally {
      _isPushingPageUpdate = false;
    }
  }
}
