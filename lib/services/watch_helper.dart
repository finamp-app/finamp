import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audio_session/audio_session.dart';
import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/models/music_slices.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' show ClientException;
import 'package:logging/logging.dart';

import 'android_auto_helper.dart';
import 'current_track_metadata_provider.dart';
import 'downloads_service.dart';
import 'favorite_provider.dart';
import 'item_by_id_provider.dart';
import 'music_player_background_task.dart';
import 'music_screen_provider.dart';
import 'output_route_provider.dart';
import 'queue_service.dart';
import 'quick_actions_service.dart';
import 'widget_bindings_observer_provider.dart';

final _logger = Logger('WatchHandler');

/// Default artwork side length in pixels when the request omits a size.
const _defaultWatchArtworkSize = 160;

/// Page size for library roots.
const _defaultPageSize = 50;

const _homeSectionSize = 8;
const _recentlyPlayedLimit = 6;
const _searchSectionSize = 5;
const _favoritesLimit = 200;
const _queueLimit = 30;

/// Caps an artist's album list to fit WatchConnectivity; album and playlist tracks are paged instead.
const _collectionLimit = 250;

/// Favourite albums/artists fetched at once when playing them all.
const _parallelFetches = 8;

/// Scan limit for offline search and favourites, which cannot use server-side filters.
const _offlineLimit = 1000;

/// Handles Apple Watch requests through the iOS bridge and Finamp's providers.
class WatchHandler {
  static const _watchChannel = MethodChannel('com.unicornsonlsd.finamp-ios/watch');

  /// Finamp's own test for "the server can't be reached" (as in GlobalSnackbar).
  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is ClientException ||
      error is TimeoutException ||
      (error is Response && (error.error is SocketException || error.error is ClientException));

  /// Jellyfin item ids are 32 hex digits; anything else from the watch is refused before it reaches a request.
  static final _jellyfinId = RegExp(r'^[0-9a-fA-F]{32}$');

  /// The full child list of the collection the watch is paging through, by parent id.
  static (String, List<BaseItemDto>)? _childrenCache;

  /// Retains sent items so later artwork requests can resolve them by id.
  static final Map<BaseItemId, BaseItemDto> _sentItems = {};

  /// Call once during app initialization.
  static void setup() {
    if (!Platform.isIOS) return;

    _watchChannel.setMethodCallHandler((call) async {
      final arguments = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      _logger.fine("Watch request: ${call.method} $arguments");
      try {
        switch (call.method) {
          case 'list':
            return await _list(arguments);
          case 'home':
            return await _home();
          case 'search':
            return await _search(arguments['query'] as String);
          case 'shuffleAll':
            await GetIt.instance<AndroidAutoHelper>().shuffleAllTracks();
            return true;
          case 'nowPlaying':
            return _nowPlaying();
          case 'queue':
            return _upcoming();
          case 'quickAction':
            await _runQuickAction(arguments['index'] as int, arguments['action'] as String?);
            return true;
          case 'output':
            return await _output();
          case 'setVolume':
            GetIt.instance<MusicPlayerBackgroundTask>().setVolume((arguments['volume'] as double).clamp(0.0, 1.0));
            return true;
          case 'watchState':
            if (arguments['available'] == true) _startPushing();
            return true;
          // Finamp settings the watch shows: "Enable Transcoding" and "Offline Mode"
          case 'settings':
            final settings = FinampSettingsHelper.finampSettings;
            return {'transcoding': settings.shouldTranscode, 'offline': settings.isOffline};
          case 'setSetting':
            final enabled = arguments['enabled'] as bool;
            switch (arguments['name']) {
              case 'transcoding':
                FinampSetters.setShouldTranscode(enabled);
              case 'offline':
                FinampSetters.setIsOffline(enabled);
              default:
                throw PlatformException(code: "unknown", message: "Unknown setting");
            }
            return true;
          case 'favorite':
            return await _setFavorite(arguments['id'] as String, arguments['favorite'] as bool);
          case 'download':
            return await _download(arguments);
          case 'artistInfo':
            return await _artistInfo(arguments['id'] as String);
          case 'downloadState':
            return _downloadState(await _itemById(arguments['id'] as String));
          case 'control':
            if (arguments['action'] == 'skipTo') {
              await _skipTo(arguments['id'] as String);
            } else {
              await _control(arguments['action'] as String);
            }
            return true;
          case 'play':
            await _play(arguments);
            return true;
          case 'artworks':
            return await _artworks(arguments);
          default:
            throw MissingPluginException("Unknown watch method: ${call.method}");
        }
      } catch (error) {
        // One plain message for the watch, never the raw exception (which names the server and the user)
        if (_isNetworkError(error)) {
          throw PlatformException(code: "server", message: "Can't reach your Jellyfin server");
        }
        rethrow;
      }
    });

    // Avoid player subscriptions on phones without the watch app.
    unawaited(
      _watchChannel
          .invokeMethod<bool>('watchState')
          .then((available) {
            if (available ?? false) _startPushing();
          })
          .catchError((Object error) => _logger.fine("Couldn't ask for the watch state: $error")),
    );

    _logger.info("Watch handler set up");
  }

  static bool _pushing = false;

