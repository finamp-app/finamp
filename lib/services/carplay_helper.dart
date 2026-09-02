import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:finamp/services/music_screen_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:audio_service/audio_service.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

import 'favorite_provider.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'audio_service_helper.dart';
import 'queue_service.dart';
import 'item_helper.dart';
import 'radio_service_helper.dart' as radio;
import 'item_by_id_provider.dart';

final _carPlayLogger = Logger("CarPlay");

/// Fallback item cap used when CarPlay's runtime `maximumItemCount` can't be
/// queried (older head units, or the query failing outright).
const _fallbackMaxListItems = 250;

/// Sections the letter picker occupies: one per letter, plus "#".
const _letterSectionCount = 27;

/// Fallback section cap, same reasoning as [_fallbackMaxListItems]. Covers the
/// letter picker plus a leading action row.
const _fallbackMaxListSections = _letterSectionCount + 1;

/// Debug override for testing progressive loading and the letter picker
/// without a huge library, e.g. `--dart-define=CARPLAY_ITEM_CAP=30`. 0 means
/// "use the head unit's real cap".
const _itemCapOverride = int.fromEnvironment('CARPLAY_ITEM_CAP', defaultValue: 0);

/// Debug override for the section cap, same convention as [_itemCapOverride].
/// Below [_letterSectionCount] it exercises the flat-list fallback.
const _sectionCapOverride = int.fromEnvironment('CARPLAY_SECTION_CAP', defaultValue: 0);

/// Online Tracks skips the letter picker: Jellyfin bakes track numbers into
/// each track's SortName, which the NameStartsWith letter filter compares
/// against, so every track lands under "#". Flipping this to true is the
/// only change needed once the server fixes Audio SortName.
const _enableOnlineTracksLetterPicker = false;

/// Image size for CarPlay artwork. 100x100 is plenty for car displays
/// and transfers much faster than 200x200.
const _carPlayImageSize = 100;

/// First page size for CarPlay lists, kept small so lists appear quickly.
/// The background fill catches up in [musicScreenPageSize] chunks.
const _carPlayFirstPageSize = 30;

/// Albums shown in the CarPlay home Recently Added art row.
const _carPlayRecentlyAddedLimit = 6;

/// Tracks shown in the CarPlay home Recently Played row.
const _carPlayRecentlyPlayedLimit = 5;

/// Maximum number of queues to show in the CarPlay home "Recent Queues" art
/// row, before clamping to the plugin's runtime grid-image limit.
const _maxRecentQueues = 6;

/// Last resort artwork stand-in when the rendered placeholder tile is unavailable.
const _carPlayFallbackImage = 'sfsymbol:music.note.list';

/// Number of distinct albums composed into a Recent Queues collage cover,
/// and the side length in pixels of each tile within it.
const _collageTileCount = 4;
const _collageTileSize = 100;

/// Maximum number of upcoming tracks to resolve while hunting for
/// [_collageTileCount] distinct albums for a queue's collage cover, so a
/// huge queue doesn't spam the server with lookups.
const _maxCollageTrackScan = 20;

class CarPlayHelper {
  ConnectionStatusTypes connectionStatus = ConnectionStatusTypes.unknown;
  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  bool _isPushingPageUpdate = false;

  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final providerRef = GetIt.instance<ProviderContainer>();

  ProviderSubscription? _userSubscription;
  ProviderSubscription? _favoriteSubscription;
  ProviderSubscription? _offlineSubscription;
  StreamSubscription<FinampQueueItem?>? _currentTrackSubscription;
  StreamSubscription<FinampPlaybackOrder>? _playbackOrderSubscription;
  StreamSubscription<BoxEvent>? _queueHistorySubscription;
  Timer? _homeRefreshTimer;
  CPListTemplate? _homeTemplate;
  bool _isSettingRootTemplate = false;
  bool _isUpdatingNowPlayingButtons = false;
  int _recentQueueImageFillRun = 0;
  BaseItemId? _nowPlayingButtonsTrackId;

  bool get isUserLoggedIn => _finampUserHelper.currentUser != null;

  final _queueService = GetIt.instance<QueueService>();

  /// Runtime caps from `CPListTemplate.getMaximum*Count()`, reset on every
  /// CarPlay connect since different head units allow different caps. A
  /// failed query falls back to the consts above and is re-queried.
  int? _cachedMaxListItems;
  int? _cachedMaxListSections;

  Future<int> _getMaxListItems() async {
    if (_itemCapOverride > 0) return _itemCapOverride;
    final reported = _cachedMaxListItems ??= await CPListTemplate.getMaximumItemCount() ?? _fallbackMaxListItems;
    // Guard against a head unit reporting a nonsense cap of 0.
    return reported > 0 ? reported : _fallbackMaxListItems;
  }

  Future<int> _getMaxListSections() async {
    if (_sectionCapOverride > 0) return _sectionCapOverride;
    final reported = _cachedMaxListSections ??=
        await CPListTemplate.getMaximumSectionCount() ?? _fallbackMaxListSections;
    return reported > 0 ? reported : _fallbackMaxListSections;
  }

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

    _userSubscription = providerRef.listen(FinampUserHelper.finampCurrentUserProvider, (previous, next) {
      _carPlayLogger.info("User state changed, refreshing CarPlay template");
      setCarplayRootTemplate();
      _updateNowPlayingButtons();
    });

    // Keep the Now Playing buttons in sync with the current track (also
    // re-subscribes the favourite-status listener below to the new track).
    // Subscribed to the queue's own current-track stream rather than
    // audioHandler.mediaItem, since that emits on metadata-only updates
    // (e.g. artwork loading) and never emits once the queue empties.
    _currentTrackSubscription = _queueService.getCurrentTrackStream().listen((track) {
      final trackId = track?.baseItem.id;
      if (trackId == _nowPlayingButtonsTrackId) return;
      _nowPlayingButtonsTrackId = trackId;
      _subscribeToCurrentTrackFavorite();
      _updateNowPlayingButtons();
    });
    _subscribeToCurrentTrackFavorite();
    _updateNowPlayingButtons();

    // Favourite/start-mix are unavailable offline, so refresh the buttons
    // whenever offline mode is toggled.
    _offlineSubscription = providerRef.listen(finampSettingsProvider.isOffline, (previous, next) {
      _updateNowPlayingButtons();
    });

