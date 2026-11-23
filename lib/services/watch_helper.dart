import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart' show AudioProcessingState;
import 'package:audio_session/audio_session.dart';
import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/models/music_slices.dart';
import 'package:finamp/services/data_source_service.dart' show SourceChangeGenericType;
import 'package:finamp/services/datetime_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/extensions/color_extensions.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' show ClientException;
import 'package:http/http.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart' show DefaultCacheManager;
import 'package:logging/logging.dart';

import 'android_auto_helper.dart';
import 'album_screen_provider.dart';
import 'artist_content_provider.dart';
import 'current_track_metadata_provider.dart';
import 'downloads_service.dart';
import 'favorite_provider.dart';
import 'item_by_id_provider.dart';
import 'music_player_background_task.dart';
import 'music_screen_provider.dart';
import 'output_route_provider.dart';
import 'queue_service.dart';
import 'quick_actions_service.dart';
import 'radio_service_helper.dart' show currentRadioAvailabilityStatusProvider, toggleRadio;

final _logger = Logger('WatchHandler');
// The watch's own log lines and the iOS bridge's, kept in Finamp's logs (Settings → Logs) for bug reports.
final _watchLogger = Logger('FinampWatch');

// Decode fallback only; the iOS relay requires an explicit size.
const _defaultWatchArtworkSize = 160;

const _defaultPageSize = 50;

const _homeSectionSize = 8;
const _recentlyPlayedLimit = 6;
const _searchSectionSize = 5;
const _favoritesLimit = 200;

const _queueLimit = 30;

const _upNextCoverCount = 2;

// Split pages early to stay under WatchConnectivity's ~64 KB reply limit.
const _replyBudget = 40 * 1024;

class WatchHandler {
  static const _watchChannel = MethodChannel('com.unicornsonlsd.finamp-ios/watch');

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is ClientException ||
      error is TimeoutException ||
      (error is Response && (error.error is SocketException || error.error is ClientException));

  // Refuse malformed IDs before sending a Jellyfin request.
  static final _jellyfinId = RegExp(r'^[0-9a-fA-F]{32}$');

  // The full list retained while the watch pages through it, by "<type>:<parentId>".
  static (String, List<BaseItemDto>)? _childrenCache;

  // Cache recently sent items to resolve later artwork requests.
  static final Map<BaseItemId, BaseItemDto> _sentItems = {};
  static const _sentItemsLimit = 500;

  static void _rememberSent(BaseItemDto item) {
    _sentItems.remove(item.id);
    _sentItems[item.id] = item;
    if (_sentItems.length > _sentItemsLimit) _sentItems.remove(_sentItems.keys.first);
  }

  // Each line keeps the time it happened (the watch can send its lines much later).
  static void _logFromWatch(List<Object?> lines) {
    for (final line in lines.whereType<Map<Object?, Object?>>()) {
      final time = DateTime.fromMillisecondsSinceEpoch(((line['t'] as num? ?? 0) * 1000).round());
      final level = switch (line['l']) {
        'warning' => Level.WARNING,
        'info' => Level.INFO,
        _ => Level.FINE,
      };
      _watchLogger.log(level, "${line['s'] ?? 'Watch'} ${time.toIso8601String()} ${line['m']}");
    }
  }