  /// Pushes state changes and sends the initial theme, account, transcoding and offline settings.
  static void _startPushing() {
    if (_pushing) return;
    _pushing = true;
    final container = GetIt.instance<ProviderContainer>();
    GetIt.instance<QueueService>().getCurrentTrackStream().listen((_) => _scheduleNowPlayingPush());
    GetIt.instance<MusicPlayerBackgroundTask>().playbackState.listen((_) => _scheduleNowPlayingPush());
    // Metadata arrives after the track; this also keeps the provider alive.
    container.listen(currentTrackMetadataProvider, (_, _) => _scheduleNowPlayingPush());
    container.listen(brightnessProvider, (_, _) => _pushIfChanged('theme', _theme()));
    _pushIfChanged('theme', _theme());
    // The user provider also fires on address changes; only an account change clears the cache.
    container.listen(FinampUserHelper.finampCurrentUserProvider, (_, _) {
      final account = _account();
      if (account != _lastPushedValues['account']) {
        _sentItems.clear();
        _playlistFirstTracks.clear();
        _childrenCache = null;
      }
      _pushIfChanged('account', account);
    });
    _pushIfChanged('account', _account());
    container.listen(finampSettingsProvider.shouldTranscode, (_, enabled) => _pushIfChanged('transcoding', enabled));
    _pushIfChanged('transcoding', FinampSettingsHelper.finampSettings.shouldTranscode);
    container.listen(finampSettingsProvider.isOffline, (_, offline) => _pushIfChanged('offline', offline));
    // Finamp's volume (its output menu's slider), so an open Output sheet on the watch follows it
    container.listen(finampSettingsProvider.currentVolume, (_, volume) => _pushIfChanged('volume', volume));
    _pushIfChanged('volume', FinampSettingsHelper.finampSettings.currentVolume);
    // While AirPlay plays, Finamp's volume has no effect and its slider is disabled; the watch does the same
    container.listen(
      airPlayActiveProvider,
      (_, airPlay) => _pushIfChanged('airPlay', airPlay.valueOrNull ?? false),
      fireImmediately: true,
    );
    _pushIfChanged('offline', FinampSettingsHelper.finampSettings.isOffline);
  }

  static Timer? _nowPlayingPushTimer;
  static Map<String, Object>? _lastPushed;
  static ProviderSubscription<bool>? _favoriteSubscription;
  static BaseItemId? _favoriteSubscriptionItem;

  /// Coalesces bursts of player events into one push.
  static void _scheduleNowPlayingPush() {
    _nowPlayingPushTimer?.cancel();
    _nowPlayingPushTimer = Timer(const Duration(milliseconds: 150), _pushNowPlaying);
  }

  /// Skips normal progress updates because the watch advances the position locally.
  static void _pushNowPlaying() {
    final state = _nowPlaying();
    final last = _lastPushed;
    if (last != null) {
      final unchanged = state.keys.every(
        // Artist lists are rebuilt each time, so compare their contents.
        (key) =>
            key == 'position' ||
            key == 'updatedAt' ||
            state[key] == last[key] ||
            const DeepCollectionEquality().equals(state[key], last[key]),
      );
      final expected =
          (last['position'] as double) +
          ((last['playing'] as bool) ? (state['updatedAt'] as double) - (last['updatedAt'] as double) : 0);
      if (unchanged && ((state['position'] as double) - expected).abs() < 2) return;
    }
    _lastPushed = state;
    unawaited(
      _watchChannel.invokeMethod('nowPlaying', state).catchError((Object error) {
        _logger.fine("Couldn't push now playing to the watch: $error");
      }),
    );
  }

  /// `position` is seconds at `updatedAt` (Unix seconds); the watch extrapolates while playing.
  static Map<String, Object> _nowPlaying() {
    final current = GetIt.instance<QueueService>().getCurrentTrack();
    final playbackState = GetIt.instance<MusicPlayerBackgroundTask>().playbackState.value;
    final now = DateTime.now();
    final item = current?.baseItem;
    if (current == null || item == null) {
      return {
        'hasTrack': false,
        'playing': false,
        'position': 0.0,
        'updatedAt': now.millisecondsSinceEpoch / 1000,
        'theme': _theme(),
      };
    }

    _sentItems[item.id] = item;
    _watchFavorite(item);
    final elapsed = playbackState.playing
        ? now.difference(playbackState.updateTime).inMilliseconds / 1000 * playbackState.speed
        : 0.0;
    final position = playbackState.updatePosition.inMilliseconds / 1000 + elapsed;
    return {
      'hasTrack': true,
      'id': item.id.raw,
      'title': current.item.title,
      'artist': current.item.artist ?? item.artists?.join(", ") ?? "",
      'artworkKey': _artworkKey(item),
      'artworkUrl': _artworkUrl(item),
      'albumId': item.albumId?.raw ?? "",
      'album': item.album ?? "",
      'albumArtist': item.albumArtists?.firstOrNull?.name ?? item.albumArtist ?? "",
      'albumArtistId': item.albumArtists?.firstOrNull?.id.raw ?? "",
      'artists': _artists(item.artistItems),
      'audio': _audioInfo(current),
      'duration': (current.item.duration ?? item.runTimeTicksDuration() ?? Duration.zero).inMilliseconds / 1000,
      'position': position,
      'updatedAt': now.millisecondsSinceEpoch / 1000,
      'playing': playbackState.playing,
      'favorite': GetIt.instance<ProviderContainer>().read(isFavoriteProvider(item)),
      'theme': _theme(),
    };
  }

  /// Jumps to an upcoming queue item by id, wherever it is now: the queue may have moved since the watch listed it.
  static Future<void> _skipTo(String id) async {
    final queueService = GetIt.instance<QueueService>();
    final queue = queueService.getQueue();
    final index = [...queue.nextUp, ...queue.queue].indexWhere((track) => track.id == id);
    if (index < 0) throw PlatformException(code: "gone", message: "That track has already played");
    await queueService.skipByOffset(index + 1);
  }