    // Keep the shuffle button's glyph in sync with the queue's playback
    // order.
    _playbackOrderSubscription = _queueService.getPlaybackOrderStream().listen((order) {
      _updateNowPlayingButtons();
    });

    // Rebuild the home tab when a queue is archived into history so the
    // Recent Queues row appears without reopening the app. The live queue
    // saves constantly under the "latest" key, so only react to other keys.
    _queueHistorySubscription = Hive.box<FinampStorableQueueInfo>("Queues").watch().listen((event) {
      if (event.key == "latest") {
        return;
      }
      _homeRefreshTimer?.cancel();
      _homeRefreshTimer = Timer(const Duration(seconds: 2), () {
        _refreshHomeSections();
      });
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
    _favoriteSubscription?.close();
    _offlineSubscription?.close();
    _currentTrackSubscription?.cancel();
    _playbackOrderSubscription?.cancel();
    _queueHistorySubscription?.cancel();
    _homeRefreshTimer?.cancel();
    _flutterCarplay.removeListenerOnConnectionChange();
  }

  void onConnectionChange(ConnectionStatusTypes status) {
    connectionStatus = status;
    if (status == ConnectionStatusTypes.connected) {
      // Different head units allow different caps, so don't carry over a
      // previous connection's cached values.
      _cachedMaxListItems = null;
      _cachedMaxListSections = null;

      // The Now Playing template is a system-owned singleton that can be
      // presented unprompted on connect, so its buttons can't wait for the next
      // track or order change.
      _updateNowPlayingButtons();

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

  /// (Re-)subscribes to favourite-status changes for the current track so the
  /// Now Playing heart button stays in sync when the track is favourited or
  /// unfavourited (from the phone UI, another button press, etc).
  void _subscribeToCurrentTrackFavorite() {
    _favoriteSubscription?.close();
    final currentTrack = _queueService.getCurrentTrack()?.baseItem;
    if (currentTrack == null) {
      _favoriteSubscription = null;
      return;
    }
    _favoriteSubscription = providerRef.listen(isFavoriteProvider(currentTrack), (previous, next) {
      _updateNowPlayingButtons();
    });
  }

  /// Builds and sends the CarPlay Now Playing screen buttons: shuffle
  /// toggle, favourite, and start instant mix (leading to trailing). Shows
  /// no buttons when logged out and hides favourite/mix when there is no
  /// current track or while offline.
  ///
  /// Overlapping calls are ignored.
  Future<void> _updateNowPlayingButtons() async {
    if (_isUpdatingNowPlayingButtons) {
      return;
    }
    _isUpdatingNowPlayingButtons = true;
    try {
      await _sendNowPlayingButtons();
    } finally {
      _isUpdatingNowPlayingButtons = false;
    }
  }

  Future<void> _sendNowPlayingButtons() async {
    if (!isUserLoggedIn) {
      await FlutterCarplay.setNowPlayingButtons([]);
      return;
    }

    final currentTrack = _queueService.getCurrentTrack()?.baseItem;
    final isOffline = FinampSettingsHelper.finampSettings.isOffline;

    final isShuffled = _queueService.playbackOrder == FinampPlaybackOrder.shuffled;
    final shuffleIcon =
        await _getIconFontImageUri(isShuffled ? TablerIcons.arrows_shuffle : TablerIcons.arrows_right, 40) ??
        'sfsymbol:shuffle';
    final buttons = <CPNowPlayingButton>[
      CPNowPlayingImageButton(image: shuffleIcon, onPress: () => _queueService.togglePlaybackOrder()),
    ];

    if (currentTrack != null && !isOffline) {
      final isFavorite = providerRef.read(isFavoriteProvider(currentTrack));
      final heartIcon =
          await _getIconFontImageUri(isFavorite ? TablerIcons.heart_filled : TablerIcons.heart, 40) ??
          (isFavorite ? 'sfsymbol:heart.fill' : 'sfsymbol:heart');
      buttons.add(
        CPNowPlayingImageButton(
          image: heartIcon,
          onPress: () => GetIt.instance<MusicPlayerBackgroundTask>().toggleFavoriteStatusOfCurrentTrack(),
        ),
      );

      final mixIcon = await _getIconFontImageUri(TablerIcons.radio, 40) ?? 'sfsymbol:radio';
      buttons.add(
        CPNowPlayingImageButton(
          image: mixIcon,
          onPress: () async {
            // Read the track at press time. The plugin keeps earlier
            // callbacks alive when a button update is skipped as redundant.
            final track = _queueService.getCurrentTrack()?.baseItem;
            if (track == null) return;
            try {
              _carPlayLogger.info("Mix button pressed, starting an instant mix from '${track.name}'");
              FinampSetters.setRadioMode(RadioMode.similar);
              await radio.startRadioPlayback(track);
            } catch (e) {
              _carPlayLogger.severe("Starting instant mix failed: $e");
              GlobalSnackbar.error(e);
            }
          },
        ),
      );
    }

    await FlutterCarplay.setNowPlayingButtons(buttons);
  }

  List<CPListSection> _groupItemsIntoSections(
    List<BaseItemDto> items,
    CPListItem Function(BaseItemDto item, int index) itemBuilder,
  ) {
    Map<String, List<CPListItem>> grouped = {};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // Buckets on nameForSorting, so diacritic items (e.g. "Ärzte") land under
      // their base letter like Jellyfin's server-side sortName. Must stay in
      // step with the offline letter filter in music_screen_provider.dart.
      final letter = letterBucketOf(item);

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

  /// Cancel unfinished list loads.
  final List<void Function()> _pendingLoadCancellers = [];

  void _closeTemplateSubscriptions() {
    // Cancel pending loads first
    for (final cancel in List.of(_pendingLoadCancellers)) {
      cancel();
    }
    _pendingLoadCancellers.clear();
    for (final subscription in _templateSubscriptions) {
      subscription.close();
    }
    _templateSubscriptions.clear();
  }

  /// Loads up to [limit] items by subscribing to the paged provider and
  /// requesting more pages until it has enough or the list is exhausted,
  /// rather than reaching into the notifier for a one-shot slice.
  Future<List<BaseItemDto>> _loadPagedItems(FinampPagedPlayable<FinampPlayableDto> request, int limit) async {
    final provider = pagedContentProvider(request);
    final completer = Completer<List<FinampDisplayableOrPlayable>>();

    if (providerRef.read(provider).error != null) {
      providerRef.read(provider.notifier).retry();
    }

    // Retain the paged data so it survives for later taps, until the next root
    // rebuild releases it.
    _templateSubscriptions.add(providerRef.listen(provider, (_, _) {}));

    // Whatever closes this driver subscription must also settle the completer, or the caller hangs
    ProviderSubscription? driver;
    driver = providerRef.listen<PagingState<int, FinampDisplayableOrPlayable>>(provider, fireImmediately: true, (
      _,
      next,
    ) {
      if (completer.isCompleted || next.isLoading) return;
      final items = next.items ?? [];
      if (items.length < limit && next.hasNextPage && next.error == null) {
        providerRef.read(provider.notifier).newPage(pageSize: limit - items.length);
        return;
      }
      // Surface an error only when nothing is cached, so a partial page still
      // renders rather than showing an empty library.
      if (next.error != null && items.isEmpty) {
        completer.completeError(next.error!);
      } else {
        completer.complete(items);
      }
      driver?.close();
    });
    // listen() delivers its first value before `driver` is assigned, so close that subscription here
    if (completer.isCompleted) {
      driver.close();
    }

    // Stop paging and settle the caller with whatever is cached
    void cancel() {
      if (!completer.isCompleted) {
        completer.complete(providerRef.read(provider).items ?? []);
      }
      driver?.close();
    }

    _pendingLoadCancellers.add(cancel);
    try {
      final items = await completer.future;
      // pagedContentProvider isn't generic enough to express that children here are always FinampPlayableDto.
      return items.take(limit).map((x) => (x as FinampPlayableDto).item).toList();
    } finally {
      _pendingLoadCancellers.remove(cancel);
    }
  }

  /// Reads the sort config off a library tab request, regardless of whether
  /// it's a top-level [MusicScreenPlayable] or a [Genre] drill-down.
  ResolvedSortConfig _sortConfigOf(FinampPagedPlayable<FinampPlayableDto> request) => switch (request) {
    Genre<FinampPlayableDto>() => request.sortConfig,
    MusicScreenPlayable<FinampPlayableDto>() => request.sortConfig,
  };

  /// Converts [request] to the equivalent [MusicScreenPlayable], so
  /// `musicScreenItemCountProvider` has a single request shape to key off.
  MusicScreenPlayable<FinampPlayableDto> _asMusicScreenRequest(FinampPagedPlayable<FinampPlayableDto> request) {
    return switch (request) {
      Genre<FinampPlayableDto>() => request.getMusicScreenRequest(),
      MusicScreenPlayable<FinampPlayableDto>() => request,
    };
  }

  /// Replaces [request]'s letter filter, forcing ascending sort-name order
  /// (see [ResolvedSortConfig.copyWithLetter]). The distinct filter set
  /// gives each letter its own `pagedContentProvider` cache entry.
  FinampPagedPlayable<FinampPlayableDto> _withLetter(FinampPagedPlayable<FinampPlayableDto> request, String letter) {
    return switch (request) {
      Genre<FinampPlayableDto>() => request.copyWith(request.sortConfig.copyWithLetter(letter)),
      MusicScreenPlayable<FinampPlayableDto>() => request.copyWith(request.sortConfig.copyWithLetter(letter)),
    };
  }

  /// Whether [tab] can show the letter picker. See
  /// [_enableOnlineTracksLetterPicker] for why online Tracks is excluded.
  bool _letterLayerSupported(ContentType tab) =>
      FinampSettingsHelper.finampSettings.isOffline || tab != ContentType.tracks || _enableOnlineTracksLetterPicker;

  /// Groups [items] into A-Z/# sections via [_groupItemsIntoSections],
  /// degrading to one header-less section if that would exceed
  /// [maxSections]. [itemCache] memoises built [CPListItem]s by item id
  /// across repeated calls for the same view, so a tap landing between
  /// background page appends still resolves against a stable element id.
  /// [leadingItem], if given, is (re-)inserted at the very top every time.
  List<CPListSection> _buildProgressiveSections(
    List<BaseItemDto> items,
    int maxSections,
    CPListItem Function(BaseItemDto item, int index) itemBuilder,
    Map<String, CPListItem> itemCache, {
    CPListItem? leadingItem,
    bool groupByLetter = true,
  }) {
    // A letter-filtered list is a single bucket already, so letter headers
    // and a one-letter scrubber would be noise.
    if (!groupByLetter) {
      final flatItems = [
        for (final (index, item) in items.indexed) itemCache.putIfAbsent(item.id.raw, () => itemBuilder(item, index)),
      ];
      final section = CPListSection(items: flatItems, sectionIndexEnabled: false);
      if (leadingItem != null) {
        section.items.insert(0, leadingItem);
      }
      return [section];
    }

    final sections = _groupItemsIntoSections(
      items,
      (item, index) => itemCache.putIfAbsent(item.id.raw, () => itemBuilder(item, index)),
    );

    final flatSections = sections.length > maxSections
        ? [CPListSection(items: sections.expand((section) => section.items).toList())]
        : sections;

    if (leadingItem != null && flatSections.isNotEmpty) {
      flatSections.first.items.insert(0, leadingItem);
    }
    return flatSections;
  }

  /// Chooses between a flat progressive list and the letter picker for a
  /// library tab view, then pushes whichever applies. A failed item-count
  /// check falls back to the flat list.
  ///
  /// [itemBuilderFor] is invoked with the exact request a list is pushed for
  /// (the tab request, or its letter-filtered variant), so tap handlers that
  /// replay the request by index always match the displayed list.
  Future<void> _showLibraryTemplate({
    required FinampPagedPlayable<FinampPlayableDto> request,
    required CPListItem Function(BaseItemDto item, int index) Function(FinampPagedPlayable<FinampPlayableDto>)
    itemBuilderFor,
    required String systemIcon,
    String? title,
    CPListItem Function()? leadingItemBuilder,
  }) async {
    final [maxItems, maxSections] = await Future.wait([_getMaxListItems(), _getMaxListSections()]);
    final musicRequest = _asMusicScreenRequest(request);
    final sortBy = _sortConfigOf(request).sortBy;

    // The picker needs one section per letter, plus one for a leading action
    // row (e.g. Shuffle All) on the views that have one.
    final requiredSections = _letterSectionCount + (leadingItemBuilder != null ? 1 : 0);

    final String? letterLayerRefusal;
    if (sortBy == SortBy.random) {
      letterLayerRefusal = "random sort has no letter order";
    } else if (!_letterLayerSupported(musicRequest.tab)) {
      letterLayerRefusal = "tab does not support letter filtering";
    } else if (maxSections < requiredSections) {
      letterLayerRefusal = "head unit allows $maxSections sections, picker needs $requiredSections";
    } else {
      letterLayerRefusal = null;
    }

    var useLetterLayer = false;
    int? total;
    if (letterLayerRefusal == null) {
      try {
        final count = await providerRef.read(musicScreenItemCountProvider(musicRequest).future);
        total = count;
        useLetterLayer = count > maxItems;
      } catch (e) {
        _carPlayLogger.warning("Failed to check CarPlay library size, falling back to a flat list: $e");
      }
    }

    _carPlayLogger.info(
      "CarPlay ${musicRequest.tab}: ${total ?? '?'} items, caps $maxItems items / $maxSections sections, "
      "letters: $useLetterLayer${letterLayerRefusal == null ? '' : ' ($letterLayerRefusal)'}",
    );

    if (useLetterLayer) {
      await _showLetterPickerTemplate(
        request: request,
        itemBuilderFor: itemBuilderFor,
        systemIcon: systemIcon,
        title: title,
        maxItems: maxItems,
        maxSections: maxSections,
        leadingItemBuilder: leadingItemBuilder,
      );
    } else {
      await _pushProgressiveListTemplate(
        request: request,
        itemBuilderFor: itemBuilderFor,
        systemIcon: systemIcon,
        title: title,
        leadingItemBuilder: leadingItemBuilder,
        maxItems: maxItems,
        maxSections: maxSections,
      );
    }
  }

  /// Pushes the [_letterSectionCount]-section letter picker. Tapping a letter
  /// pushes the matching filtered list via [_pushProgressiveListTemplate].
  /// Each section carries an explicit `sectionIndexTitle` but no visible
  /// header, so the letter isn't rendered twice, and CarPlay's side scrubber
  /// then pops the native full-screen letter grid for these sections.
  Future<void> _showLetterPickerTemplate({
    required FinampPagedPlayable<FinampPlayableDto> request,
    required CPListItem Function(BaseItemDto item, int index) Function(FinampPagedPlayable<FinampPlayableDto>)
    itemBuilderFor,
    required String systemIcon,
    required int maxItems,
    required int maxSections,
    String? title,
    CPListItem Function()? leadingItemBuilder,
  }) async {
    final letters = [for (var i = 0; i < 26; i++) String.fromCharCode(65 + i), "#"];

    final sections = letters.map((letter) {
      return CPListSection(
        sectionIndexTitle: letter,
        items: [
          CPListItem(
            text: letter,
            onPress: (complete, self) async {
              if (_isPushingPageUpdate) {
                _carPlayLogger.warning("Navigation dropped: already pushing page update");
                complete();
                return;
              }
              _isPushingPageUpdate = true;
              try {
                await _pushProgressiveListTemplate(
                  request: _withLetter(request, letter),
                  itemBuilderFor: itemBuilderFor,
                  systemIcon: systemIcon,
                  title: letter,
                  maxItems: maxItems,
                  maxSections: maxSections,
                  groupByLetter: false,
                );
              } catch (e) {
                GlobalSnackbar.error(e);
              } finally {
                _isPushingPageUpdate = false;
                complete();
              }
            },
          ),
        ],
      );
    }).toList();

    // Shuffle All applies to the whole library, so it belongs on the picker
    // rather than inside any single letter's list.
    final leadingItem = leadingItemBuilder?.call();
    final letterPickerTemplate = CPListTemplate(
      title: title,
      sections: [
        if (leadingItem != null) CPListSection(items: [leadingItem], sectionIndexEnabled: false),
        ...sections,
      ],
      systemIcon: systemIcon,
      emptyViewTitleVariants: [GlobalSnackbar.requireL10n.emptyFilteredListTitle],
    );

    await FlutterCarplay.push(template: letterPickerTemplate);
  }

  /// Pushes [request] as a list template as soon as its first page loads, then
  /// keeps appending further pages up to [maxItems] by observing the paged
  /// provider. Random sort is the exception: it forces `startIndex=0`
  /// server-side so appending would just duplicate items, so it shows one
  /// capped page instead.
  ///
  /// [itemBuilderFor], bound to this exact [request], builds a [CPListItem]
  /// for a playable item at its index within the full (appended) list,
  /// matching what [_startSliceFromPlayable] expects. [leadingItemBuilder],
  /// if given, adds one extra item (e.g. Shuffle All) at the very top of the
  /// first section.
  Future<void> _pushProgressiveListTemplate({
    required FinampPagedPlayable<FinampPlayableDto> request,
    required CPListItem Function(BaseItemDto item, int index) Function(FinampPagedPlayable<FinampPlayableDto>)
    itemBuilderFor,
    required String systemIcon,
    required int maxItems,
    required int maxSections,
    String? title,
    CPListItem Function()? leadingItemBuilder,
    bool groupByLetter = true,
  }) async {
    // Bind tap handlers to this exact request (which may be letter-filtered)
    // so replaying it by index resolves to the tapped item.
    final itemBuilder = itemBuilderFor(request);
    final itemCache = <String, CPListItem>{};
    final leadingItem = leadingItemBuilder?.call();
    var cancelled = false;

    final provider = pagedContentProvider(request);
    final isRandom = _sortConfigOf(request).sortBy == SortBy.random;
    // Random loads its whole capped page in one request
    final firstPageTarget = isRandom ? maxItems : min(_carPlayFirstPageSize, maxItems);

    if (providerRef.read(provider).error != null) {
      providerRef.read(provider.notifier).retry();
    }

    // Retain the paged data so later taps resolve, until the next root rebuild.
    _templateSubscriptions.add(providerRef.listen(provider, (_, _) {}));

    final pushed = Completer<void>();
    CPListTemplate? template;
    ProviderSubscription? driver;

    // Requests the next page while more items are wanted and available, and
    // closes the driver once the list is complete, cancelled, or errored.
    void requestNextPage() {
      if (cancelled) {
        driver?.close();
        return;
      }
      final state = providerRef.read(provider);
      // A settling load emits and drives the next request
      if (state.isLoading) return;
      if (state.error != null) {
        // The error resets when the next load starts
        _carPlayLogger.warning("Stopped filling CarPlay list '$title' early: ${state.error}");
        driver?.close();
        return;
      }
      final loaded = (state.items ?? []).length;
      if (!isRandom && loaded < maxItems && state.hasNextPage) {
        providerRef.read(provider.notifier).newPage(pageSize: min(musicScreenPageSize, maxItems - loaded));
      } else {
        driver?.close();
        _carPlayLogger.info("CarPlay list '$title' complete at $loaded items");
      }
    }

    // Repaints the on-screen template as pages arrive, driving new page requests and the first push.
    driver = providerRef.listen<PagingState<int, FinampDisplayableOrPlayable>>(provider, fireImmediately: true, (
      _,
      next,
    ) {
      if (cancelled) {
        driver?.close();
        if (!pushed.isCompleted) pushed.complete();
        return;
      }
      if (next.isLoading) return;

      final loaded = (next.items ?? []).length;
      final items = (next.items ?? []).take(maxItems).map((x) => (x as FinampPlayableDto).item).toList();

      // A first-load error with nothing cached leaves no list to show.
      if (template == null && next.error != null && items.isEmpty) {
        driver?.close();
        if (!pushed.isCompleted) pushed.completeError(next.error!);
        return;
      }

      // Keep assembling the first page before the list appears on screen.
      if (template == null && loaded < firstPageTarget && next.hasNextPage && next.error == null) {
        providerRef.read(provider.notifier).newPage(pageSize: firstPageTarget - loaded);
        return;
      }

      final sections = _buildProgressiveSections(
        items,
        maxSections,
        itemBuilder,
        itemCache,
        leadingItem: leadingItem,
        groupByLetter: groupByLetter,
      );

      if (template == null) {
        final pushTemplate = CPListTemplate(
          title: title,
          sections: sections,
          systemIcon: systemIcon,
          emptyViewTitleVariants: [GlobalSnackbar.requireL10n.emptyFilteredListTitle],
          onPop: () => cancelled = true,
        );
        template = pushTemplate;
        // Push first, then start the fill once the template is on screen so no
        // section update can race ahead of the push.
        unawaited(
          FlutterCarplay.push(template: pushTemplate).then((_) {
            _carPlayLogger.info("Pushed CarPlay list '$title' with ${items.length} items (cap $maxItems)");
            if (!pushed.isCompleted) pushed.complete();
            requestNextPage();
          }),
        );
        return;
      }

      // Repaint the pushed template with the newly arrived page, then request
      // the next one only after the update settles.
      unawaited(() async {
        try {
          await _flutterCarplay.updateListTemplateSections(elementId: template!.uniqueId, sections: sections);
        } catch (e) {
          _carPlayLogger.warning("Failed to append CarPlay list page: $e");
          driver?.close();
          return;
        }
        requestNextPage();
      }());
    });
    // listen() delivers its first value before `driver` is assigned, so close that subscription here
    if (pushed.isCompleted) {
      driver.close();
    }

    void cancel() {
      cancelled = true;
      if (!pushed.isCompleted) pushed.complete();
      driver?.close();
    }

    _pendingLoadCancellers.add(cancel);
    await pushed.future;
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
    await audioServiceHelper.shuffleAll(
      onlyShowFavorites: FinampSettingsHelper.finampSettings.onlyShowFavorites,
      itemCount: DefaultSettings.quickShuffleItemCount,
    );
    await FlutterCarplay.showSharedNowPlaying();
  }

  /// Resolves a home section preset like the main UI home screen. Presets with no offline
  /// fallback resolve to UnavailableHomeSectionPlayable and return empty, hiding the row.
  Future<List<BaseItemDto>> _loadHomeSectionItems(HomeScreenSectionPresetType preset, int limit) async {
    final section = HomeScreenSectionConfiguration.fromPreset(preset);
    final displayable = await providerRef.read(resolveSectionProvider(section).future);
    if (displayable is UnavailableHomeSectionPlayable) {
      return [];
    }
    return _loadPagedItems(displayable as FinampPagedPlayable<FinampPlayableDto>, limit);
  }

  /// Fetches Recent Queues through the same provider path as the main UI home screen.
  Future<List<FinampStorableQueueInfo>> _loadRecentQueueHistory() async {
    final section = HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType.recentQueues);
    final displayable = await providerRef.read(resolveSectionProvider(section).future);
    final children = await providerRef.read(getChildrenProvider(item: displayable as LatestQueues).future);
    return children.map((child) => (child as PlayableQueue).queue).toList();
  }

  /// Pushes the full recently-added albums list, so tapping the Recently
  /// Added art row itself leads to more than the handful shown as art.
  Future<void> _showRecentlyAddedTemplate() async {
    if (_isPushingPageUpdate) {
      _carPlayLogger.warning("Navigation dropped: already pushing page update");
      return;
    }
    _isPushingPageUpdate = true;
    try {
      final albums = await _loadHomeSectionItems(HomeScreenSectionPresetType.recentlyAddedAlbums, 24);
      final section = CPListSection(
        items: albums.map((album) {
          return CPListItem(
            text: album.name ?? GlobalSnackbar.requireL10n.unknownName,
            detailText: album.albumArtist,
            image: _getCarPlayImageUri(album),
            onPress: (complete, self) async {
              await showCollectionTracksTemplate(album);
              complete();
            },
          );
        }).toList(),
      );

      await FlutterCarplay.push(
        template: CPListTemplate(
          sections: [section],
          title: GlobalSnackbar.requireL10n.recentlyAdded,
          systemIcon: 'clock.arrow.circlepath',
        ),
      );
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  /// Resolves the art-row image for a saved queue: a 2x2 collage of covers
  /// from the next [_collageTileCount] distinct albums coming up in the
  /// queue, falling back to the current track's own artwork, then to a
  /// placeholder icon, so a missing track or missing artwork doesn't shift
  /// indices out of alignment with the queue list.
  Future<String> _getRecentQueueImage(FinampStorableQueueInfo info) async {
    try {
      final collage = await _buildRecentQueueCollage(info);
      if (collage != null) {
        return collage;
      }
    } catch (e) {
      _carPlayLogger.warning("Failed to build collage for recent queue: $e");
    }
    return _getRecentQueueCoverImage(info);
  }

  /// Resolves the current track's own artwork for a saved queue, falling
  /// back to a placeholder icon. Used when a collage can't be built.
  Future<String> _getRecentQueueCoverImage(FinampStorableQueueInfo info) async {
    final currentTrackId = info.currentTrack;
    if (currentTrackId == null) {
      return _getPlaceholderImageUri();
    }
    try {
      final track = await providerRef.read(itemByIdProvider(currentTrackId).future);
      if (track == null) {
        return _getPlaceholderImageUri();
      }
      return _getCarPlayImageUri(track) ?? await _getPlaceholderImageUri();
    } catch (e) {
      _carPlayLogger.warning("Failed to resolve artwork for recent queue: $e");
      return _getPlaceholderImageUri();
    }
  }

  /// Finds up to [_collageTileCount] distinct albums among the tracks
  /// coming up in [info] (current track, then queue), resolving each
  /// candidate's cover as it's found so a single failed cover doesn't sink
  /// the whole collage, then composes the resolved covers into a PNG cached
  /// under the temp directory and returns a `file://` URI. Returns null if
  /// no cover resolves at all.
  Future<String?> _buildRecentQueueCollage(FinampStorableQueueInfo info) async {
    // Prefer albums still coming up, then pad with the most recently played
    // ones so a queue archived near its end can still fill the collage.
    final upcomingIds = <BaseItemId>[
      if (info.currentTrack != null) info.currentTrack!,
      ...info.nextUp,
      ...info.queue,
      ...info.previousTracks.reversed,
    ];

    final albumImages = <ui.Image>[];
    final usedAlbumIds = <String>[];
    final seenAlbumIds = <String>{};
    var scanned = 0;
    for (final id in upcomingIds) {
      if (albumImages.length >= _collageTileCount || scanned >= _maxCollageTrackScan) {
        break;
      }
      scanned++;
      final track = await providerRef.read(itemByIdProvider(id).future);
      final albumId = track?.albumId?.raw;
      if (albumId == null || !seenAlbumIds.add(albumId)) {
        continue;
      }
      final image = await _resolveCollageTileImage(track!);
      if (image == null) {
        // Cover failed to resolve or decode. Keep scanning for a
        // replacement instead of failing the whole collage.
        continue;
      }
      albumImages.add(image);
      usedAlbumIds.add(albumId);
    }

    if (albumImages.isEmpty) {
      return null;
    }

    // Anything short of a full 2x2 grid falls back to the best single
    // cover scaled across the whole canvas, so every tile in the Recent
    // Queues row stays the same size.
    final tiles = albumImages.length == _collageTileCount ? albumImages : [albumImages.first];
    final tileIdsKey = albumImages.length == _collageTileCount ? usedAlbumIds : [usedAlbumIds.first];

    final cacheFile = File(
      path_helper.join(
        (await getTemporaryDirectory()).path,
        'carplay_queue_collage_${info.creation}_${tileIdsKey.join(',').hashCode}.png',
      ),
    );
    if (await cacheFile.exists()) {
      return Uri.file(cacheFile.path).toString();
    }

    final bytes = await _composeCollage(tiles);
    if (bytes == null) {
      return null;
    }
    await cacheFile.writeAsBytes(bytes, flush: true);
    return Uri.file(cacheFile.path).toString();
  }

  /// Resolves a track's album cover as a decoded [ui.Image] via
  /// [albumImageProvider], reusing Finamp's image cache and auth. Returns
  /// null if the artwork can't be resolved or decoded.
  Future<ui.Image?> _resolveCollageTileImage(BaseItemDto track) async {
    final imageProvider = providerRef
        .read(
          albumImageProvider(AlbumImageRequest(item: track, maxWidth: _collageTileSize, maxHeight: _collageTileSize)),
        )
        .image;
    if (imageProvider == null) {
      return null;
    }

    final completer = Completer<ui.Image?>();
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        stream.removeListener(listener);
        completer.complete(image.image);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Composes [images] into a square collage PNG the same size regardless
  /// of tile count, returning the encoded bytes, or null if encoding fails.
  /// A single image fills the whole canvas. [_collageTileCount] images are
  /// drawn as 2x2 quadrants.
  Future<Uint8List?> _composeCollage(List<ui.Image> images) async {
    final tileSize = _collageTileSize.toDouble();
    final collageSize = tileSize * 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, collageSize, collageSize));
    if (images.length == 1) {
      final image = images.first;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, collageSize, collageSize),
        ui.Paint(),
      );
    } else {
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final dx = (i % 2) * tileSize;
        final dy = (i ~/ 2) * tileSize;
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          ui.Rect.fromLTWH(dx, dy, tileSize, tileSize),
          ui.Paint(),
        );
      }
    }
    final picture = recorder.endRecording();
    final collageImage = await picture.toImage(collageSize.round(), collageSize.round());
    final byteData = await collageImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  String? _placeholderImage;

  /// Renders the main UI's artwork placeholder, the album glyph on a card
  /// coloured tile, to a cached PNG and returns its file URI.
  Future<String> _getPlaceholderImageUri() async {
    if (_placeholderImage != null) {
      return _placeholderImage!;
    }
    try {
      const size = 100.0;
      final cacheFile = File(
        path_helper.join((await getTemporaryDirectory()).path, 'carplay_placeholder_${size.round()}.png'),
      );
      if (!await cacheFile.exists()) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size, size));
        canvas.drawRect(ui.Rect.fromLTWH(0, 0, size, size), ui.Paint()..color = const ui.Color(0xFF424242));
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(Icons.album.codePoint),
            style: TextStyle(
              fontFamily: Icons.album.fontFamily,
              fontSize: size * 0.4,
              color: const ui.Color(0xB3FFFFFF),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        painter.paint(canvas, ui.Offset((size - painter.width) / 2, (size - painter.height) / 2));
        final image = await recorder.endRecording().toImage(size.round(), size.round());
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          return _carPlayFallbackImage;
        }
        await cacheFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      }
      _placeholderImage = Uri.file(cacheFile.path).toString();
    } catch (e) {
      _carPlayLogger.warning("Failed to render artwork placeholder: $e");
      _placeholderImage = _carPlayFallbackImage;
    }
    return _placeholderImage!;
  }

  /// Renders an icon font glyph to a PNG in the temp directory and returns
  /// its file URI, so CarPlay buttons can show the same icons as the phone
  /// UI. Only the glyph's alpha matters, CarPlay tints button images itself.
  Future<String?> _getIconFontImageUri(IconData icon, double size) async {
    final cacheFile = File(
      path_helper.join((await getTemporaryDirectory()).path, 'carplay_icon_${icon.codePoint}_${size.round()}.png'),
    );
    if (!await cacheFile.exists()) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size, size));
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: size,
            color: const ui.Color(0xFFFFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(canvas, ui.Offset((size - painter.width) / 2, (size - painter.height) / 2));
      final image = await recorder.endRecording().toImage(size.round(), size.round());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }
      await cacheFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    }
    return Uri.file(cacheFile.path).toString();
  }

  /// Archives the live queue, restores [info] at its saved track and seek
  /// position, then shows CarPlay's Now Playing screen. Shared by the
  /// Recent Queues art row's per-image tap and its pushed full-history list.
  Future<void> _resumeSavedQueue(FinampStorableQueueInfo info) async {
    // The cold-launch startup restore commonly hasn't settled yet, which
    // would otherwise error as "already loading". Its own failure is
    // unrelated to this queue, so ignore it.
    try {
      await _queueService.performInitialQueueLoad();
    } catch (_) {}
    _queueService.archiveSavedQueue();
    await _queueService.loadSavedQueue(info);
    await FlutterCarplay.showSharedNowPlaying();
  }

  /// Pushes the full saved-queue history as a scrollable list, so tapping
  /// the Recent Queues art row itself (CarPlay always renders a '>' chevron
  /// on an image row) leads to more than the handful shown as art.
  Future<void> _showRecentQueuesTemplate(List<FinampStorableQueueInfo> queueHistory) async {
    if (_isPushingPageUpdate) {
      _carPlayLogger.warning("Navigation dropped: already pushing page update");
      return;
    }
    _isPushingPageUpdate = true;
    try {
      final l10n = GlobalSnackbar.requireL10n;
      final placeholderImage = await _getPlaceholderImageUri();
      final items = List.generate(queueHistory.length, (index) {
        final info = queueHistory[index];
        final remaining = info.trackCount - info.previousTracks.length;
        return CPListItem(
          text: info.source.name.getLocalized(l10n),
          detailText: l10n.queueRestoreSubtitle2(info.trackCount, remaining),
          image: placeholderImage,
          onPress: (complete, self) async {
            try {
              await _resumeSavedQueue(info);
            } catch (e) {
              GlobalSnackbar.error(e);
            } finally {
              complete();
            }
          },
        );
      });

      await FlutterCarplay.push(
        template: CPListTemplate(
          sections: [CPListSection(items: items)],
          title: l10n.recentQueues,
          systemIcon: 'clock.arrow.circlepath',
        ),
      );
      unawaited(_fillRecentQueueImages(queueHistory, items));
    } finally {
      _isPushingPageUpdate = false;
    }
  }

  /// Streams the pushed Recent Queues list's collage covers in one queue at
  /// a time via [CPListItem.setImage], so the list opens instantly and
  /// building covers never blocks CarPlay navigation. A newer run abandons
  /// any older one still going.
  Future<void> _fillRecentQueueImages(List<FinampStorableQueueInfo> queueHistory, List<CPListItem> items) async {
    final run = ++_recentQueueImageFillRun;
    try {
      final placeholderImage = await _getPlaceholderImageUri();
      for (var i = 0; i < items.length; i++) {
        final image = await _getRecentQueueImage(queueHistory[i]);
        if (run != _recentQueueImageFillRun) {
          return;
        }
        if (image != placeholderImage) {
          items[i].setImage(image);
        }
      }
    } catch (e) {
      _carPlayLogger.warning("Failed to fill recent queue covers: $e");
    }
  }

  /// Clamps [desired] to the CarPlay image row's runtime grid-image limit
  /// when the plugin reports one smaller than [desired].
  Future<int> _clampToGridImageLimit(int desired) async {
    final maxGridImages = await CPListImageRowItem.getMaximumNumberOfGridImages();
    if (maxGridImages != null && maxGridImages < desired) {
      return maxGridImages;
    }
    return desired;
  }

  Future<List<CPListSection>> _buildHomeSections() async {
    List<CPListSection> sections = [];

    CPListSection quickActionsSection = CPListSection(
      sectionIndexEnabled: false,
      items: [
        CPListItem(
          text: GlobalSnackbar.requireL10n.shuffleTracksAction,
          onPress: (complete, self) async {
            await shuffleAllTracks();
            complete();
          },
        ),
        CPListItem(
          text: GlobalSnackbar.requireL10n.surpriseMeAction,
          onPress: (complete, self) async {
            if (FinampSettingsHelper.finampSettings.isOffline) {
              // Offline: instant mix not available, fallback to shuffle.
              await shuffleAllTracks();
            } else {
              await GetIt.instance<AudioServiceHelper>().startSurpriseMeMix();
              await FlutterCarplay.showSharedNowPlaying();
            }
            complete();
          },
        ),
      ],
    );
    sections.add(quickActionsSection);

    final [recentPlays, recentlyAddedFetched] = await Future.wait([
      _loadHomeSectionItems(HomeScreenSectionPresetType.recentlyPlayedTracks, _carPlayRecentlyPlayedLimit),
      _loadHomeSectionItems(HomeScreenSectionPresetType.recentlyAddedAlbums, _carPlayRecentlyAddedLimit),
    ]);

    _carPlayLogger.info("Got ${recentlyAddedFetched.length} recently added albums");
    if (recentlyAddedFetched.isNotEmpty) {
      final recentlyAddedLimit = await _clampToGridImageLimit(recentlyAddedFetched.length);
      final recentlyAdded = recentlyAddedFetched.take(recentlyAddedLimit).toList();
      final placeholderImage = await _getPlaceholderImageUri();

      sections.add(
        CPListSection(
          items: [
            CPListImageRowItem(
              text: GlobalSnackbar.requireL10n.recentlyAdded,
              gridImages: recentlyAdded.map((album) => _getCarPlayImageUri(album) ?? placeholderImage).toList(),
              onPress: (complete, self) async {
                try {
                  await _showRecentlyAddedTemplate();
                } catch (e) {
                  GlobalSnackbar.error(e);
                } finally {
                  complete();
                }
              },
              onItemPress: (complete, self, index) async {
                try {
                  if (index != null && index >= 0 && index < recentlyAdded.length) {
                    await showCollectionTracksTemplate(recentlyAdded[index]);
                  }
                } catch (e) {
                  GlobalSnackbar.error(e);
                } finally {
                  complete();
                }
              },
            ),
          ],
        ),
      );
    }

    if (recentPlays.isNotEmpty) {
      CPListSection recentPlaysSection = CPListSection(
        header: GlobalSnackbar.requireL10n.recentlyPlayed,
        sectionIndexEnabled: false,
        items: [],
      );

      for (final baseItem in recentPlays) {
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

    final recentQueueHistory = await _loadRecentQueueHistory();
    if (recentQueueHistory.isNotEmpty) {
      final queueLimit = await _clampToGridImageLimit(_maxRecentQueues);
      final recentQueues = recentQueueHistory.take(queueLimit).toList();

      final queueImages = await Future.wait(recentQueues.map(_getRecentQueueImage));

      sections.add(
        CPListSection(
          items: [
            CPListImageRowItem(
              text: GlobalSnackbar.requireL10n.recentQueues,
              gridImages: queueImages,
              onPress: (complete, self) async {
                try {
                  await _showRecentQueuesTemplate(recentQueueHistory);
                } catch (e) {
                  GlobalSnackbar.error(e);
                } finally {
                  complete();
                }
              },
              onItemPress: (complete, self, index) async {
                try {
                  if (index != null && index >= 0 && index < recentQueues.length) {
                    await _resumeSavedQueue(recentQueues[index]);
                  }
                } catch (e) {
                  GlobalSnackbar.error(e);
                } finally {
                  complete();
                }
              },
            ),
          ],
        ),
      );
    }

    return sections;
  }

  Future<void> setCarplayRootTemplate() async {
    // Replacing the root template resets CarPlay navigation, so drop a
    // rebuild that overlaps one already running.
    if (_isSettingRootTemplate) {
      _carPlayLogger.info("Root template rebuild dropped: already in progress");
      return;
    }
    _isSettingRootTemplate = true;
    try {
      // A root rebuild discards the navigation stack, so release its paged
      // requests and clear any push guard left set by an abandoned load.
      _closeTemplateSubscriptions();
      _isPushingPageUpdate = false;
      await _setCarplayRootTemplate();
    } finally {
      _isSettingRootTemplate = false;
    }
  }

  Future<void> _setCarplayRootTemplate() async {
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
              case ContentType.inPlaylistOrAlbum:
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

    final homeTemplate = CPListTemplate(
      sections: homeSections,
      title: GlobalSnackbar.requireL10n.home,
      emptyViewTitleVariants: [GlobalSnackbar.requireL10n.home],
      emptyViewSubtitleVariants: [GlobalSnackbar.requireL10n.notAvailable],
      systemIcon: 'music.note.house',
    );
    _homeTemplate = homeTemplate;

    await FlutterCarplay.setRootTemplate(
      rootTemplate: CPTabBarTemplate(
        templates: [
          homeTemplate,
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

  /// Rebuilds the home tab's sections in place. Setting a new root template
  /// tears down CarPlay's navigation stack and dismisses the Now Playing
  /// screen, so avoid it once the root exists.
  Future<void> _refreshHomeSections() async {
    final homeTemplate = _homeTemplate;
    if (homeTemplate == null) {
      await setCarplayRootTemplate();
      return;
    }
    try {
      final sections = await _buildHomeSections();
      await _flutterCarplay.updateListTemplateSections(elementId: homeTemplate.uniqueId, sections: sections);
    } catch (e) {
      _carPlayLogger.warning("Failed to refresh CarPlay home sections: $e");
    }
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
      final FinampPagedPlayable<FinampPlayableDto> request;
      if (genreFilter != null) {
        request = Genre(
          genreFilter,
          source: QueueItemSource.fromBaseItem(genreFilter),
          sortConfig: SortAndFilterConfiguration.defaultSort,
          type: GenreChildType.albums,
          library: currentLibraryPlaceholder,
        );
      } else {
        request = _tabPlayable(tabType);
      }

      await _showLibraryTemplate(
        request: request,
        systemIcon: 'square.stack',
        title: genreFilter?.name ?? tabType.toLocalisedString(GlobalSnackbar.requireL10n),
        itemBuilderFor: (_) =>
            (item, index) => CPListItem(
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
            ),
      );
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
      await _showLibraryTemplate(
        request: _tabPlayable(ContentType.tracks),
        systemIcon: 'music.note',
        title: ContentType.tracks.toLocalisedString(GlobalSnackbar.requireL10n),
        leadingItemBuilder: () => CPListItem(
          text: GlobalSnackbar.requireL10n.shuffleAll,
          onPress: (complete, self) async {
            await shuffleAllTracks();
            complete();
          },
        ),
        // Taps replay the pushed list's request (possibly letter-filtered) so
        // the index resolves against the displayed pages.
        itemBuilderFor: (request) =>
            (item, index) => CPListItem(
              text: item.name ?? GlobalSnackbar.requireL10n.unknownName,
              detailText: item.artists?.join(", ") ?? item.albumArtist,
              image: _getCarPlayImageUri(item),
              onPress: (complete, self) async {
                await _startSliceFromPlayable(request, index: index);
                complete();
              },
            ),
      );
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
      await _showLibraryTemplate(
        request: _tabPlayable(ContentType.albumArtists),
        systemIcon: 'person.2',
        title: ContentType.albumArtists.toLocalisedString(GlobalSnackbar.requireL10n),
        itemBuilderFor: (_) =>
            (item, index) => CPListItem(
              text: item.name ?? GlobalSnackbar.requireL10n.unknownName,
              onPress: (complete, self) async {
                await showArtistTemplate(item);
                complete();
              },
            ),
      );
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