  static void setup() {
    if (!Platform.isIOS) return;

    _watchChannel.setMethodCallHandler((call) async {
      final arguments = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      _logger.fine("Watch request: ${call.method} $arguments");
      if (call.method == 'watchLog') {
        _logFromWatch(arguments['lines'] as List<Object?>? ?? const []);
        return null;
      }
      if (call.method != 'watchState') _startPushing();
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
            GetIt.instance<MusicPlayerBackgroundTask>().setVolume(
              (arguments['volume'] as num).toDouble().clamp(0.0, 1.0),
            );
            return true;
          case 'seek':
            final seconds = (arguments['position'] as num).toDouble();
            await GetIt.instance<MusicPlayerBackgroundTask>().seek(
              Duration(milliseconds: max(0, (seconds * 1000).round())),
            );
            return true;
          case 'watchState':
            arguments['available'] == true ? _startPushing() : _stopPushing();
            return true;
          case 'settings':
            final settings = FinampSettingsHelper.finampSettings;
            return {'transcoding': settings.shouldTranscode, 'offline': settings.isOffline};
          case 'setSetting':
            final name = arguments['name'] as String;
            final enabled = arguments['enabled'] as bool;
            switch (name) {
              case 'transcoding':
                FinampSetters.setShouldTranscode(enabled);
              case 'offline':
                FinampSetters.setIsOffline(enabled);
              default:
                throw PlatformException(code: "unknown", message: "Unknown setting");
            }
            final question = _reloadQuestion(name, enabled);
            return question == null
                ? true
                : {
                    'reload': question,
                    'reloadButton': GlobalSnackbar.requireL10n.autoReloadPromptReloadButton,
                    'archive': name == 'offline',
                  };
          case 'reloadQueue':
            await GetIt.instance<QueueService>().reloadQueue(archiveQueue: arguments['archive'] == true);
            return true;
          case 'favorite':
            return await _setFavorite(arguments['id'] as String, arguments['favorite'] as bool);
          case 'playlistMenu':
            return await _playlistMenu(arguments['id'] as String);
          case 'playlistToggle':
            return await _playlistToggle(
              arguments['id'] as String,
              arguments['playlistId'] as String,
              arguments['add'] as bool,
            );
          case 'download':
            return await _download(arguments);
          case 'deleteDownload':
            return await _deleteDownload(arguments['id'] as String);
          case 'artistInfo':
            return await _artistInfo(arguments['id'] as String);
          case 'item':
            return _rows([await _itemById(arguments['id'] as String)]).single;
          case 'downloadState':
            return _downloadState(await _itemById(arguments['id'] as String));
          case 'favoritesCount':
            return await _favoritesCount();
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
            // Not MissingPluginException: iOS reports that as "Finamp is still starting"
            throw PlatformException(code: "unsupported", message: "Update Finamp on your iPhone");
        }
      } catch (error) {
        // Send plain error message without exposing user/server details.
        if (_isNetworkError(error)) {
          throw PlatformException(code: "server", message: "Can't reach your Jellyfin server");
        }
        if (error is PlatformException) rethrow;
        _logger.warning("Watch request ${call.method} failed: $error");
        throw PlatformException(code: "error", message: "Finamp couldn't do that on your iPhone");
      }
    });

    // Avoid player subscriptions if watch app is not installed.
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

  // Ask to reload affected tracks unless auto-reload is on; no answer keeps the old queue.
  static String? _reloadQuestion(String name, bool enabled) {
    if (FinampSettingsHelper.finampSettings.autoReloadQueue) return null;
    final queue = GetIt.instance<QueueService>().getQueue();
    if (queue.trackCount == 0) return null;
    final l10n = GlobalSnackbar.requireL10n;
    if (name == 'offline') {
      if (!enabled || queue.undownloadedTracks == 0) return null;
      return "${l10n.autoReloadPrompt(SourceChangeGenericType.network.name)}. "
          "${l10n.autoReloadPromptMissingTracks(queue.undownloadedTracks)}";
    }
    final transcodedTracksQueued = queue.fullQueue.any((item) => item.item.extras?["shouldTranscode"] == true);
    if (!enabled && !transcodedTracksQueued) return null;
    return l10n.autoReloadPrompt(SourceChangeGenericType.transcoding.name);
  }

  static final List<void Function()> _stopListening = [];

  static void _startPushing() {
    if (_pushing) return;
    _pushing = true;
    final container = GetIt.instance<ProviderContainer>();
    _stopListening.addAll([
      GetIt.instance<QueueService>().getCurrentTrackStream().listen((_) => _scheduleNowPlayingPush()).cancel,
      GetIt.instance<MusicPlayerBackgroundTask>().playbackState.listen((_) => _scheduleNowPlayingPush()).cancel,
      // Metadata arrives after the track; this also keeps the provider alive.
      container.listen(currentTrackMetadataProvider, (_, _) => _scheduleNowPlayingPush()).close,
      GetIt.instance<QueueService>().getLoopModeStream().listen((_) => _scheduleNowPlayingPush()).cancel,
      GetIt.instance<QueueService>().getPlaybackOrderStream().listen((_) => _scheduleNowPlayingPush()).cancel,
      container.listen(finampSettingsProvider.radioEnabled, (_, _) => _scheduleNowPlayingPush()).close,
      container.listen(currentRadioAvailabilityStatusProvider, (_, _) => _scheduleNowPlayingPush()).close,
      // The feature chips
      container.listen(finampSettingsProvider.featureChipsConfiguration, (_, _) => _scheduleNowPlayingPush()).close,
      container.listen(finampSettingsProvider.playbackSpeed, (_, _) => _scheduleNowPlayingPush()).close,
      container.listen(finampSettingsProvider.currentVolume, (_, _) => _scheduleNowPlayingPush()).close,
      container.listen(finampSettingsProvider.volumeNormalizationActive, (_, _) => _scheduleNowPlayingPush()).close,
      container.listen(finampSettingsProvider.accentColor, (_, _) => _pushIfChanged('accent', _accent())).close,
      container.listen(finampSettingsProvider.systemAccentColor, (_, _) => _pushIfChanged('accent', _accent())).close,
      container
          .listen(finampSettingsProvider.useSystemAccentColor, (_, _) => _pushIfChanged('accent', _accent()))
          .close,
      container.listen(finampSettingsProvider.amoledTheme, (_, _) => _pushIfChanged('accent', _accent())).close,
      container
          .listen(
            finampSettingsProvider.preferAddingToFavoritesOverPlaylists,
            (_, prefer) => _pushIfChanged('preferFavorites', prefer),
          )
          .close,
      // Address changes also fire user provider; only account change clears cache.
      container.listen(FinampUserHelper.finampCurrentUserProvider, (_, _) {
        final account = _account();
        if (account != _lastPushedValues['account']) {
          _sentItems.clear();
          _playlistFirstTracks.clear();
          _childrenCache = null;
          for (final subscription in _followedFavorites.values) {
            subscription.close();
          }
          _followedFavorites.clear();
          _pushFavoriteStates();
        }
        _pushIfChanged('account', account);
      }).close,
      container
          .listen(finampSettingsProvider.shouldTranscode, (_, enabled) => _pushIfChanged('transcoding', enabled))
          .close,
      container.listen(finampSettingsProvider.isOffline, (_, offline) {
        _childrenCache = null; // may list tracks that can't play in the new mode
        _pushIfChanged('offline', offline);
      }).close,
      container.listen(finampSettingsProvider.currentVolume, (_, volume) => _pushIfChanged('volume', volume)).close,
      // Finamp volume has no effect during AirPlay; disable the watch slider too.
      container
          .listen(
            airPlayActiveProvider,
            (_, airPlay) => _pushIfChanged('airPlay', airPlay.valueOrNull ?? false),
            fireImmediately: true,
          )
          .close,
      // The Output sheet follows the route while it's open (headphones connected or removed, AirPlay chosen).
      AVAudioSession().routeChangeStream
          .listen((_) async => _pushIfChanged('outputRoute', await _outputRoute()))
          .cancel,
    ]);
    _pushIfChanged('accent', _accent());
    _pushIfChanged('account', _account());
    _pushIfChanged('transcoding', FinampSettingsHelper.finampSettings.shouldTranscode);
    _pushIfChanged('volume', FinampSettingsHelper.finampSettings.currentVolume);
    _pushIfChanged('offline', FinampSettingsHelper.finampSettings.isOffline);
    _pushIfChanged('preferFavorites', FinampSettingsHelper.finampSettings.preferAddingToFavoritesOverPlaylists);
    unawaited(_outputRoute().then((route) => _pushIfChanged('outputRoute', route)));
  }

  static void _stopPushing() {
    if (!_pushing) return;
    _pushing = false;
    for (final stop in _stopListening) {
      stop();
    }
    _stopListening.clear();
    _nowPlayingPushTimer?.cancel();
    _favoriteSubscription?.close();
    _favoriteSubscription = null;
    _favoriteSubscriptionItem = null;
    _coverColorSubscription?.close();
    _coverColorSubscription = null;
    _coverColorSubscriptionItem = null;
    _lastPushed = null;
    _lastPushedValues.clear();
  }

  static Timer? _nowPlayingPushTimer;
  static Map<String, Object>? _lastPushed;
  static ProviderSubscription<bool>? _favoriteSubscription;
  static BaseItemId? _favoriteSubscriptionItem;
  static ProviderSubscription<ColorScheme>? _coverColorSubscription;
  static BaseItemId? _coverColorSubscriptionItem;

  // Coalesce player events into one push 150 ms after the first. The watch's own timings, which this must stay well
  // under, are all in `ios/FinampWatch Watch App/ConnectionPolicy.swift`.
  static void _scheduleNowPlayingPush() {
    if (_nowPlayingPushTimer?.isActive ?? false) return;
    _nowPlayingPushTimer = Timer(const Duration(milliseconds: 150), _pushNowPlaying);
  }

  // Watch advances position locally; skip periodic progress pushes.
  static void _pushNowPlaying() {
    final state = _nowPlaying();
    final last = _lastPushed;
    if (last != null) {
      final unchanged = state.keys.every(
        // Compare artist list contents as lists are rebuilt each time.
        (key) =>
            key == 'position' ||
            key == 'updatedAt' ||
            state[key] == last[key] ||
            const DeepCollectionEquality().equals(state[key], last[key]),
      );
      // At the player's speed, as the watch advances it.
      final expected =
          (last['position'] as double) +
          ((last['advancing'] as bool)
              ? ((state['updatedAt'] as double) - (last['updatedAt'] as double)) * (last['speed'] as double? ?? 1)
              : 0);
      if (unchanged && ((state['position'] as double) - expected).abs() < 2) return;
    }
    _lastPushed = state;
    unawaited(
      _watchChannel.invokeMethod('nowPlaying', state).catchError((Object error) {
        _logger.fine("Couldn't push now playing to the watch: $error");
      }),
    );
  }

  // Position and updatedAt are seconds; the watch extrapolates only while advancing.
  static Map<String, Object> _nowPlaying() {
    final current = GetIt.instance<QueueService>().getCurrentTrack();
    final playbackState = GetIt.instance<MusicPlayerBackgroundTask>().playbackState.value;
    final now = DateTime.now();
    final item = current?.baseItem;
    if (current == null || item == null) {
      return {
        'hasTrack': false,
        'playing': false,
        'advancing': false,
        'position': 0.0,
        'updatedAt': now.millisecondsSinceEpoch / 1000,
      };
    }

    _rememberSent(item);
    _watchFavorite(item);
    final queueService = GetIt.instance<QueueService>();
    return {
      'hasTrack': true,
      'id': item.id.raw,
      'title': current.item.title,
      'artist': current.item.artist ?? item.artists?.join(", ") ?? "",
      'artworkKey': _artworkKey(item),
      'blurHash': item.blurHash ?? "",
      'albumId': item.albumId?.raw ?? "",
      'album': item.album ?? "",
      'albumArtist': item.albumArtists?.firstOrNull?.name ?? item.albumArtist ?? "",
      'albumArtistId': item.albumArtists?.firstOrNull?.id.raw ?? "",
      'artists': _artists(item.artistItems),
      'features': _features(current),
      'shortFeatures': _shortFeatures(current),
      'duration': (current.item.duration ?? item.runTimeTicksDuration() ?? Duration.zero).inMilliseconds / 1000,
      'position': playbackState.position.inMilliseconds / 1000,
      'updatedAt': now.millisecondsSinceEpoch / 1000,
      // The player's speed (Finamp's playback speed setting), so the watch advances the position at the same rate.
      'speed': playbackState.speed,
      'playing': playbackState.playing,
      // Keep the watch clock still while loading or buffering.
      'advancing': playbackState.playing && playbackState.processingState == AudioProcessingState.ready,
      'loop': queueService.loopMode.name,
      'shuffled': queueService.playbackOrder == FinampPlaybackOrder.shuffled,
      'radio': FinampSettingsHelper.finampSettings.radioEnabled,
      // Radio button uses accent colour only when available.
      'radioAvailable': GetIt.instance<ProviderContainer>().read(currentRadioAvailabilityStatusProvider).isAvailable,
      'favorite': GetIt.instance<ProviderContainer>().read(isFavoriteProvider(item)),
      'upNext': _upNextCovers(),
      'coverColor': _coverColor(item),
    };
  }

  // Find the item by ID: the queue may have moved since the watch listed it.
  static Future<void> _skipTo(String id) async {
    final queueService = GetIt.instance<QueueService>();
    final queue = queueService.getQueue();
    final index = [...queue.nextUp, ...queue.queue].indexWhere((track) => track.id == id);
    if (index < 0) throw PlatformException(code: "gone", message: "That track has already played");
    await queueService.skipByOffset(index + 1);
  }

  static List<Map<String, Object>> _upNextCovers() {
    final queueService = GetIt.instance<QueueService>();
    final queue = queueService.getQueue();
    return CombinedIterableView([
      queue.nextUp,
      queue.queue,
      if (queueService.loopMode == FinampLoopMode.all) queue.previousTracks,
    ]).map((track) => track.baseItem).nonNulls.take(_upNextCoverCount).map((item) {
      // Retain IDs for phone artwork fallback when direct requests fail.
      _rememberSent(item);
      return {'id': item.id.raw, 'artworkKey': _artworkKey(item)};
    }).toList();
  }

  static List<Map<String, Object>> _upcoming() {
    final queue = GetIt.instance<QueueService>().getQueue();
    return CombinedIterableView([queue.nextUp, queue.queue])
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

  // Keep current track's favourite provider alive and push changes.
  static void _watchFavorite(BaseItemDto item) {
    if (_favoriteSubscriptionItem == item.id) return;
    _favoriteSubscription?.close();
    _favoriteSubscriptionItem = item.id;
    _favoriteSubscription = GetIt.instance<ProviderContainer>().listen(
      isFavoriteProvider(item),
      (_, _) => _scheduleNowPlayingPush(),
    );
  }

  // The colour Finamp's player and queue take from this track's cover (their theme's primary), as ARGB. It starts
  // grey and changes once the cover is analysed, which pushes again. The watch is always dark, so a colour made for
  // Finamp's light theme is lifted until it reads on black.
  static int _coverColor(BaseItemDto item) {
    if (_coverColorSubscriptionItem != item.id) {
      _coverColorSubscription?.close();
      _coverColorSubscriptionItem = item.id;
      _coverColorSubscription = GetIt.instance<ProviderContainer>().listen(
        finampThemeProvider(ThemeInfo(item, useLargeImage: true)),
        (_, _) => _scheduleNowPlayingPush(),
      );
    }
    return _onBlack(_coverColorSubscription!.read().primary);
  }

  static int _onBlack(Color color) => color.atContrast(5.5, const Color(0xFF000000), true).toARGB32();

  // The colour Finamp themes a track's menus with (`showThemedBottomSheet`): its cover's theme, waiting up to
  // [_menuColorWait] for a cover not analysed yet (grey until then).
  static Future<int> _menuColor(BaseItemDto item) async {
    final container = GetIt.instance<ProviderContainer>();
    final gray = getGrayTheme(container.read(brightnessProvider));
    final analysed = Completer<ColorScheme>();
    final subscription = container.listen(finampThemeProvider(ThemeInfo(item)), (_, scheme) {
      if (scheme != gray && !analysed.isCompleted) analysed.complete(scheme);
    });
    var scheme = subscription.read();
    if (scheme == gray) scheme = await analysed.future.timeout(_menuColorWait, onTimeout: () => gray);
    subscription.close();
    return _onBlack(scheme.primary);
  }

  static const _menuColorWait = Duration(seconds: 1);

  static Future<void> _control(String action) async {
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    switch (action) {
      case 'playPause':
        // As Finamp's own play buttons: play() completes only when playback stops again, so waiting for it left the
        // watch without an answer for every "play".
        unawaited(audioHandler.togglePlayback());
      case 'next':
        await audioHandler.skipToNext();
      case 'previous':
        await audioHandler.skipToPrevious();
      // Looping waits while radio is on.
      case 'toggleLoop':
        if (!FinampSettingsHelper.finampSettings.radioEnabled) GetIt.instance<QueueService>().toggleLoopMode();
      case 'togglePlaybackOrder':
        await GetIt.instance<QueueService>().togglePlaybackOrder();
      case 'toggleRadio':
        toggleRadio();
      default:
        throw PlatformException(code: "unsupported", message: "Update Finamp on your iPhone");
    }
  }

  static ContentType _contentType(String type) {
    if (type == 'artists') {
      return FinampSettingsHelper.finampSettings.defaultArtistType == ArtistType.albumArtist
          ? ContentType.albumArtists
          : ContentType.performingArtists;
    }
    return ContentType.values.byName(type);
  }

  // Return a page of library items kept under [_replyBudget].
  static Future<List<Map<String, Object>>> _list(Map<String, dynamic> arguments) async {
    final type = arguments['type'] as String;
    final offset = arguments['offset'] as int? ?? 0;
    final limit = arguments['limit'] as int? ?? _defaultPageSize;
    final parentId = arguments['parentId'] as String?;
    final List<BaseItemDto> items;
    if (type == 'favorites') {
      items = await _favorites(ContentType.tracks, offset: offset, limit: limit);
    } else if (type == 'downloads') {
      items = (await _downloads()).skip(offset).take(limit).toList();
    } else if (type == 'favoriteAlbums') {
      items = await _favorites(ContentType.albums, offset: offset, limit: limit);
    } else if (type == 'favoriteArtists') {
      items = await _favorites(_contentType('artists'), offset: offset, limit: limit);
    } else if (parentId == null) {
      items = await _tabPage(_contentType(type), offset, limit);
    } else {
      final parent = await _itemById(parentId);
      final key = "$type:$parentId";
      if (offset == 0 || _childrenCache?.$1 != key) _childrenCache = (key, await _parentList(type, parent));
      items = _childrenCache!.$2.skip(offset).take(limit).toList();
    }
    return _withinReplyBudget(_rows(items));
  }

  static List<Map<String, Object>> _withinReplyBudget(List<Map<String, Object>> rows) {
    var bytes = 0;
    for (final (index, row) in rows.indexed) {
      bytes += utf8.encode(jsonEncode(row)).length;
      if (bytes > _replyBudget && index > 0) return rows.sublist(0, index);
    }
    return rows;
  }

  // Reuse controllers to avoid leaking cached sort state.
  static final _tabSortControllers = <ContentType, SortAndFilterController>{};

  static final _artistAlbumsSortController = SortAndFilterController(
    contentType: ContentType.tracks,
    startingConfig: const SortAndFilterConfiguration(
      sortBy: SortBy.premiereDate,
      sortOrder: SortOrder.ascending,
      filters: {},
    ),
  );

  static Future<List<BaseItemDto>> _tabPage(
    ContentType tab,
    int offset,
    int limit, {
    String? search,
    bool favorites = false,
  }) async {
    // Every library list first looks up the library itself (`_fetchMusicScreenPageOnline`).
    final library = GetIt.instance<FinampUserHelper>().currentUser?.currentView?.id;
    return await _readOnce<List<BaseItemDto>?>(
          loadHomeSectionItemsProvider(
            request: _tabPlayable(tab, search: search, favorites: favorites),
            startIndex: offset,
            limit: limit,
          ),
          dependsOn: [if (library != null) itemByIdProvider(library)],
        ) ??
        [];
  }

  static MusicScreenPlayable _tabPlayable(ContentType tab, {String? search, bool favorites = false}) {
    var sortConfig = _tabSortControllers
        .putIfAbsent(tab, () => SortAndFilterController.trackSettings(tab))
        .resolveConfig();
    if (search != null) sortConfig = sortConfig.copyWithSearch(search);
    if (favorites) sortConfig = ResolvedSortConfig.skipResolving(sortConfig.copyWith(favoriteFilter: true));
    return MusicScreenPlayable(
      tab: tab,
      library: currentLibraryPlaceholder,
      source: QueueItemSource.rawId(
        type: QueueItemSourceType.allTracks,
        name: const QueueItemSourceName(type: QueueItemSourceNameType.musicScreenTracks),
        id: "allTracks",
      ),
      sortConfig: sortConfig,
    );
  }

  // A parent's list: for an artist, Finamp's artist screen sections (`albums`: where they're the album artist;
  // `appearsOn`: albums they perform on, without those), else a collection's tracks.
  static Future<List<BaseItemDto>> _parentList(String type, BaseItemDto parent) async {
    if (BaseItemDtoType.fromItem(parent) != BaseItemDtoType.artist) return _children(parent);
    return type == 'appearsOn' ? _appearsOnAlbums(parent) : _artistAlbums(parent);
  }

  // As Finamp's artist screen (`artist_screen_content.dart`), in the current library.
  static Future<List<BaseItemDto>> _artistAlbums(BaseItemDto artist) =>
      _readOnce(getArtistAlbumsProvider(artist: artist, libraryFilter: currentLibraryPlaceholder));

  static Future<List<BaseItemDto>> _appearsOnAlbums(BaseItemDto artist) async {
    final own = {for (final album in await _artistAlbums(artist)) album.id};
    final performing = await _readOnce(
      getPerformingArtistAlbumsProvider(artist: artist, libraryFilter: currentLibraryPlaceholder),
    );
    return performing.where((album) => !own.contains(album.id)).toList();
  }

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
    final children = await _readOnce(getChildrenProvider(item: playable));
    return children.whereType<FinampPlayableDto>().map((child) => child.item).toList();
  }

  static Future<Map<String, Object>> _home() async {
    final sections = await Future.wait([
      _recentlyPlayed(),
      _query(ContentType.albums, limit: _homeSectionSize, sortBy: "DateCreated", sortOrder: "Descending").then(_rows),
    ]);
    return {'recent': sections[0], 'newAlbums': sections[1], 'actions': _quickActions()};
  }

  static final Map<String, Object> _lastPushedValues = {};

  static void _pushIfChanged(String key, Object value) {
    if (const DeepCollectionEquality().equals(_lastPushedValues[key], value)) return;
    _lastPushedValues[key] = value;
    unawaited(
      _watchChannel.invokeMethod(key, value).catchError((Object error) {
        // Forget it so the next push tries again
        if (identical(_lastPushedValues[key], value)) _lastPushedValues.remove(key);
        _logger.warning("Couldn't push the $key to the watch: $error");
      }),
    );
  }

  // Server IDs survive local/public address changes.
  static String _account() {
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    return user == null ? "" : "${user.id}@${user.serverId}";
  }

  // Finamp's colour scheme for each theme, exactly as its app theme builds it (getColorScheme), as ARGB, so the watch
  // can use the same Material pairs Finamp's screens do. The watch draws with the dark one and tints switches with
  // the light one's primary.
  static Map<String, Object> _accent() {
    final settings = FinampSettingsHelper.finampSettings;
    final seed = settings.useSystemAccentColor ? settings.systemAccentColor : settings.accentColor;
    Map<String, int> colors(ui.Brightness brightness) {
      final scheme = getColorScheme(seed, brightness, settings.amoledTheme);
      return {
        'primary': scheme.primary.toARGB32(),
        'onPrimary': scheme.onPrimary.toARGB32(),
        'surface': scheme.surface.toARGB32(),
        'onSurface': scheme.onSurface.toARGB32(),
        'onSurfaceVariant': scheme.onSurfaceVariant.toARGB32(),
      };
    }

    return {'light': colors(ui.Brightness.light), 'dark': colors(ui.Brightness.dark)};
  }

  static const _watchQuickActions = {
    FinampQuickActions.shuffleTracks,
    FinampQuickActions.playRandomItem,
    FinampQuickActions.playRandomFavoriteItem,
    FinampQuickActions.playPreviousQueue,
    FinampQuickActions.surpriseMe,
  };

  static List<Map<String, Object>> _quickActions() {
    final actions = FinampSettingsHelper.finampSettings.homeScreenConfiguration.actions;
    return [
      for (final (index, action) in actions.indexed)
        if (_watchQuickActions.contains(action.action))
          {'index': index, 'title': action.getTitle(GlobalSnackbar.requireL10n), 'action': action.action.name},
    ];
  }

  static Future<void> _runQuickAction(int index, String? name) async {
    final actions = FinampSettingsHelper.finampSettings.homeScreenConfiguration.actions;
    final context = GlobalSnackbar.rawMaterialAppNavigatorKey.currentContext;
    if (index < 0 || index >= actions.length || !_watchQuickActions.contains(actions[index].action)) {
      throw PlatformException(code: "changed", message: "Quick actions changed on your iPhone");
    }
    // Reject stale index if actions were reordered.
    if (name != null && actions[index].action.name != name) {
      throw PlatformException(code: "changed", message: "Quick actions changed on your iPhone");
    }
    if (context == null) {
      throw PlatformException(code: "unavailable", message: "Open Finamp on your iPhone for this action");
    }
    await QuickActionsService.handleAction(actions[index], context);
  }

  // Use queue history so items appear before Jellyfin marks them played.
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
      // Skip items with no downloaded tracks when offline.
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

  // Each kind under its own heading, as Finamp's tabs: album artists, then artists credited only on tracks (Finamp's
  // Performing Artists tab, without the album artists already listed).
  static Future<Map<String, Object>> _search(String query) async {
    final results = await Future.wait([
      _searchFind(ContentType.albums, query),
      _searchFind(ContentType.playlists, query),
    ]);
    final artists = await _searchArtists(query);
    final tracks = await _searchTracks(query, [...artists.album, ...artists.performing]);
    return {
      'artists': _rows(artists.album),
      'performingArtists': _rows(artists.performing),
      'albums': _rows(results[0]),
      'playlists': _rows(results[1]),
      'tracks': _rows(tracks),
    };
  }

  static Future<List<BaseItemDto>> _searchFind(
    ContentType contentType,
    String query, {
    int limit = _searchSectionSize,
  }) => _query(contentType, limit: limit, searchTerm: query, sortBy: "SortName");

  // The album artists the search finds, and the artists credited only on tracks (Finamp's Performing Artists tab,
  // without the album artists already found).
  static Future<({List<BaseItemDto> album, List<BaseItemDto> performing})> _searchArtists(String query) async {
    final found = await Future.wait([
      _searchFind(ContentType.albumArtists, query),
      _searchFind(ContentType.performingArtists, query, limit: _searchSectionSize * 2),
    ]);
    final albumArtists = found[0].map((artist) => artist.id).toSet();
    final performing = found[1].where((artist) => !albumArtists.contains(artist.id)).take(_searchSectionSize).toList();
    return (album: found[0], performing: performing);
  }

  // Tracks whose name matches, then the found artists' tracks as Finamp plays an artist (their albums' tracks and the
  // tracks they're credited on), once each. The watch plays the same list (`play` with `search`).
  static Future<List<BaseItemDto>> _searchTracks(String query, List<BaseItemDto> artists) async {
    final named = await _searchFind(ContentType.tracks, query);
    final byArtist = await Future.wait(
      artists.map(
        (artist) => _readOnce(getArtistTracksProvider(artist: artist, libraryFilter: currentLibraryPlaceholder)),
      ),
    );
    final seen = <BaseItemId>{};
    return [
      ...named,
      ...byArtist.expand((tracks) => tracks),
    ].where((track) => seen.add(track.id)).take(_searchSectionSize).toList();
  }

  static Future<List<BaseItemDto>> _favorites(ContentType contentType, {int offset = 0, int limit = _favoritesLimit}) =>
      _query(contentType, offset: offset, limit: limit, isFavorite: true, sortBy: "SortName");

  // WatchConnectivity requires non-null property-list values.
  static List<Map<String, Object>> _rows(List<BaseItemDto> items) {
    for (final item in items) {
      _rememberSent(item);
    }
    return items
        .map(
          (item) => {
            'id': item.id.raw,
            'name': item.name ?? "",
            'subtitle': _subtitle(item),
            'artistId': _mainArtist(item)?.id.raw ?? "",
            'artworkKey': _artworkKey(item),
            'blurHash': item.blurHash ?? "",
            'duration': (item.runTimeTicksDuration() ?? Duration.zero).inMilliseconds / 1000,
            'year': item.productionYear ?? 0,
            'releaseDate': ReleaseDateHelper.autoFormat(item) ?? "",
            'trackCount': item.childCount ?? 0,
            'favorite': item.userData?.isFavorite ?? false,
            ..._downloadState(item),
            'kind': _kind(item),
            if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.album) 'artists': _artists(item.albumArtists),
          },
        )
        .toList();
  }

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
      // Finamp's own offline list with its search and favourite filters: every download, and favourites from its
      // offline favourites index (an item's own flag is unreliable offline).
      return await _tabPage(contentType, offset, limit, search: searchTerm, favorites: isFavorite ?? false);
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
          // As Finamp's music screen: each artist tab asks for its own artist type.
          artistType: switch (contentType) {
            ContentType.albumArtists => ArtistType.albumArtist,
            ContentType.performingArtists => ArtistType.artist,
            _ => contentType.isArtist ? settings.defaultArtistType : null,
          },
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

  static List<Map<String, String>> _artists(List<NameIdPair>? artists) =>
      (artists ?? const []).map((artist) => {'id': artist.id.raw, 'name': artist.name ?? ""}).toList();

  static NameIdPair? _mainArtist(BaseItemDto item) => BaseItemDtoType.fromItem(item) == BaseItemDtoType.album
      ? item.albumArtists?.firstOrNull
      : item.artistItems?.firstOrNull;

  // The player's feature chips as FeatureState.features builds them, in the user's configured order.
  static List<String> _features(FinampQueueItem current) {
    final settings = FinampSettingsHelper.finampSettings;
    final configuration = settings.featureChipsConfiguration;
    if (!configuration.enabled) return const [];
    final l10n = GlobalSnackbar.requireL10n;
    final metadata = GetIt.instance<ProviderContainer>().read(currentTrackMetadataProvider).valueOrNull;
    final item = current.baseItem;
    final isDownloaded = metadata?.isDownloaded ?? false;
    final transcoding = !isDownloaded && (current.item.extras?["shouldTranscode"] as bool? ?? false);
    final format = settings.transcodingStreamingFormat;
    final MediaStream? audioStream =
        metadata?.mediaSourceInfo.mediaStreams.firstWhereOrNull((stream) => stream.type == "Audio") ??
        metadata?.mediaSourceInfo.mediaStreams.firstOrNull;
    final codec = transcoding ? format.codec : audioStream?.codec ?? l10n.unknown;
    final bitrate = transcoding
        ? (format == FinampTranscodingStreamingFormat.flacFragmentedMp4 ? null : settings.transcodeBitrate)
        : audioStream?.bitRate ?? metadata?.mediaSourceInfo.bitrate;
    final sampleRate = transcoding ? format.sampleRate : audioStream?.sampleRate;
    final bitDepth = transcoding
        ? (format.lossless ? metadata?.mediaSourceInfo.mediaStreams.firstOrNull?.bitDepth : null)
        : audioStream?.bitDepth;
    final size = transcoding ? null : metadata?.mediaSourceInfo.size;
    final enabled = configuration.features;
    final speed = GetIt.instance<QueueService>().playbackSpeed;

    var codecAdded = false;
    final features = <String>[
      if (speed != 1.0) l10n.playbackSpeedFeatureText(speed),
      if (settings.currentVolume != 1.0) l10n.currentVolumeFeatureText((settings.currentVolume * 100).floor()),
    ];
    for (final feature in enabled) {
      if (feature == FinampFeatureChipType.explicit && item.isExplicit) features.add("E");
      final playCount = item.userData?.playCount;
      if (feature == FinampFeatureChipType.playCount && playCount != null) features.add(l10n.playCountValue(playCount));
      if (feature == FinampFeatureChipType.additionalPeople) {
        for (final person in metadata?.people ?? item.people ?? const <BaseItemPerson>[]) {
          final role = (person.role?.isNotEmpty ?? false) ? person.role : person.type;
          if (role?.isNotEmpty ?? false) features.add("$role: ${person.name}");
        }
      }
      if (feature == FinampFeatureChipType.playbackMode) {
        features.add(
          isDownloaded
              ? l10n.playbackModeLocal
              : (transcoding ? l10n.playbackModeTranscoding : l10n.playbackModeDirectPlaying),
        );
      }
      if (metadata == null) continue;
      // One chip for both settings, added at whichever comes first
      if ((feature == FinampFeatureChipType.codec || feature == FinampFeatureChipType.bitRate) && !codecAdded) {
        codecAdded = true;
        final showCodec = enabled.contains(FinampFeatureChipType.codec);
        final showBitrate = enabled.contains(FinampFeatureChipType.bitRate) && bitrate != null;
        features.add(
          "${showCodec ? codec.toUpperCase() : ""}${showCodec && showBitrate ? " @ " : ""}"
          "${showBitrate ? l10n.kiloBitsPerSecondLabel(bitrate ~/ 1000) : ""}",
        );
      }
      if (feature == FinampFeatureChipType.bitDepth && bitDepth != null) features.add(l10n.numberAsBit(bitDepth));
      if (feature == FinampFeatureChipType.sampleRate && sampleRate != null) {
        features.add(l10n.numberAsKiloHertz(sampleRate / 1000.0));
      }
      if (feature == FinampFeatureChipType.size && size != null) features.add(FileSize.getSize(size));
      if (feature == FinampFeatureChipType.normalizationGain && settings.volumeNormalizationActive) {
        final gain = getGainForCurrentPlayback(current.item, item);
        if (gain != null) features.add(l10n.numberAsDecibel(double.parse(gain.toStringAsFixed(1))));
      }
    }
    return features;
  }

  // The watch's short chips, in the order the user set Finamp's chips (feature_chips.dart walks
  // `configuration.features` the same way): explicit, play count, how it plays (`local`, `transcoding` or `direct`),
  // and codec with bitrate as one chip where the first of the two is.
  static List<Map<String, Object>> _shortFeatures(FinampQueueItem current) {
    final settings = FinampSettingsHelper.finampSettings;
    final configuration = settings.featureChipsConfiguration;
    if (!configuration.enabled) return const [];
    final enabled = configuration.features;
    final metadata = GetIt.instance<ProviderContainer>().read(currentTrackMetadataProvider).valueOrNull;
    final isDownloaded = metadata?.isDownloaded ?? false;
    final transcoding = !isDownloaded && (current.item.extras?["shouldTranscode"] as bool? ?? false);
    final format = settings.transcodingStreamingFormat;
    final MediaStream? audioStream =
        metadata?.mediaSourceInfo.mediaStreams.firstWhereOrNull((stream) => stream.type == "Audio") ??
        metadata?.mediaSourceInfo.mediaStreams.firstOrNull;
    final codec = transcoding ? format.codec : audioStream?.codec;
    final bitrate = transcoding
        ? (format == FinampTranscodingStreamingFormat.flacFragmentedMp4 ? null : settings.transcodeBitrate)
        : audioStream?.bitRate ?? metadata?.mediaSourceInfo.bitrate;
    final playCount = current.baseItem.userData?.playCount;
    final chips = <Map<String, Object>>[];
    for (final feature in enabled) {
      switch (feature) {
        case FinampFeatureChipType.explicit when current.baseItem.isExplicit:
          chips.add({'type': 'explicit'});
        case FinampFeatureChipType.playCount when playCount != null:
          chips.add({'type': 'plays', 'text': GlobalSnackbar.requireL10n.playCountValue(playCount)});
        case FinampFeatureChipType.playbackMode:
          chips.add({'type': 'mode', 'mode': isDownloaded ? 'local' : (transcoding ? 'transcoding' : 'direct')});
        case FinampFeatureChipType.codec || FinampFeatureChipType.bitRate
            when metadata != null && !chips.any((chip) => chip['type'] == 'format'):
          final showCodec = enabled.contains(FinampFeatureChipType.codec) && codec != null;
          final showBitrate = enabled.contains(FinampFeatureChipType.bitRate) && bitrate != null;
          if (showCodec || showBitrate) {
            chips.add({
              'type': 'format',
              if (showCodec) 'codec': codec.toUpperCase(),
              if (showBitrate) 'kbps': bitrate ~/ 1000,
            });
          }
        default:
          break;
      }
    }
    return chips;
  }

  static Future<Map<String, Object>> _output() async {
    return {...await _outputRoute(), 'volume': FinampSettingsHelper.finampSettings.currentVolume};
  }

  static Future<Map<String, Object>> _outputRoute() async {
    final outputs = (await AVAudioSession().currentRoute).outputs;
    return {
      'route': outputs.map((port) => port.portName).join(" + "),
      'routeType': outputs.firstOrNull?.portType.name ?? "",
    };
  }

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

  // Whether item is required as its own download.
  static bool _isDownloaded(BaseItemDto item) {
    final stub = _downloadStub(item);
    return stub != null && GetIt.instance<DownloadsService>().getStatus(stub, null).isRequired;
  }

  // null means unlocked; empty means the requiring item is unknown.
  static String? _downloadLock(BaseItemDto item) {
    final stub = _downloadStub(item);
    if (stub == null) return null;
    final downloads = GetIt.instance<DownloadsService>();
    final status = downloads.getStatus(stub, null);
    if (status == DownloadItemStatus.notNeeded || status.isRequired) return null;
    final parent = downloads.getFirstRequiringItem(stub);
    if (parent == null) return "";
    final parentItem = parent.finampCollection?.item;
    final parentType = parentItem != null ? BaseItemDtoType.fromItem(parentItem) : parent.baseItemType;
    final l10n = GlobalSnackbar.requireL10n;
    return l10n.incidentalDownloadTooltip(l10n.itemTypeSubtitle(parentType.name, parent.name));
  }

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

  static Future<bool> _setFavorite(String id, bool favorite) async {
    final item = await _itemById(id);
    // Inform watch if offline; Finamp refuses favourite changes offline.
    if (FinampSettingsHelper.finampSettings.isOffline) {
      throw PlatformException(code: "offline", message: GlobalSnackbar.requireL10n.notAvailableInOfflineMode);
    }
    final result = GetIt.instance<ProviderContainer>().read(isFavoriteProvider(item).notifier).updateFavorite(favorite);
    _followFavorite(item);
    return result;
  }

  // Finamp's playlist menu for one track (`playlist_actions_menu.dart`): its heart, and every playlist sorted by name.
  // As there, only the playlist the track is playing from is known to hold it (it comes first); the others aren't
  // looked up, and adding to one is what shows it holds the track.
  static Future<Map<String, Object>> _playlistMenu(String id) async {
    final item = await _itemById(id);
    if (FinampSettingsHelper.finampSettings.isOffline) {
      throw PlatformException(code: "offline", message: GlobalSnackbar.requireL10n.notAvailableInOfflineMode);
    }
    final playlists =
        await GetIt.instance<JellyfinApiHelper>().getItems(includeItemTypes: "Playlist", sortBy: "SortName") ?? [];
    final current = GetIt.instance<QueueService>().getCurrentTrack();
    final source = current?.baseItem.id == item.id && queueItemInPlaylist(current) ? current!.source.id : null;
    final rows = [
      for (final row in _rows(playlists)) {...row, 'included': row['id'] == source},
    ];
    return {
      'favorite': GetIt.instance<ProviderContainer>().read(isFavoriteProvider(item)),
      'color': await _menuColor(item),
      'playlists': [...rows.where((row) => row['included'] == true), ...rows.where((row) => row['included'] != true)],
    };
  }

  // Adds the track to a playlist or takes it out, with Finamp's own functions (`queue_source_helper.dart`): they also
  // re-sync the playlist's download and confirm on the phone. Answers whether the playlist now holds the track.
  static Future<bool> _playlistToggle(String id, String playlistId, bool add) async {
    if (FinampSettingsHelper.finampSettings.isOffline) {
      throw PlatformException(code: "offline", message: GlobalSnackbar.requireL10n.notAvailableInOfflineMode);
    }
    final item = await _itemById(id);
    final playlist = await _itemById(playlistId);
    String? entry;
    if (!add) {
      final entries = await GetIt.instance<JellyfinApiHelper>().getItems(parentItem: playlist, fields: "");
      entry = entries?.firstWhereOrNull((track) => track.id == item.id)?.playlistItemId;
      if (entry == null) return false;
    }
    final context = GlobalSnackbar.rawMaterialAppNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      throw PlatformException(code: "unavailable", message: "Open Finamp on your iPhone for this action");
    }
    final holds = add
        ? await addItemsToPlaylist(context, [item], playlist)
        : !await removeFromPlaylist(context, item, playlist, entry!, confirm: false);
    // The playlist's tracks are read again, as Finamp's playlist editor does after a change.
    GetIt.instance<ProviderContainer>().invalidate(getAlbumOrPlaylistTracksProvider(playlist));
    if (_childrenCache?.$1 == "playlists:$playlistId") _childrenCache = null;
    return holds;
  }

  // Finamp sets a heart before the server answers and puts it back if the server refuses; following Finamp's state for
  // the items the watch changed carries that (and later changes on the phone) to the watch's hearts.
  static final Map<BaseItemId, ProviderSubscription<bool>> _followedFavorites = {};
  static const _followedFavoritesLimit = 20;

  static void _followFavorite(BaseItemDto item) {
    _followedFavorites.remove(item.id)?.close();
    if (_followedFavorites.length >= _followedFavoritesLimit) {
      _followedFavorites.remove(_followedFavorites.keys.first)?.close();
    }
    _followedFavorites[item.id] = GetIt.instance<ProviderContainer>().listen(
      isFavoriteProvider(item),
      (_, _) => _pushFavoriteStates(),
    );
    _pushFavoriteStates();
  }

  static void _pushFavoriteStates() => _pushIfChanged('favoriteStates', {
    for (final entry in _followedFavorites.entries) entry.key.raw: entry.value.read(),
  });

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

    // Limit warnings across all of an artist's albums.
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

  // Finamp's delete button for a download (askBeforeDeleteDownloadFromDevice): the watch asks first, then this
  // deletes it from the phone and answers with Finamp's own message.
  static Future<Map<String, Object>> _deleteDownload(String id) async {
    final item = await _itemById(id);
    final stub = _downloadStub(item);
    if (stub == null) {
      throw PlatformException(code: "unknown", message: "Unknown item");
    }
    if (!_isDownloaded(item)) return {'status': 'notDownloaded'};
    await GetIt.instance<DownloadsService>().deleteDownload(stub: stub);
    return {
      'status': 'deleted',
      'message': GlobalSnackbar.requireL10n.itemDeletedSnackbar("device", stub.baseItemType.name),
    };
  }

  // Image ID and tag for cache validation.
  static String _artworkKey(BaseItemDto item) {
    final imageId = item.imageId;
    if (imageId == null) {
      // Coverless playlists use their first track's album cover.
      return BaseItemDtoType.fromItem(item) == BaseItemDtoType.playlist ? "first-${item.id.raw}" : "";
    }
    final tag = item.hasOwnImage
        ? item.imageTags!["Primary"]
        : (item.parentPrimaryImageItemId != null ? item.parentPrimaryImageTag : item.albumPrimaryImageTag);
    return "$imageId-${tag ?? ""}";
  }

  // Start at startId within the collection, favourites or search results.
  static Future<void> _play(Map<String, dynamic> arguments) async {
    switch (arguments['type']) {
      case 'favorites':
        await _playTrackList(
          await _trackWindow(
            arguments,
            (offset, limit) => _favorites(ContentType.tracks, offset: offset, limit: limit),
          ),
          arguments,
          QueueItemSource.rawId(
            type: QueueItemSourceType.favorites,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.yourLikes),
            id: "favorites",
          ),
        );
        return;
      case 'search':
        final query = arguments['query'] as String;
        await _playTrackList(
          await _searchArtists(
            query,
          ).then((artists) => _searchTracks(query, [...artists.album, ...artists.performing])),
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
    // Reuse cached list if available to save server round trip.
    final cached = _childrenCache;
    final tracks = cached != null && cached.$1 == "${arguments['type']}:$parentId"
        ? cached.$2
        : await _children(parent);
    await _playTrackList(tracks, arguments, QueueItemSource.fromBaseItem(parent));
  }

  // Artist playback slices including album shuffle.
  static Future<void> _playArtist(Map<String, dynamic> arguments) async {
    final artist = Artist<Track>.fromItem(await _itemById(arguments['parentId'] as String));
    final PlayableSlice slice;
    if (arguments['albumShuffle'] == true) {
      slice = await _readOnce(getAlbumShuffledPlayerSliceProvider(item: artist));
    } else {
      final linear = await _readOnce(getPlayableSliceProvider(item: artist, startingOffset: 0));
      slice = (arguments['shuffle'] as bool? ?? false) ? linear.shuffle() : linear;
    }
    // Finamp's queue skips an empty slice without an error (offline, an artist with nothing downloaded), so the watch
    // would hear "ok" while nothing plays. A pre-cached slice always holds its first tracks.
    final playable = slice is PreCachedPlayableSlice ? slice : await slice.resolve();
    if (playable is BasePlayableSlice && playable.items.isEmpty) {
      throw PlatformException(code: "empty", message: "Nothing to play");
    }
    await GetIt.instance<QueueService>().startSlicePlayback(playable);
  }

  static Future<Map<String, Object>> _artistInfo(String id) async {
    final item = await _itemById(id);
    final artist = Artist<Track>.fromItem(item);
    final tracks = await _readOnce(getChildTracksProvider(item: artist));
    final albums = await _artistAlbums(item);
    return {
      'tracks': tracks.length,
      // As Finamp's artist header: the albums where they're the album artist.
      'albums': albums.length,
      // The order of the artist page's album sections, from Finamp's artist screen setting.
      'sections': [
        for (final section in FinampSettingsHelper.finampSettings.artistItemSectionsOrder)
          if (section != ArtistItemSections.tracks) section.name,
      ],
      'favorite': GetIt.instance<ProviderContainer>().read(isFavoriteProvider(item)),
      ..._downloadState(item),
    };
  }

  // The list row's download state may be stale.
  static Map<String, Object> _downloadState(BaseItemDto item) => {
    'downloaded': _isDownloaded(item),
    'downloadLock': ?_downloadLock(item),
  };

  // Resolve sent items or query cached lookup.
  static Future<BaseItemDto> _itemById(String id) async {
    if (!_jellyfinId.hasMatch(id)) throw PlatformException(code: "invalid", message: "Invalid item id");
    final known = _sentItems[BaseItemId(id)];
    if (known != null) {
      _rememberSent(known);
      return known;
    }
    final item = await _readOnce(itemByIdProvider(BaseItemId(id)));
    if (item == null) throw PlatformException(code: "unknown", message: "Unknown item");
    _rememberSent(item);
    return item;
  }

  // Keep auto-disposed providers alive until their value arrives.
  // Reads one of Finamp's providers once. While one of Finamp's own screens listens to the same provider, it keeps its
  // last result, a failed load included, and a read would get that error at once without a new request (seen:
  // Artists stayed "Can't reach your Jellyfin server" after a single timeout, while the phone's Artists tab held the
  // error). A provider held in a failed state is started again first, as Finamp's own pull-to-refresh does.
  // `dependsOn`: providers the read depends on that can hold a failure the same way (the library lookup behind every
  // library list, which Finamp's own Retry doesn't clear either).
  static Future<T> _readOnce<T>(
    AutoDisposeFutureProvider<T> provider, {
    List<AutoDisposeFutureProvider<Object?>> dependsOn = const [],
  }) async {
    final container = GetIt.instance<ProviderContainer>();
    for (final held in [...dependsOn, provider]) {
      if (container.exists(held) && container.read(held).hasError) {
        _logger.info("Watch request: a failed load held by Finamp is started again");
        container.invalidate(held);
      }
    }
    final subscription = container.listen(provider.future, (_, _) {});
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }

  // Load the queue the same way as the watch's list, so the tapped track is where the watch showed it
  // The tapped track (`index`, `startId`) with a few before it, so Previous works, and Finamp's track shuffle count
  // after it, like Finamp's own Tracks screen, instead of the whole list.
  static Future<List<BaseItemDto>> _trackWindow(
    Map<String, dynamic> arguments,
    Future<List<BaseItemDto>> Function(int offset, int limit) page,
  ) async {
    final index = arguments['index'] as int? ?? 0;
    final start = max(0, index - 20);
    var tracks = await page(start, index - start + FinampSettingsHelper.finampSettings.trackShuffleItemCount);
    final startId = arguments['startId'] as String?;
    // A changing list (e.g. a random sort) can move it out of this window: still start with the tapped track
    if (startId != null && !tracks.any((track) => track.id.raw == startId)) {
      tracks = [await _itemById(startId), ...tracks];
    }
    return tracks;
  }

  static Future<void> _playTracksPage(Map<String, dynamic> arguments) async {
    await _playTrackList(
      await _trackWindow(arguments, (offset, limit) => _tabPage(ContentType.tracks, offset, limit)),
      arguments,
      QueueItemSource.rawId(
        type: QueueItemSourceType.allTracks,
        name: const QueueItemSourceName(type: QueueItemSourceNameType.musicScreenTracks),
        id: "allTracks",
      ),
    );
  }

  static Future<void> _playTrackList(
    List<BaseItemDto> tracks,
    Map<String, dynamic> arguments,
    QueueItemSource source,
  ) async {
    if (tracks.isEmpty) throw PlatformException(code: "empty", message: "Nothing to play");
    final startId = arguments['startId'] as String?;
    final startingIndex = tracks.indexWhere((track) => track.id.raw == startId);
    // Never start another track in its place (e.g. a favourite past the queue limit)
    if (startId != null && startingIndex < 0) {
      throw PlatformException(code: "changed", message: "Couldn't find that track on your iPhone");
    }
    await GetIt.instance<QueueService>().startPlayback(
      items: tracks,
      source: source,
      order: (arguments['shuffle'] as bool? ?? false) ? FinampPlaybackOrder.shuffled : FinampPlaybackOrder.linear,
      startingIndex: startingIndex < 0 ? null : startingIndex,
    );
  }

  // Batch results stay in request order so iOS can pair them with IDs and sizes. The answer goes once every cover is
  // settled, or after `_watchCoverAnswerAfter` with the ones settled by then: the others are marked `later`, which the
  // watch asks for again, joining the fetch still running here (`_coversInFlight`). So a ready cover never waits for a
  // slow one.
  static Future<List<Map<String, Object>>> _artworks(Map<String, dynamic> arguments) async {
    final requests = (arguments['items'] as List).take(20).map((request) => Map<String, dynamic>.from(request as Map));
    final ids = [for (final request in requests) request['id'] as String];
    final sizes = [
      for (final request in requests) (request['size'] as int? ?? _defaultWatchArtworkSize).clamp(16, 1200),
    ];
    final settled = List<Map<String, Object>?>.filled(ids.length, null);
    final all = Future.wait([
      for (var i = 0; i < ids.length; i++)
        _coverJoined(ids[i], sizes[i]).then((cover) => settled[i] = {'id': ids[i], 'data': ?cover}),
    ]);
    await Future.any([all, Future<void>.delayed(_watchCoverAnswerAfter)]);
    return [
      for (var i = 0; i < ids.length; i++) settled[i] ?? {'id': ids[i], 'later': true},
    ];
  }

  // Covers being fetched, by "<id>-<size>", so the watch asking again joins the fetch; kept briefly after it ends so
  // that a cover finished between two answers is ready for the next one.
  static final Map<String, Future<Uint8List?>> _coversInFlight = {};

  static Future<Uint8List?> _coverJoined(String id, int size) {
    final key = "$id-$size";
    final running = _coversInFlight[key];
    if (running != null) return running;
    final cover = _coverWithinLimit(id, size);
    _coversInFlight[key] = cover;
    cover.whenComplete(
      () => Future<void>.delayed(const Duration(seconds: 30), () {
        if (_coversInFlight[key] == cover) _coversInFlight.remove(key);
      }),
    );
    return cover;
  }

  static Future<Uint8List?> _coverWithinLimit(String id, int size) async {
    try {
      return await _artwork(id, size).timeout(_watchCoverLimit);
    } on TimeoutException {
      _logger.warning(
        "Watch artwork for $id: nothing after ${_watchCoverLimit.inSeconds} s "
        "(app ${WidgetsBinding.instance.lifecycleState?.name ?? "unknown"})",
      );
    } catch (e) {
      _logger.warning("Watch artwork for $id: failed", e);
    }
    return null;
  }

  // How many favourite tracks there are, counted as Finamp's Random Favorite counts them (`audio_service_helper.dart`):
  // Jellyfin's total online (one item asked for), the downloaded favourites offline.
  static Future<int> _favoritesCount() async {
    final type = ContentType.tracks.itemType!;
    if (FinampSettingsHelper.finampSettings.isOffline) {
      return GetIt.instance<DownloadsService>().getFavoritesCount(baseItemType: type) ?? 0;
    }
    final view = GetIt.instance<FinampUserHelper>().currentUser?.currentView;
    final result = await GetIt.instance<JellyfinApiHelper>().getItemsWithTotalRecordCount(
      parentItem: view,
      libraryFilter: view?.id,
      includeItemTypes: type.jellyfinName,
      filters: "IsFavorite",
      limit: 1,
    );
    return result.totalRecordCount;
  }

  // Each cover gets at most `_watchCoverLimit`; an answer waits at most `_watchCoverAnswerAfter` for the covers in it.
  // Both well under the watch's wait for the answer (30 s, `ConnectionPolicy.Reply.normal` in
  // `ios/FinampWatch Watch App/ConnectionPolicy.swift`).
  static const _watchCoverLimit = Duration(seconds: 10);
  static const _watchCoverAnswerAfter = Duration(seconds: 2);

  // Cache playlist covers to avoid repeated lookups for first track.
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

  // A cover's file as it is (JPEG/PNG bytes; `WatchBridge.swift` scales it to the watch's size); null when unavailable.
  // Never decoded here: Flutter's image decoding stalls with Finamp in the background, and stalled even in the
  // foreground while the server hung, so the watch got nothing for 25 s.
  static Future<Uint8List?> _artwork(String id, int size) async {
    BaseItemDto? item;
    try {
      item = await _itemById(id);
    } catch (e) {
      _logger.warning("Watch artwork for $id: item lookup failed", e);
      return null;
    }
    if (item.imageId == null && BaseItemDtoType.fromItem(item) == BaseItemDtoType.playlist) {
      try {
        item = await _firstTrack(item);
      } catch (e) {
        _logger.warning("Watch artwork for $id: playlist's first track lookup failed", e);
        return null;
      }
    }
    if (item == null || item.imageId == null) return null;

    // 1. The downloaded cover.
    final file = GetIt.instance<DownloadsService>().getImageDownload(item: item)?.file;
    if (file != null && await file.exists()) {
      _logger.fine("Watch artwork for $id: the downloaded file");
      return await file.readAsBytes();
    }

    // 2. The copy Finamp's player saved, full size, under the key `album_image_provider.dart` gives it (BlurHash, or
    // image ID, plus the size, which is "null" for full size). Needs no server, so it also works with no connection.
    final saved = await DefaultCacheManager().getFileFromCache("${item.blurHash ?? item.imageId}nullnull");
    if (saved != null && await saved.file.exists()) {
      _logger.fine("Watch artwork for $id: the player's saved copy");
      return await saved.file.readAsBytes();
    }

    // 3. The watch's size from the server, unless Finamp is offline.
    if (FinampSettingsHelper.finampSettings.isOffline) {
      _logger.fine("Watch artwork for $id: none saved for Offline Mode");
      return null;
    }
    final url = GetIt.instance<JellyfinApiHelper>().getImageUrl(item: item, maxWidth: size, maxHeight: size);
    if (url == null) return null;
    final response = await http.get(url);
    if (response.statusCode != 200) {
      _logger.warning("Watch artwork for $id: server answered ${response.statusCode}");
      return null;
    }
    _logger.fine("Watch artwork for $id: from the server");
    return response.bodyBytes;
  }
}