  /// Upcoming rows, next-up first; `skipTo` takes a row's `id`.
  static List<Map<String, Object>> _upcoming() {
    final queue = GetIt.instance<QueueService>().getQueue();
    return [...queue.nextUp, ...queue.queue]
        .take(_queueLimit)
        .map(
          (track) => {
            'id': track.id,
            'name': track.item.title,
            'subtitle': track.item.artist ?? "",
            'artworkKey': "",
            'duration': (track.item.duration ?? Duration.zero).inMilliseconds / 1000,
          },
        )
        .toList();
  }

  /// Keeps the current track's favourite provider alive and pushes changes.
  static void _watchFavorite(BaseItemDto item) {
    if (_favoriteSubscriptionItem == item.id) return;
    _favoriteSubscription?.close();
    _favoriteSubscriptionItem = item.id;
    _favoriteSubscription = GetIt.instance<ProviderContainer>().listen(
      isFavoriteProvider(item),
      (_, _) => _scheduleNowPlayingPush(),
    );
  }

  static Future<void> _control(String action) async {
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    switch (action) {
      case 'playPause':
        if (audioHandler.playbackState.value.playing) {
          await audioHandler.pause();
        } else {
          await audioHandler.play();
        }
      case 'next':
        await audioHandler.skipToNext();
      case 'previous':
        await audioHandler.skipToPrevious();
    }
  }

  /// `artists` follows the artist type setting; other values are [ContentType] names.
  static ContentType _contentType(String type) {
    if (type == 'artists') {
      return FinampSettingsHelper.finampSettings.defaultArtistType == ArtistType.albumArtist
          ? ContentType.albumArtists
          : ContentType.performingArtists;
    }
    return ContentType.values.byName(type);
  }

  /// Returns a paged library root or a collection's children, capped at [_collectionLimit].
  static Future<List<Map<String, Object>>> _list(Map<String, dynamic> arguments) async {
    final type = arguments['type'] as String;
    final offset = arguments['offset'] as int? ?? 0;
    final limit = arguments['limit'] as int? ?? _defaultPageSize;
    final parentId = arguments['parentId'] as String?;
    final List<BaseItemDto> items;
    if (type == 'favorites') {
      items = await _favorites(ContentType.tracks);
    } else if (type == 'downloads') {
      items = (await _downloads()).skip(offset).take(limit).toList();
    } else if (type == 'favoriteAlbums') {
      items = await _favorites(ContentType.albums);
    } else if (type == 'favoriteArtists') {
      items = await _favorites(_contentType('artists'));
    } else if (parentId == null) {
      items = await _tabPage(_contentType(type), offset, limit);
    } else {
      // Albums and playlists come a page at a time, from the full list kept since the first page; an artist's albums
      // come at once
      final parent = await _itemById(parentId);
      if (BaseItemDtoType.fromItem(parent) == BaseItemDtoType.artist) {
        items = (await _children(parent)).take(_collectionLimit).toList();
      } else {
        if (offset == 0 || _childrenCache?.$1 != parentId) _childrenCache = (parentId, await _children(parent));
        items = _childrenCache!.$2.skip(offset).take(limit).toList();
      }
    }
    return _rows(items);
  }

  /// Reuse controllers because each new instance leaves cached sort state behind.
  static final _tabSortControllers = <ContentType, SortAndFilterController>{};

  static final _artistAlbumsSortController = SortAndFilterController(
    contentType: ContentType.tracks,
    startingConfig: const SortAndFilterConfiguration(
      sortBy: SortBy.premiereDate,
      sortOrder: SortOrder.ascending,
      filters: {},
    ),
  );

  /// Loads a tab page with Finamp's sort, library and offline settings.
  static Future<List<BaseItemDto>> _tabPage(ContentType tab, int offset, int limit) async {
    final request = MusicScreenPlayable(
      tab: tab,
      library: currentLibraryPlaceholder,
      source: QueueItemSource.rawId(
        type: QueueItemSourceType.allTracks,
        name: const QueueItemSourceName(type: QueueItemSourceNameType.musicScreenTracks),
        id: "allTracks",
      ),
      sortConfig: _tabSortControllers
          .putIfAbsent(tab, () => SortAndFilterController.trackSettings(tab))
          .resolveConfig(),
    );
    return await _readOnce<List<BaseItemDto>?>(
          loadHomeSectionItemsProvider(request: request, startIndex: offset, limit: limit).future,
        ) ??
        [];
  }

  /// Loads collection children through the same providers as Finamp's screens.
  static Future<List<BaseItemDto>> _children(BaseItemDto parent) async {
    final FinampDisplayableOrPlayable playable = BaseItemDtoType.fromItem(parent) == BaseItemDtoType.artist
        ? Artist(
            parent,
            source: QueueItemSource.fromBaseItem(parent),
            sortConfig: _artistAlbumsSortController.resolveConfig(),
            type: FinampSettingsHelper.finampSettings.defaultArtistType == ArtistType.albumArtist
                ? ArtistChildType.albumsFromArtist
                : ArtistChildType.appearsOnAlbums,
            library: currentLibraryPlaceholder,
          )
        : FinampPlayableDto.fromItem(parent);
    if (playable is! FinampUnpagedDisplayable) {
      throw PlatformException(code: "unsupported", message: "Not a collection");
    }
    final children = await _readOnce(getChildrenProvider(item: playable).future);
    return children.whereType<FinampPlayableDto>().map((child) => child.item).toList();
  }

  /// Returns Home sections together to save WatchConnectivity round trips.
  static Future<Map<String, Object>> _home() async {
    final sections = await Future.wait([
      _recentlyPlayed(),
      _query(ContentType.albums, limit: _homeSectionSize, sortBy: "DateCreated", sortOrder: "Descending").then(_rows),
    ]);
    return {'recent': sections[0], 'newAlbums': sections[1], 'actions': _quickActions(), 'theme': _theme()};
  }

  static final Map<String, Object> _lastPushedValues = {};

  static void _pushIfChanged(String key, Object value) {
    if (_lastPushedValues[key] == value) return;
    _lastPushedValues[key] = value;
    unawaited(
      _watchChannel.invokeMethod(key, value).catchError((Object error) {
        _logger.fine("Couldn't push the $key to the watch: $error");
      }),
    );
  }

  /// `user-id@server-id`, or "" when logged out; server ids survive local/public address changes.
  static String _account() {
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    return user == null ? "" : "${user.id}@${user.serverId}";
  }

  /// Returns "light" or "dark", resolving the system theme on the phone.
  static String _theme() {
    final brightness = switch (FinampSettingsHelper.finampSettings.themeMode) {
      ThemeMode.light => ui.Brightness.light,
      ThemeMode.dark => ui.Brightness.dark,
      ThemeMode.system => ui.PlatformDispatcher.instance.platformBrightness,
    };
    return brightness == ui.Brightness.light ? 'light' : 'dark';
  }

  /// Home quick actions that do not open a phone screen.
  static const _watchQuickActions = {
    FinampQuickActions.shuffleTracks,
    FinampQuickActions.playRandomItem,
    FinampQuickActions.playRandomFavoriteItem,
    FinampQuickActions.playPreviousQueue,
    FinampQuickActions.surpriseMe,
  };

  /// Returns runnable actions with their configuration index, name and localised title.
  static List<Map<String, Object>> _quickActions() {
    final actions = FinampSettingsHelper.finampSettings.homeScreenConfiguration.actions;
    return [
      for (final (index, action) in actions.indexed)
        if (_watchQuickActions.contains(action.action))
          {'index': index, 'title': action.getTitle(GlobalSnackbar.requireL10n), 'action': action.action.name},
    ];
  }

  /// Runs an allowed quick action through Finamp's handler.
  static Future<void> _runQuickAction(int index, String? name) async {
    final actions = FinampSettingsHelper.finampSettings.homeScreenConfiguration.actions;
    final context = GlobalSnackbar.rawMaterialAppNavigatorKey.currentContext;
    if (index < 0 || index >= actions.length || !_watchQuickActions.contains(actions[index].action)) return;
    // Reject a stale index if the phone's quick actions were reordered.
    if (name != null && actions[index].action.name != name) {
      throw PlatformException(code: "changed", message: "Quick actions changed on your iPhone");
    }
    if (context == null) {
      throw PlatformException(code: "unavailable", message: "Open Finamp on your iPhone for this action");
    }
    await QuickActionsService.handleAction(actions[index], context);
  }

  /// Uses queue history so items appear when playback starts, before Jellyfin marks them played.
  static Future<List<Map<String, Object>>> _recentlyPlayed() async {
    final queueService = GetIt.instance<QueueService>();
    final sources = [
      queueService.getQueue().source,
      ...queueService.getRecentQueueHistory().map((queue) => queue.source),
    ];

    final seen = <String>{};
    final rows = <Map<String, Object>>[];
    for (final source in sources) {
      if (rows.length >= _recentlyPlayedLimit) break;
      final kind = switch (source.type) {
        QueueItemSourceType.album => 'albums',
        QueueItemSourceType.playlist => 'playlists',
        QueueItemSourceType.artist => 'artists',
        _ => null,
      };
      if (kind == null || !seen.add(source.id)) continue;
      final BaseItemDto item;
      try {
        item = source.item ?? await _itemById(source.id);
      } catch (_) {
        continue; // e.g. deleted from the server since
      }
      // Offline, skip items with nothing downloaded; partly downloaded ones open on their downloaded children.
      if (FinampSettingsHelper.finampSettings.isOffline &&
          (await _children(item).catchError((Object _) => <BaseItemDto>[])).isEmpty) {
        continue;
      }
      rows.add({
        ..._rows([item]).single,
        'kind': kind,
      });
    }
    return rows;
  }

  static Future<Map<String, Object>> _search(String query) async {
    Future<List<Map<String, Object>>> find(ContentType contentType) async =>
        _rows(await _query(contentType, limit: _searchSectionSize, searchTerm: query, sortBy: "SortName"));
    final sections = await Future.wait([
      find(_contentType('artists')),
      find(ContentType.albums),
      find(ContentType.playlists),
      find(ContentType.tracks),
    ]);
    return {'artists': sections[0], 'albums': sections[1], 'playlists': sections[2], 'tracks': sections[3]};
  }

  static Future<List<BaseItemDto>> _favorites(ContentType contentType) =>
      _query(contentType, limit: _favoritesLimit, isFavorite: true, sortBy: "SortName");

  /// Values must be non-null property-list types for WatchConnectivity.
  static List<Map<String, Object>> _rows(List<BaseItemDto> items) {
    for (final item in items) {
      _sentItems[item.id] = item;
    }
    return items
        .map(
          (item) => {
            'id': item.id.raw,
            'name': item.name ?? "",
            'subtitle': _subtitle(item),
            'artistId': _mainArtist(item)?.id.raw ?? "",
            'artworkKey': _artworkKey(item),
            'artworkUrl': _artworkUrl(item),
            'artistArtworkUrl': _imageUrlFor(_mainArtist(item)?.id),
            'duration': (item.runTimeTicksDuration() ?? Duration.zero).inMilliseconds / 1000,
            'year': item.productionYear ?? 0,
            'trackCount': item.childCount ?? 0,
            'favorite': item.userData?.isFavorite ?? false,
            ..._downloadState(item),
            'kind': _kind(item),
            if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.album) 'artists': _artists(item.albumArtists),
          },
        )
        .toList();
  }

  /// Queries one page; defaults to the tab's sort unless overridden.
  static Future<List<BaseItemDto>> _query(
    ContentType contentType, {
    int offset = 0,
    int limit = _defaultPageSize,
    String? sortBy,
    String? sortOrder,
    bool? isFavorite,
    String? searchTerm,
  }) async {
    final settings = FinampSettingsHelper.finampSettings;
    if (settings.isOffline) {
      // Offline search and favourites must filter downloaded items locally.
      var items = await _tabPage(contentType, 0, _offlineLimit);
      if (searchTerm != null) {
        final needle = searchTerm.toLowerCase();
        items = items.where((item) => (item.name ?? "").toLowerCase().contains(needle)).toList();
      }
      if (isFavorite ?? false) {
        items = items.where((item) => item.userData?.isFavorite ?? false).toList();
      }
      return items.skip(offset).take(limit).toList();
    }

    final tabSortBy = settings.getTabSortBy(contentType);
    return await GetIt.instance<JellyfinApiHelper>().getItems(
          parentItem: contentType == ContentType.playlists
              ? null
              : GetIt.instance<FinampUserHelper>().currentUser?.currentView,
          includeItemTypes: contentType.itemType!.jellyfinName,
          sortBy:
              sortBy ??
              (contentType == ContentType.tracks
                  ? "${tabSortBy.jellyfinName(contentType)},ParentIndexNumber,IndexNumber"
                  : tabSortBy.jellyfinName(contentType)),
          sortOrder: sortOrder ?? settings.getSortOrder(contentType).toString(),
          artistType: contentType.isArtist ? settings.defaultArtistType : null,
          isFavorite: isFavorite,
          searchTerm: searchTerm,
          startIndex: offset,
          limit: limit,
        ) ??
        [];
  }

  static String _subtitle(BaseItemDto item) => BaseItemDtoType.fromItem(item) == BaseItemDtoType.album
      ? (_mainArtist(item)?.name ?? item.albumArtist ?? item.artists?.join(", ") ?? "")
      : (item.artists?.join(", ") ?? item.albumArtist ?? "");

  static List<Map<String, String>> _artists(List<NameIdPair>? artists) => (artists ?? const [])
      .map((artist) => {'id': artist.id.raw, 'name': artist.name ?? "", 'artworkUrl': _imageUrlFor(artist.id)})
      .toList();

  static NameIdPair? _mainArtist(BaseItemDto item) => BaseItemDtoType.fromItem(item) == BaseItemDtoType.album
      ? item.albumArtists?.firstOrNull
      : item.artistItems?.firstOrNull;

  /// Token-free Jellyfin cover URL; empty when unavailable. The watch adds MaxWidth/MaxHeight.
  static String _artworkUrl(BaseItemDto item) {
    if (FinampSettingsHelper.finampSettings.isOffline) return "";
    return GetIt.instance<JellyfinApiHelper>().getImageUrl(item: item)?.replace(userInfo: '').toString() ?? "";
  }

  /// Token-free image URL by id; Jellyfin returns 404 for items without an image.
  static String _imageUrlFor(BaseItemId? id) {
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (id == null || user == null || FinampSettingsHelper.finampSettings.isOffline) return "";
    final base = Uri.parse(user.baseURL);
    return base
        .replace(
          userInfo: '',
          pathSegments: [...base.pathSegments, "Items", id.raw, "Images", "Primary"],
          queryParameters: {"format": "jpg", "quality": "90"},
        )
        .toString();
  }

  /// Playback mode, codec and bitrate; empty until playback metadata arrives.
  static String _audioInfo(FinampQueueItem current) {
    final metadata = GetIt.instance<ProviderContainer>().read(currentTrackMetadataProvider).valueOrNull;
    if (metadata == null) return "";
    final settings = FinampSettingsHelper.finampSettings;
    final transcoding = !metadata.isDownloaded && (current.item.extras?["shouldTranscode"] as bool? ?? false);
    final MediaStream? audioStream =
        metadata.mediaSourceInfo.mediaStreams.firstWhereOrNull((stream) => stream.type == "Audio") ??
        metadata.mediaSourceInfo.mediaStreams.firstOrNull;
    final codec = transcoding ? settings.transcodingStreamingFormat.codec : audioStream?.codec;
    final bitrate = transcoding
        ? (settings.transcodingStreamingFormat == FinampTranscodingStreamingFormat.flacFragmentedMp4
              ? null
              : settings.transcodeBitrate)
        : audioStream?.bitRate ?? metadata.mediaSourceInfo.bitrate;
    final l10n = GlobalSnackbar.requireL10n;
    final mode = metadata.isDownloaded
        ? l10n.playbackModeLocal
        : (transcoding ? l10n.playbackModeTranscoding : l10n.playbackModeDirectPlaying);
    final format = [
      if (codec != null) codec.toUpperCase(),
      if (bitrate != null) l10n.kiloBitsPerSecondLabel(bitrate ~/ 1000),
    ].join(" @ ");
    return [mode, if (format.isNotEmpty) format].join(" · ");
  }

  /// Returns the phone's audio route and Finamp volume (0–1).
  static Future<Map<String, Object>> _output() async {
    final route = await AVAudioSession().currentRoute;
    final outputs = route.outputs;
    return {
      'route': outputs.map((port) => port.portName).join(" + "),
      'routeType': outputs.firstOrNull?.portType.name ?? "",
      'volume': FinampSettingsHelper.finampSettings.currentVolume,
    };
  }

  /// Returns user downloads in Finamp's artist, album and playlist sections.
  static Future<List<BaseItemDto>> _downloads() async {
    final downloads = GetIt.instance<DownloadsService>();
    final container = GetIt.instance<ProviderContainer>();
    List<BaseItemDto> section(DownloadsScreenCategory category) => container
        .read(downloads.userDownloadedItemsProvider(category))
        .map((stub) => stub.finampCollection?.item ?? stub.baseItem)
        .nonNulls
        .toList();
    return [
      ...section(DownloadsScreenCategory.artists),
      ...section(DownloadsScreenCategory.albums),
      ...section(DownloadsScreenCategory.playlists),
    ];
  }

  static String _kind(BaseItemDto item) => switch (BaseItemDtoType.fromItem(item)) {
    BaseItemDtoType.album => 'albums',
    BaseItemDtoType.playlist => 'playlists',
    BaseItemDtoType.artist => 'artists',
    _ => '',
  };

  /// Whether the item is required as its own download, including queued downloads.
  static bool _isDownloaded(BaseItemDto item) {
    final stub = _downloadStub(item);
    return stub != null && GetIt.instance<DownloadsService>().getStatus(stub, null).isRequired;
  }

  /// Download dependency tooltip; null if unlocked, empty if the requiring item is unknown.
  static String? _downloadLock(BaseItemDto item) {
    final stub = _downloadStub(item);
    if (stub == null) return null;
    final downloads = GetIt.instance<DownloadsService>();
    final status = downloads.getStatus(stub, null);
    if (status == DownloadItemStatus.notNeeded || status.isRequired) return null;
    final parent = downloads.getFirstRequiringItem(stub);
    if (parent == null) return "";
    // Artist downloads wrap a `noItem` collection; use the contained artist for the tooltip.
    final parentItem = parent.finampCollection?.item;
    final parentType = parentItem != null ? BaseItemDtoType.fromItem(parentItem) : parent.baseItemType;
    final l10n = GlobalSnackbar.requireL10n;
    return l10n.incidentalDownloadTooltip(l10n.itemTypeSubtitle(parentType.name, parent.name));
  }

  /// Download stub for a collection or an artist's albums in the current library; null otherwise.
  static DownloadStub? _downloadStub(BaseItemDto item) => switch (BaseItemDtoType.fromItem(item)) {
    BaseItemDtoType.album ||
    BaseItemDtoType.playlist => DownloadStub.fromItem(type: DownloadItemType.collection, item: item),
    BaseItemDtoType.artist => DownloadStub.fromFinampCollection(
      FinampCollection(
        type: FinampCollectionType.collectionWithLibraryFilter,
        library: GetIt.instance<FinampUserHelper>().currentUser?.currentView,
        item: item,
      ),
    ),
    _ => null,
  };

  /// Returns the resulting favourite state, unchanged while offline.
  static Future<bool> _setFavorite(String id, bool favorite) async {
    final item = await _itemById(id);
    // Finamp refuses favourite changes offline; tell the watch in Finamp's own words instead of silently not changing
    if (FinampSettingsHelper.finampSettings.isOffline) {
      throw PlatformException(code: "offline", message: GlobalSnackbar.requireL10n.notAvailableInOfflineMode);
    }
    return GetIt.instance<ProviderContainer>().read(isFavoriteProvider(item).notifier).updateFavorite(favorite);
  }

  /// Returns `{ask: …}` for required answers; repeat with `transcode`, `locationId` or `confirmed`.
  /// Otherwise returns `{status: "downloading" | "alreadyDownloaded"}`.
  static Future<Map<String, Object>> _download(Map<String, dynamic> arguments) async {
    final item = await _itemById(arguments['id'] as String);
    if (_downloadStub(item) == null) {
      throw PlatformException(code: "unknown", message: "Unknown item");
    }
    if (_isDownloaded(item)) return {'status': 'alreadyDownloaded'};

    final settings = FinampSettingsHelper.finampSettings;

    final transcodeProfile = settings.downloadTranscodingProfile;
    final bool transcode;
    switch (settings.shouldTranscodeDownloads) {
      case TranscodeDownloadsSetting.always:
        transcode = true;
      case TranscodeDownloadsSetting.never:
        transcode = false;
      case TranscodeDownloadsSetting.ask:
        final answer = arguments['transcode'] as bool?;
        if (answer == null) {
          return {
            'ask': 'transcode',
            'transcodedLabel':
                "${transcodeProfile.codec.name.toUpperCase()} ${transcodeProfile.stereoBitrate ~/ 1000} kbps",
          };
        }
        transcode = answer;
    }

    String? location = arguments['locationId'] as String? ?? settings.defaultDownloadLocation;
    if (!settings.downloadLocationsMap.containsKey(location)) location = null;
    if (location == null) {
      final candidates = settings.downloadLocationsMap.values
          .where((element) => element.baseDirectory != DownloadLocationType.internalDocuments)
          .toList();
      if (candidates.length == 1) {
        location = candidates.first.id;
      } else {
        return {
          'ask': 'location',
          'locations': [
            for (final candidate in candidates) {'id': candidate.id, 'name': candidate.name},
          ],
        };
      }
    }

    // Match DownloadDialog's warning count across all of an artist's albums.
    final trackCount = BaseItemDtoType.fromItem(item) == BaseItemDtoType.artist
        ? (await GetIt.instance<JellyfinApiHelper>().getItems(
                parentItem: item,
                includeItemTypes: BaseItemDtoType.album.jellyfinName,
              ))?.fold<int>(0, (count, album) => count + (album.childCount ?? 0)) ??
              0
        : item.childCount ?? 0;
    if (trackCount >= settings.downloadSizeWarningCutoff && arguments['confirmed'] != true) {
      return {'ask': 'confirm', 'message': GlobalSnackbar.requireL10n.largeDownloadWarning(trackCount)};
    }

    final profile = transcode ? transcodeProfile : DownloadProfile(transcodeCodec: FinampTranscodingCodec.original);
    profile.downloadLocationId = location;
    FinampSetters.setLastUsedDownloadLocationId(location);
    unawaited(
      GetIt.instance<DownloadsService>()
          .addDownload(
            stub: _downloadStub(item)!,
            viewId: GetIt.instance<FinampUserHelper>().currentUser!.currentViewId,
            transcodeProfile: profile,
          )
          .onError((error, stackTrace) => GlobalSnackbar.error(error)),
    );
    return {'status': 'downloading'};
  }

  /// Image id plus image tag, so replaced covers invalidate the watch cache; empty without a cover.
  static String _artworkKey(BaseItemDto item) {
    final imageId = item.imageId;
    if (imageId == null) {
      // Coverless playlists borrow their first track's album cover.
      return BaseItemDtoType.fromItem(item) == BaseItemDtoType.playlist ? "first-${item.id.raw}" : "";
    }
    final tag = item.hasOwnImage
        ? item.imageTags!["Primary"]
        : (item.parentPrimaryImageItemId != null ? item.parentPrimaryImageTag : item.albumPrimaryImageTag);
    return "$imageId-${tag ?? ""}";
  }

  /// Plays a collection from `startId`, or the displayed `offset`/`limit` page when `parentId` is absent.
  static Future<void> _play(Map<String, dynamic> arguments) async {
    switch (arguments['type']) {
      case 'favorites':
        await _playTrackList(
          await _favorites(ContentType.tracks),
          arguments,
          QueueItemSource.rawId(
            type: QueueItemSourceType.favorites,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.yourLikes),
            id: "favorites",
          ),
        );
        return;
      case 'favoriteAlbums':
        final albums = await _favorites(ContentType.albums);
        // An unavailable album must not prevent the other favourites from playing.
        final albumTracks = await _fetchAll(
          albums,
          (album) => _children(album).catchError((Object _) => <BaseItemDto>[]),
        );
        await _playTrackList(
          albumTracks.expand((tracks) => tracks).toList(),
          arguments,
          _favoritesSource("favoriteAlbums", GlobalSnackbar.requireL10n.favoriteAlbums),
        );
        return;
      case 'favoriteArtists':
        final artists = await _favorites(_contentType('artists'));
        final artistTracks = await _fetchAll(
          artists,
          (artist) => _readOnce(
            getChildTracksProvider(item: Artist<Track>.fromItem(artist)).future,
          ).catchError((Object _) => <Track>[]),
        );
        await _playTrackList(
          artistTracks.expand((tracks) => tracks.map((track) => track.item)).toList(),
          arguments,
          _favoritesSource("favoriteArtists", GlobalSnackbar.requireL10n.favoriteArtists),
        );
        return;
      case 'search':
        final query = arguments['query'] as String;
        await _playTrackList(
          await _query(ContentType.tracks, limit: _searchSectionSize, searchTerm: query, sortBy: "SortName"),
          arguments,
          QueueItemSource.rawId(
            type: QueueItemSourceType.filteredList,
            name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: query),
            id: "search",
          ),
        );
        return;
    }
    if (arguments['parentId'] == null) {
      await _playTracksPage(arguments);
      return;
    }
    if (arguments['type'] == 'artist') {
      await _playArtist(arguments);
      return;
    }

    final parentId = arguments['parentId'] as String;
    final parent = await _itemById(parentId);
    // The list the watch is showing, if it's this collection's (saves a server round trip)
    final cached = _childrenCache;
    final tracks = cached != null && cached.$1 == parentId ? cached.$2 : await _children(parent);
    await _playTrackList(tracks, arguments, QueueItemSource.fromBaseItem(parent));
  }

  /// Uses Finamp's artist playback slices, including album shuffle.
  static Future<void> _playArtist(Map<String, dynamic> arguments) async {
    final artist = Artist<Track>.fromItem(await _itemById(arguments['parentId'] as String));
    final PlayableSlice slice;
    if (arguments['albumShuffle'] == true) {
      slice = await _readOnce(getAlbumShuffledPlayerSliceProvider(item: artist).future);
    } else {
      final linear = await _readOnce(getPlayableSliceProvider(item: artist, startingOffset: 0).future);
      slice = (arguments['shuffle'] as bool? ?? false) ? linear.shuffle() : linear;
    }
    await GetIt.instance<QueueService>().startSlicePlayback(slice);
  }

  static Future<Map<String, Object>> _artistInfo(String id) async {
    final item = await _itemById(id);
    final artist = Artist<Track>.fromItem(item);
    final tracks = await _readOnce(getChildTracksProvider(item: artist).future);
    return {
      'tracks': tracks.length,
      'favorite': GetIt.instance<ProviderContainer>().read(isFavoriteProvider(item)),
      ..._downloadState(item),
    };
  }

  /// Reads current download state because the list row's copy can be stale.
  static Map<String, Object> _downloadState(BaseItemDto item) => {
    'downloaded': _isDownloaded(item),
    'downloadLock': ?_downloadLock(item),
  };

  /// Resolves sent items first, then Finamp's cached, offline-aware lookup.
  static Future<BaseItemDto> _itemById(String id) async {
    if (!_jellyfinId.hasMatch(id)) throw PlatformException(code: "invalid", message: "Invalid item id");
    final known = _sentItems[BaseItemId(id)];
    if (known != null) return known;
    final item = await _readOnce(itemByIdProvider(BaseItemId(id)).future);
    if (item == null) throw PlatformException(code: "unknown", message: "Unknown item");
    return _sentItems[item.id] = item;
  }

  /// Runs `fetch` for every item with at most [_parallelFetches] in flight, results in input order.
  static Future<List<R>> _fetchAll<T, R>(List<T> items, Future<R> Function(T) fetch) async {
    final results = List<R?>.filled(items.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        final i = next++;
        results[i] = await fetch(items[i]);
      }
    }

    await Future.wait(List.generate(min(_parallelFetches, items.length), (_) => worker()));
    return results.cast<R>();
  }

  /// Keeps an auto-disposed provider alive until its value arrives.
  static Future<T> _readOnce<T>(ProviderListenable<Future<T>> provider) async {
    final subscription = GetIt.instance<ProviderContainer>().listen(provider, (_, _) {});
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }

  static Future<void> _playTracksPage(Map<String, dynamic> arguments) async {
    await _playTrackList(
      await _tabPage(
        ContentType.tracks,
        arguments['offset'] as int? ?? 0,
        arguments['limit'] as int? ?? _defaultPageSize,
      ),
      arguments,
      QueueItemSource.rawId(
        type: QueueItemSourceType.allTracks,
        name: const QueueItemSourceName(type: QueueItemSourceNameType.musicScreenTracks),
        id: "allTracks",
      ),
    );
  }

  static QueueItemSource _favoritesSource(String id, String name) => QueueItemSource.rawId(
    type: QueueItemSourceType.favorites,
    name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: name),
    id: id,
  );

  /// Starts at `startId` (or the first track), honouring `shuffle`.
  static Future<void> _playTrackList(
    List<BaseItemDto> tracks,
    Map<String, dynamic> arguments,
    QueueItemSource source,
  ) async {
    final startId = arguments['startId'] as String?;
    final startingIndex = tracks.indexWhere((track) => track.id.raw == startId);
    await GetIt.instance<QueueService>().startPlayback(
      items: tracks,
      source: source,
      order: (arguments['shuffle'] as bool? ?? false) ? FinampPlaybackOrder.shuffled : FinampPlaybackOrder.linear,
      startingIndex: startingIndex < 0 ? null : startingIndex,
    );
  }

  /// Batches covers to save round trips; returns `[{id, data, width, height}]` in request order.
  /// `data` is raw RGBA pixels (the iOS side encodes the JPEG), omitted when no cover is available.
  static Future<List<Map<String, Object>>> _artworks(Map<String, dynamic> arguments) async {
    // Bounded here, not only by the watch: at most a batch of 20, each between 16 and 1200 px
    final requests = (arguments['items'] as List).take(20).map((request) => Map<String, dynamic>.from(request as Map));
    return await Future.wait(
      requests.map((request) async {
        final id = request['id'] as String;
        final cover = await _artwork(id, (request['size'] as int? ?? _defaultWatchArtworkSize).clamp(16, 1200));
        return {
          'id': id,
          // A downloaded cover comes encoded (width 0); others as raw pixels with their size
          if (cover != null) ...{
            'data': cover.data,
            if (cover.width > 0) ...{'width': cover.width, 'height': cover.height},
          },
        };
      }),
    );
  }

  /// Caches playlist cover lookups to avoid repeated requests for the first track.
  static final Map<BaseItemId, BaseItemDto?> _playlistFirstTracks = {};

  static Future<BaseItemDto?> _firstTrack(BaseItemDto playlist) async {
    if (_playlistFirstTracks.containsKey(playlist.id)) return _playlistFirstTracks[playlist.id];
    final tracks = await GetIt.instance<JellyfinApiHelper>().getItems(
      parentItem: playlist,
      includeItemTypes: BaseItemDtoType.track.jellyfinName,
      limit: 1,
    );
    return _playlistFirstTracks[playlist.id] = tracks?.firstOrNull;
  }

  /// Returns a cached cover's raw RGBA pixels, or null if unavailable. Raw pixels skip a costly PNG encode.
  static Future<({Uint8List data, int width, int height})?> _artwork(String id, int size) async {
    BaseItemDto? item;
    try {
      item = await _itemById(id);
    } catch (_) {
      return null;
    }
    if (item.imageId == null && BaseItemDtoType.fromItem(item) == BaseItemDtoType.playlist) {
      try {
        item = await _firstTrack(item);
      } catch (_) {
        return null;
      }
    }
    if (item == null || item.imageId == null) return null;

    // A downloaded cover: the file Finamp saved, sent as it is for the iOS side to decode. Flutter's image decoding
    // below only completes while Finamp is in the foreground, which it often isn't when the watch asks.
    final file = GetIt.instance<DownloadsService>().getImageDownload(item: item)?.file;
    if (file != null && await file.exists()) {
      return (data: await file.readAsBytes(), width: 0, height: 0);
    }

    // Request the full size: iOS only scales down, so smaller sources would look blurry.
    final imageProvider = GetIt.instance<ProviderContainer>()
        .read(albumImageProvider(AlbumImageRequest(item: item, maxWidth: size, maxHeight: size)))
        .image;
    if (imageProvider == null) return null;

    final completer = Completer<ImageInfo?>();
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        stream.removeListener(listener);
        completer.complete(imageInfo);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        _logger.warning("Failed to load watch artwork for $id", error);
        completer.complete(null);
      },
    );
    stream.addListener(listener);

    final imageInfo = await completer.future;
    if (imageInfo == null) return null;
    final image = imageInfo.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final cover = byteData == null
        ? null
        : (data: byteData.buffer.asUint8List(), width: image.width, height: image.height);
    imageInfo.dispose();
    return cover;
  }
}
