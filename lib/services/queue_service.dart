import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/gen/assets.gen.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart' as jellyfin_models;
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/playback_history_service.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

/// A track queueing service for Finamp.
class QueueService {
  static const savedQueueSource = QueueItemSource.rawId(
    type: QueueItemSourceType.unknown,
    name: QueueItemSourceName(type: QueueItemSourceNameType.savedQueue),
    id: "savedqueue",
  );

  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  final _downloadsService = GetIt.instance<DownloadsService>();
  final _queueServiceLogger = Logger("QueueService");
  final _queuesBox = Hive.box<FinampStorableQueueInfo>("Queues");
  final _providers = GetIt.instance<ProviderContainer>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  // internal state

  final List<FinampQueueItem> _queuePreviousTracks =
      []; // contains **all** items that have been played, including "next up"
  FinampQueueItem? _currentTrack; // the currently playing track
  final List<FinampQueueItem> _queueNextUp = []; // a temporary queue that gets appended to if the user taps "next up"
  final List<FinampQueueItem> _queue = []; // contains all regular queue items
  // The latest shuffle indices.  This is only updated by _buildQueueFromNativePlayerQueue to ensure
  // it is always in sync with the queued track lists
  List<int> _latestShuffleIndices = [];
  FinampQueueOrder _order = FinampQueueOrder(
    items: [],
    originalSource: QueueItemSource.rawId(
      id: "",
      name: const QueueItemSourceName(type: QueueItemSourceNameType.preTranslated),
      type: QueueItemSourceType.unknown,
    ),
    linearOrder: [],
    shuffledOrder: [],
    sourceLibrary: null,
  ); // contains all items that were at some point added to the regular queue, as well as their order when shuffle is enabled and disabled. This is used to loop the original queue once the end has been reached and "loop all" is enabled, **excluding** "next up" items and keeping the playback order.

  FinampPlaybackOrder _playbackOrder = FinampPlaybackOrder.linear;
  FinampLoopMode _loopMode = FinampLoopMode.none;
  double _playbackSpeed = 1.0;
  double _playbackPitch = 1.0;

  final _currentTrackStream = BehaviorSubject<FinampQueueItem?>.seeded(null);
  final _queueStream = BehaviorSubject<FinampQueueInfo?>.seeded(null);

  final _playbackOrderStream = BehaviorSubject<FinampPlaybackOrder>.seeded(FinampPlaybackOrder.linear);
  final _loopModeStream = BehaviorSubject<FinampLoopMode>.seeded(FinampLoopMode.none);
  final _playbackSpeedStream = BehaviorSubject<double>.seeded(1.0);
  final _playbackPitchStream = BehaviorSubject<double>.seeded(1.0);

  // external queue state

  late final NextUpShuffleOrder _shuffleOrder;
  int _currentQueueIndex = 0;
  int? _activeInitialIndex;

  // Flags for saving and loading saved queues
  int _saveUpdateCycleCount = 0;
  bool _saveUpdateImmediate = false;
  SavedQueueState _savedQueueState = SavedQueueState.preInit;
  FinampStorableQueueInfo? _failedSavedQueue;
  static const int _maxSavedQueues = 60;

  static int get maxInitialQueueItems => Platform.isIOS || Platform.isMacOS
      ? 1000
      : Platform.isAndroid
      ? 1000
      : 1000;

  static int get maxQueueItems => Platform.isIOS || Platform.isMacOS ? 1500 : 5000;

  QueueService() {
    // _queueServiceLogger.level = Level.OFF;

    final finampSettings = FinampSettingsHelper.finampSettings;

    loopMode = finampSettings.loopMode;
    _queueServiceLogger.info("Restored loop mode to $loopMode from settings");

    playbackSpeed = finampSettings.playbackSpeed;
    _queueServiceLogger.info("Restored playback speed to $playbackSpeed from settings");

    _shuffleOrder = NextUpShuffleOrder(queueService: this);

    _audioHandler.playbackState.listen((event) async {
      // int indexDifference = (event.currentIndex ?? 0) - _queueAudioSourceIndex;

      final previousIndex = _currentQueueIndex;
      _currentQueueIndex = event.queueIndex ?? 0;

      // Ignore playback events if queue is empty.
      if (previousIndex != _currentQueueIndex && _currentTrack != null) {
        _queueServiceLogger.finer("Play queue index changed, new index: $_currentQueueIndex");
        _buildQueueFromNativePlayerQueue();
      } else {
        _saveUpdateImmediate = true;
      }
    });

    Stream<void>.periodic(const Duration(seconds: 10)).listen((event) {
      // Update once per minute while playing in background, and up to once every ten seconds if
      // pausing/seeking is occurring
      // We also update on every track switch.
      if ((_saveUpdateCycleCount >= 5 && !_audioHandler.paused) || _saveUpdateImmediate) {
        if (_savedQueueState == SavedQueueState.pendingSave && !_audioHandler.paused) {
          _savedQueueState = SavedQueueState.saving;
        }
        if (_savedQueueState == SavedQueueState.saving) {
          _saveUpdateImmediate = false;
          _saveUpdateCycleCount = 0;
          final info = _saveCurrentQueue(withPosition: true);
          _queueServiceLogger.finest("Saved new periodic queue $info");
        }
      } else {
        _saveUpdateCycleCount++;
      }
      // just in case, check if there are radio tracks missing (due to errors, race conditions, etc.)
      unawaited(maybeAddRadioTracks());
    });

    // check if new radio tracks are needed whenever the queue changes in some way
    _queueStream.listen((_) {
      unawaited(maybeAddRadioTracks());
    });

    // Schedule for after queue service is registered
    Future.microtask(() {
      // Keep currentAlbumImageProvider alive to provide precaching
      _providers.listen(currentAlbumImageProvider, (_, _) {});

      // check if new radio tracks are needed whenever the radio mode or connectivity is changed
      _providers.listen(finampSettingsProvider.radioEnabled, (_, _) => unawaited(maybeAddRadioTracks()));
      _providers.listen(finampSettingsProvider.radioMode, (_, _) => unawaited(maybeAddRadioTracks()));
      _providers.listen(finampSettingsProvider.isOffline, (_, _) => unawaited(maybeAddRadioTracks()));
      _providers.listen(FinampUserHelper.finampCurrentUserProvider, (_, _) => unawaited(maybeAddRadioTracks()));
    });

    // register callbacks
    // _audioHandler.setQueueCallbacks(
    //   nextTrackCallback: _applyNextTrack,
    //   previousTrackCallback: _applyPreviousTrack,
    //   skipToIndexCallback: _applySkipToTrackByOffset,
    // );
  }

  ProviderSubscription<AlbumImageInfo>? _latestAlbumImage;

  void _buildQueueFromNativePlayerQueue({bool logUpdate = true, int? indexOverride}) {
    final playbackHistoryService = GetIt.instance<PlaybackHistoryService>();

    _currentQueueIndex = indexOverride ?? _audioHandler.queueIndex ?? _currentQueueIndex;
    if (_activeInitialIndex != null && _currentQueueIndex != _activeInitialIndex) {
      // We have been during the middle of a queue replacement.  Ignore to avoid stripping next up entries.
      _queueServiceLogger.warning("Ignoring call to _buildQueueFromNativePlayerQueue while in queue replacement");
      return;
    }

    List<FinampQueueItem> allTracks = _audioHandler.sequenceState.effectiveSequence
        .map((e) => e.tag as FinampQueueItem)
        .toList();
    _latestShuffleIndices = _audioHandler.sequenceState.shuffleIndices;

    _queuePreviousTracks.clear();
    _queueNextUp.clear();
    _queue.clear();

    bool canHaveNextUp = true;

    // split the queue by old type
    for (int i = 0; i < allTracks.length; i++) {
      if (i < _currentQueueIndex) {
        _queuePreviousTracks.add(allTracks[i]);
        if ([
          QueueItemSourceType.nextUp,
          QueueItemSourceType.nextUpAlbum,
          QueueItemSourceType.nextUpPlaylist,
          QueueItemSourceType.nextUpArtist,
          QueueItemSourceType.nextUpGenre,
        ].contains(_queuePreviousTracks.last.source.type)) {
          _queuePreviousTracks.last.source = QueueItemSource.rawId(
            type: QueueItemSourceType.formerNextUp,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.tracksFormerNextUp),
            id: "former-next-up",
          );
        }
        _queuePreviousTracks.last.type = QueueItemQueueType.previousTracks;
      } else if (i == _currentQueueIndex) {
        _currentTrack = allTracks[i];
        _currentTrack!.type = QueueItemQueueType.currentTrack;
      } else {
        if (allTracks[i].type == QueueItemQueueType.currentTrack &&
            [
              QueueItemSourceType.nextUp,
              QueueItemSourceType.nextUpAlbum,
              QueueItemSourceType.nextUpPlaylist,
              QueueItemSourceType.nextUpArtist,
              QueueItemSourceType.nextUpGenre,
            ].contains(allTracks[i].source.type)) {
          _queue.add(allTracks[i]);
          _queue.last.type = QueueItemQueueType.queue;
          _queue.last.source = QueueItemSource.rawId(
            type: QueueItemSourceType.formerNextUp,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.tracksFormerNextUp),
            id: "former-next-up",
          );
          canHaveNextUp = false;
        } else if (allTracks[i].type == QueueItemQueueType.nextUp) {
          if (canHaveNextUp) {
            _queueNextUp.add(allTracks[i]);
            _queueNextUp.last.type = QueueItemQueueType.nextUp;
          } else {
            _queue.add(allTracks[i]);
            _queue.last.type = QueueItemQueueType.queue;
            _queue.last.source = QueueItemSource.rawId(
              type: QueueItemSourceType.formerNextUp,
              name: const QueueItemSourceName(type: QueueItemSourceNameType.tracksFormerNextUp),
              id: "former-next-up",
            );
          }
        } else {
          _queue.add(allTracks[i]);
          _queue.last.type = QueueItemQueueType.queue;
          canHaveNextUp = false;
        }
      }
    }

    if (allTracks.isEmpty) {
      _queueServiceLogger.fine("Queue is empty");
      _currentTrack = null;
      _audioHandler.playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.idle,
          playing: false,
          queueIndex: 0,
          updatePosition: Duration.zero,
          updateTime: DateTime.now(),
          bufferedPosition: Duration.zero,
        ),
      );
    }

    refreshQueueStream();
    _currentTrackStream.add(_currentTrack);
    var currentMediaItem = _currentTrack?.item;
    if (currentMediaItem != null) {
      final item = jellyfin_models.BaseItemDto.fromJson(currentMediaItem.extras!["itemJson"] as Map<String, dynamic>);
      final artRequest = AlbumImageRequest(item: item);

      void updateMediaItem(AlbumImageInfo latest, bool force) async {
        var artUri = latest.uri;
        if (artUri == null) {
          // replace with placeholder art
          final applicationSupportDirectory = await getApplicationSupportDirectory();
          artUri = Uri.file(path_helper.join(applicationSupportDirectory.absolute.path, Assets.images.albumWhite.path));
        }
        // player images should always be either the placeholder image, downloaded images, or loaded from the image cache.
        assert(artUri.scheme == "file");
        // use content provider for handling media art on Android
        if (Platform.isAndroid) {
          final packageInfo = await PackageInfo.fromPlatform();
          artUri = Uri(scheme: "content", host: packageInfo.packageName, path: artUri.path);
        }
        if (!force && _audioHandler.mediaItem.valueOrNull?.id != currentMediaItem?.id) return;
        currentMediaItem = currentMediaItem?.copyWith(artUri: artUri);
        _audioHandler.mediaItem.add(currentMediaItem);
      }

      _latestAlbumImage?.close();
      _latestAlbumImage = _providers.listen(
        albumImageProvider(artRequest),
        (_, latest) => updateMediaItem(latest, false),
      );
      updateMediaItem(_providers.read(albumImageProvider(artRequest)), true);
    }
    _audioHandler.queue.add(
      _queuePreviousTracks
          .followedBy(_currentTrack != null ? [_currentTrack!] : [])
          .followedBy(_queueNextUp)
          .followedBy(_queue)
          .map((e) => e.item)
          .toList(),
    );
    // _audioHandler.queueTitle.add(_order.originalSource.name.toString());
    _audioHandler.queueTitle.add("Finamp");

    if (_savedQueueState == SavedQueueState.saving) {
      _saveCurrentQueue(withPosition: false);
      _queueServiceLogger.finest("Saved new rebuilt queue");
      _saveUpdateImmediate = false;
      _saveUpdateCycleCount = 0;
    }

    if (logUpdate) {
      _logQueues(message: "(current)");
    }

    if (FinampSettingsHelper.finampSettings.reportQueueToServer || FinampSettingsHelper.finampSettings.enablePlayon) {
      unawaited(playbackHistoryService.reportQueueStatus());
    }
  }

  FinampStorableQueueInfo _saveCurrentQueue({bool withPosition = false}) {
    final queueToSave = getQueue();
    List<int> shuffleIndices = [..._latestShuffleIndices];
    // if we exceeded the queue size limit, remove as many tracks from previousTracks as needed
    if (queueToSave.fullQueue.length > maxQueueItems) {
      final excess = queueToSave.fullQueue.length - maxQueueItems;
      // create a copy of previous tracks to avoid modifying the original list, which is tied directly to Finamp's internal queue
      var trimmedPreviousTracks = [...queueToSave.previousTracks];
      List<int> indicesToRemove = [];
      trimmedPreviousTracks.forEachIndexed((index, e) {
        if (indicesToRemove.length < excess && [QueueItemSourceType.radio].contains(e.source.type)) {
          indicesToRemove.add(index);
        }
      });
      if (indicesToRemove.isNotEmpty) {
        final List<int> shuffleIndicesToRemove;
        if (playbackOrder == FinampPlaybackOrder.shuffled) {
          shuffleIndicesToRemove = indicesToRemove.map((x) => shuffleIndices[x]).toList();
        } else {
          shuffleIndicesToRemove = indicesToRemove;
        }
        trimmedPreviousTracks = trimmedPreviousTracks
            .mapIndexed((i, x) => indicesToRemove.contains(i) ? null : x)
            .nonNulls
            .toList();
        shuffleIndices = shuffleIndices.map((x) => shuffleIndicesToRemove.contains(x) ? null : x).nonNulls.toList();
        queueToSave.previousTracks = trimmedPreviousTracks;
        // repair shuffle indices to close "gaps"
        for (int i = 0; i < shuffleIndices.length; i++) {
          int removedBefore = shuffleIndicesToRemove.where((x) => x < shuffleIndices[i]).length;
          shuffleIndices[i] = shuffleIndices[i] - removedBefore;
        }
      }
    }
    assert(queueToSave.trackCount == shuffleIndices.length);
    FinampStorableQueueInfo info = FinampStorableQueueInfo.fromQueueInfo(
      queueToSave,
      withPosition ? _audioHandler.playbackPosition.inMilliseconds : null,
      playbackOrder,
      shuffleIndices,
    );
    _queuesBox.put("latest", info);
    return info;
  }

  Future<void> performInitialQueueLoad() async {
    if (_savedQueueState == SavedQueueState.preInit) {
      try {
        _savedQueueState = SavedQueueState.init;
        archiveSavedQueue(inInit: true);
        var info = _queuesBox.get("latest");
        if (info != null) {
          var keys = _queuesBox.values.map((x) => DateTime.fromMillisecondsSinceEpoch(x.creation)).toList();
          keys.sort();
          _queueServiceLogger.finest("Stored queue dates: $keys");
          if (keys.length > _maxSavedQueues) {
            var extra = keys.getRange(0, keys.length - _maxSavedQueues).map((e) => e.millisecondsSinceEpoch.toString());
            _queueServiceLogger.finest("Deleting stored queues: $extra");
            unawaited(_queuesBox.deleteAll(extra));
          }

          if (FinampSettingsHelper.finampSettings.autoloadLastQueueOnStartup) {
            await loadSavedQueue(info);
          } else {
            _savedQueueState = SavedQueueState.pendingSave;
          }
        }
      } catch (e) {
        _queueServiceLogger.severe(e);
        rethrow;
      }
    }
  }

  /// Push latest queue into history if it is not empty and not a duplicate.
  /// If the caller is setting the queue state to saving, that should generally
  /// occur after this is called.
  void archiveSavedQueue({bool inInit = false}) {
    if (_savedQueueState == SavedQueueState.saving || inInit) {
      var latest = _queuesBox.get("latest");
      if (latest != null && latest.trackCount != 0) {
        _queuesBox.put(latest.creation.toString(), latest);
      }
    }
  }

  Future<void> retryQueueLoad() async {
    if (_savedQueueState == SavedQueueState.failed && _failedSavedQueue != null) {
      await loadSavedQueue(_failedSavedQueue!);
    }
  }

  Future<void> loadSavedQueue(
    FinampStorableQueueInfo info, {
    Map<jellyfin_models.BaseItemId, jellyfin_models.BaseItemDto>? existingItems,
    bool isReload = false,
  }) async {
    final playbackHistoryService = GetIt.instance<PlaybackHistoryService>();
    if (_savedQueueState == SavedQueueState.loading) {
      return Future.error("A saved queue is currently loading");
    }
    _queueServiceLogger.finest("Loading stored queue: $info");

    SavedQueueState finalState = SavedQueueState.failed;
    try {
      _savedQueueState = SavedQueueState.loading;
      if (info.trackCount == 0) {
        finalState = SavedQueueState.pendingSave;
        return;
      }
      refreshQueueStream();

      List<jellyfin_models.BaseItemId> allIds =
          info.previousTracks + ((info.currentTrack == null) ? [] : [info.currentTrack!]) + info.nextUp + info.queue;
      allIds.addAll(info.sourceList.where((x) => x.wantsItem).map((x) => jellyfin_models.BaseItemId(x.id)));
      Map<jellyfin_models.BaseItemId, jellyfin_models.BaseItemDto> idMap = existingItems ?? {};

      // If queue source is playlist, fetch via parent to retrieve metadata needed
      // for removal from playlist via queueItem
      if (!FinampSettingsHelper.finampSettings.isOffline) {
        for (final source in info.sourceList.where((x) => x.type == QueueItemSourceType.playlist)) {
          try {
            // Only id and type are really needed to fetch child items.  Full base item will be fetched later.
            final playlist = jellyfin_models.BaseItemDto(
              id: jellyfin_models.BaseItemId(source.id),
              type: BaseItemDtoType.playlist.jellyfinName,
            );
            var itemList =
                await _jellyfinApiHelper.getItems(
                  parentItem: playlist,
                  sortBy: "ParentIndexNumber,IndexNumber,SortName",
                  includeItemTypes: "Audio",
                ) ??
                [];
            for (var d2 in itemList) {
              idMap[d2.id] = d2;
            }
          } catch (e) {
            _queueServiceLogger.warning("Error loading queue source playlist, continuing anyway.  Error: $e");
          }
        }
      }

      // Get list of unique ids that do not yet have an associated item.
      List<jellyfin_models.BaseItemId> missingIds = allIds.toSet().difference(idMap.keys.toSet()).toList();

      if (FinampSettingsHelper.finampSettings.isOffline) {
        for (var id in missingIds) {
          jellyfin_models.BaseItemDto? item = _downloadsService.getTrackDownload(id: id)?.baseItem;
          if (item != null) {
            idMap[id] = item;
          }
        }
      } else {
        List<jellyfin_models.BaseItemDto> itemList = await _jellyfinApiHelper.getItems(itemIds: missingIds) ?? [];
        for (var d2 in itemList) {
          idMap[d2.id] = d2;
        }
      }

      int prevCount = 0;
      int curCount = 0;
      int nextCount = 0;
      int queueCount = 0;
      var previousTracks = info.previousTracks;
      var currentTracks = info.currentTrack == null ? <jellyfin_models.BaseItemId>[] : [info.currentTrack!];
      var nextTracks = info.nextUp;
      var queueTracks = info.queue;

      var order = info.shuffleOrder;
      // If order!=null, we received shuffled tracks.  Unshuffle before submitting to player.
      if (order != null && info.trackCount > 0) {
        final allTracks = previousTracks + currentTracks + nextTracks + queueTracks;
        final unshuffled = List.generate(order.length, (x) => x).map((x) => allTracks[order!.indexOf(x)]).toList();
        final currentIndex = order[previousTracks.length < allTracks.length ? previousTracks.length : 0];
        previousTracks = unshuffled.slice(0, currentIndex);
        currentTracks = unshuffled.slice(currentIndex, currentIndex + currentTracks.length);
        nextTracks = unshuffled.slice(
          currentIndex + currentTracks.length,
          currentIndex + currentTracks.length + nextTracks.length,
        );
        queueTracks = unshuffled.slice(currentIndex + currentTracks.length + nextTracks.length, order.length);
      }

      List<jellyfin_models.BaseItemDto> items = [];
      List<QueueItemSource> sources = [];
      List<int?> postDropIndices = [];
      final allSources = info.trackSources;
      int i = 0;
      int j = 0;
      void processTrack(jellyfin_models.BaseItemId id) {
        if (idMap.containsKey(id) && idMap[id] != null) {
          items.add(idMap[id]!);
          sources.add(allSources[i].withItem(idMap[jellyfin_models.BaseItemId(allSources[i].id)]));
          postDropIndices.add(j);
          j++;
        } else {
          postDropIndices.add(null);
        }
        i++;
      }

      previousTracks.forEach(processTrack);
      prevCount = items.length;
      currentTracks.forEach(processTrack);
      curCount = items.length - prevCount;
      nextTracks.forEach(processTrack);
      nextCount = items.length - curCount - prevCount;
      queueTracks.forEach(processTrack);
      queueCount = items.length - nextCount - curCount - prevCount;

      if (order != null) {
        order = order.map((x) => postDropIndices[x]).nonNulls.toList();
      }

      assert(i == info.trackCount);
      assert(j == items.length);
      assert(prevCount + curCount + nextCount + queueCount == items.length);
      assert(order == null || order.length == items.length);

      int loadedTracks = items.length;
      int droppedTracks = info.trackCount - loadedTracks;

      if (_savedQueueState != SavedQueueState.loading) {
        return Future.error("Loading of saved Queue was interrupted.");
      }

      if (loadedTracks > 0) {
        await _replaceWholeQueue(
          isRestoredQueue: true,
          itemList: items,
          trackSources: sources,
          initialIndex: curCount > 0 || queueCount > 0 || nextCount > 0 ? prevCount : 0,
          nextUpLength: curCount == 0 ? max(0, nextCount - 1) : nextCount,
          shuffleOrder: order,
          initialSeekPosition: (info.currentTrackSeek ?? 0) > (isReload ? 500 : 5000) && curCount > 0
              ? Duration(milliseconds: info.currentTrackSeek!)
              : null,
          order: order == null ? FinampPlaybackOrder.linear : FinampPlaybackOrder.shuffled,
          beginPlaying: isReload
              ? (_audioHandler.playbackState.valueOrNull?.playing ?? false)
              : (FinampSettingsHelper.finampSettings.autoplayRestoredQueue && droppedTracks == 0),
          source: info.source.withItem(idMap[jellyfin_models.BaseItemId(info.source.id)]),
        );
      }
      _queueServiceLogger.info("Loaded saved queue.");
      if (loadedTracks > 0 || info.trackCount == 0) {
        // After loading queue, do not begin overwriting latest until the user modifies
        // the queue or begins playback.  This prevents saving unused queues that
        // had loading errors or were immediately overwritten.
        finalState = SavedQueueState.pendingSave;

        if (droppedTracks > 0) {
          GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.queueRestoreError(droppedTracks));
        }
      }
    } finally {
      // Do not overwrite state or bump reporting if loading was interrupted by the user starting a new queue
      if (_savedQueueState == SavedQueueState.loading) {
        _savedQueueState = finalState;
        if (finalState == SavedQueueState.failed) {
          _failedSavedQueue = info;
        }
        refreshQueueStream();
        await Future<void>.delayed(const Duration(seconds: 1)).then((_) {
          unawaited(playbackHistoryService.reportRestoredSessionStatus());
        });
      }
    }
  }

  Future<void> startPlayback({
    required List<jellyfin_models.BaseItemDto> items,
    required QueueItemSource source,
    QueueItemSource? customTrackSource,
    FinampPlaybackOrder? order,
    int? startingIndex,
    bool skipRadioCacheInvalidation = false,
  }) async {
    // _initialQueue = list; // save original PlaybackList for looping/restarting and meta info

    await _replaceWholeQueue(
      itemList: items,
      source: source,
      customTrackSource: customTrackSource,
      order: order,
      initialIndex: startingIndex,
      skipRadioCacheInvalidation: skipRadioCacheInvalidation,
    );
    _queueServiceLogger.info(
      "Started playing '${GlobalSnackbar.materialAppScaffoldKey.currentContext != null ? source.name.getLocalized(GlobalSnackbar.materialAppScaffoldKey.currentContext!) : source.name.type}' (${source.type}) in order $order from index $startingIndex",
    );
    _queueServiceLogger.info("Items for queue: [${items.map((e) => e.name).join(", ")}]");
  }

  /// Replaces the queue with the given list of items. If startAtIndex is specified, Any items below it
  /// will be ignored. This is used for when the user taps in the middle of an album to start from that point.
  Future<void> _replaceWholeQueue({
    required List<jellyfin_models.BaseItemDto> itemList,
    required QueueItemSource source,
    QueueItemSource? customTrackSource,
    List<QueueItemSource?>? trackSources,
    int? initialIndex,
    int? nextUpLength,
    List<int>? shuffleOrder,
    Duration? initialSeekPosition,
    FinampPlaybackOrder? order,
    bool beginPlaying = true,
    bool isRestoredQueue = false,
    bool skipRadioCacheInvalidation = false,
  }) async {
    if (trackSources != null) {
      if (trackSources.length != itemList.length) {
        _queueServiceLogger.severe(
          "trackSources length (${trackSources.length}) does not match itemList length (${itemList.length})",
        );
        assert(false);
        trackSources = null;
      }
    }
    if (shuffleOrder != null) {
      if (shuffleOrder.length != itemList.length ||
          shuffleOrder.toSet().length != itemList.length ||
          shuffleOrder.any((x) => x < 0 || x >= shuffleOrder!.length)) {
        _queueServiceLogger.severe(
          "received invalid shuffleOrder $shuffleOrder for  itemList length (${itemList.length})",
        );
        // If an invalid shuffleOrder is received in release mode, ignore it and continue.  But if we are
        // in debug mode, throw.
        assert(false);
        shuffleOrder = null;
      }
    }

    try {
      if (itemList.isEmpty) {
        _queueServiceLogger.warning("Cannot start playback of empty queue! Source: $source");
        return;
      }

      if (!skipRadioCacheInvalidation) {
        invalidateRadioCache();
      }

      order ??= FinampPlaybackOrder.linear;

      nextUpLength ??= 0;

      if (initialIndex == null) {
        if (order == FinampPlaybackOrder.shuffled) {
          initialIndex = Random().nextInt(itemList.length);
        } else {
          initialIndex = 0;
        }
      }

      if (initialIndex >= itemList.length) {
        return Future.error("initialIndex is bigger than the itemList! ($initialIndex >= ${itemList.length})");
      }

      if (initialIndex + nextUpLength >= itemList.length) {
        return Future.error(
          "nextUpLength is longer than available items! ($nextUpLength >= ${itemList.length - initialIndex})",
        );
      }

      _queueServiceLogger.finest("Replacing whole queue with ${itemList.length} items.");

      if (!isRestoredQueue) {
        archiveSavedQueue();
        _savedQueueState = SavedQueueState.saving;
      }

      _queue.clear(); // empty queue
      _queuePreviousTracks.clear();
      _queueNextUp.clear();
      _currentTrack = null;
      playlistRemovalsCache.clear();

      List<FinampQueueItem> newItems = [];
      List<int> newLinearOrder = [];
      List<int> newShuffledOrder;
      for (int i = 0; i < itemList.length; i++) {
        final jellyfin_models.BaseItemDto item = itemList[i];
        try {
          MediaItem mediaItem = await generateMediaItem(
            item,
            contextNormalizationGain: isRestoredQueue ? null : source.contextNormalizationGain,
          );
          newItems.add(
            FinampQueueItem(
              item: mediaItem,
              source: trackSources?[i] ?? (isRestoredQueue ? savedQueueSource : customTrackSource ?? source),
              type: switch (i) {
                _ when i < initialIndex => QueueItemQueueType.previousTracks,
                _ when i == initialIndex => QueueItemQueueType.currentTrack,
                _ when i <= initialIndex + nextUpLength => QueueItemQueueType.nextUp,
                _ => QueueItemQueueType.queue,
              },
            ),
          );
          newLinearOrder.add(i);
        } catch (e, trace) {
          _queueServiceLogger.severe(e, e, trace);
        }
      }

      if (Platform.isIOS || Platform.isMacOS) {
        // Both iOS and macOS will start playing the first queue index if we don't stop first
        await _audioHandler.stopPlayback();
      }
      await _audioHandler.clearFinampQueueItems();

      try {
        // block _buildQueueFromNativePlayerQueue until both new sequence
        // and intial index have been applied.
        _activeInitialIndex = initialIndex;
        await _audioHandler.setQueueItems(
          newItems,
          initialIndex: initialIndex,
          preload: true,
          shuffleOrder: _shuffleOrder,
          initialPosition: initialSeekPosition ?? Duration.zero,
        );
      } finally {
        _activeInitialIndex = null;
      }

      //!!! keep this roughly here so the player screen opens to the correct track, but doesn't seem laggy
      if (beginPlaying) {
        // only open the player screen if we actually start playing, otherwise it would open after startup + queue restore
        if (FinampSettingsHelper.finampSettings.autoExpandPlayerScreen) {
          unawaited(NowPlayingBar.openPlayerScreen(GlobalSnackbar.materialAppNavigatorKey.currentContext!));
        }
      }

      newShuffledOrder = List.from(_audioHandler.shuffleIndices);

      _order = FinampQueueOrder(
        items: newItems,
        originalSource: source,
        linearOrder: newLinearOrder,
        shuffledOrder: newShuffledOrder,
        sourceLibrary: _finampUserHelper.currentUser?.currentView,
      );

      _queueServiceLogger.fine("Order items length: ${_order.items.length}");

      // set playback order to trigger shuffle if necessary (fixes indices being wrong when starting with shuffle enabled)
      // this will run _queueFromConcatenatingAudioSource();
      await setPlaybackOrder(order, shuffleOrder: shuffleOrder);

      if (beginPlaying) {
        // don't await this, because it will not return until playback is finished
        unawaited(_audioHandler.play(disableFade: true));
      } else if (!Platform.isAndroid && !Platform.isIOS) {
        unawaited(_audioHandler.pause(disableFade: true));
      }
    } catch (e) {
      _queueServiceLogger.severe("Error while initializing queue: $e", e);
    }
  }

  Future<void> reloadQueue({bool archiveQueue = false}) async {
    _queueServiceLogger.info("Reloading queue");

    if (_audioHandler.audioSources.isEmpty) {
      return Future.error("Queue is empty, cannot reload!");
    }

    _saveCurrentQueue(withPosition: true);
    if (archiveQueue) {
      archiveSavedQueue();
    }

    var info = _queuesBox.get("latest");
    if (info != null) {
      final Map<jellyfin_models.BaseItemId, jellyfin_models.BaseItemDto> existingItems = {};
      final queueInfo = getQueue();

      // re-use items in online mode, re-fetch from downloads service in offline mode (will happen later on)
      if (!FinampSettingsHelper.finampSettings.isOffline) {
        for (var item in queueInfo.fullQueue) {
          existingItems[item.baseItemId] = item.baseItem;
        }
      }

      await loadSavedQueue(info, existingItems: existingItems, isReload: true);
    }
  }

  Future<void> stopAndClearQueue() async {
    queueServiceLogger.info("Stopping playback");

    archiveSavedQueue();
    if (_savedQueueState == SavedQueueState.pendingSave) {
      _savedQueueState = SavedQueueState.saving;
    }

    // avoid radio eagerly adding new tracks from cache (or requesting new tracks) right after the queue is cleared
    final previousRadioState = FinampSettingsHelper.finampSettings.radioEnabled;
    FinampSetters.setRadioEnabled(false);
    invalidateRadioCache();

    await _audioHandler.clearFinampQueueItems();

    await _audioHandler.stopPlayback();

    _buildQueueFromNativePlayerQueue();
    // await _audioHandler.initializeAudioSource(_queueAudioSource,
    //     preload: false);

    FinampSetters.setRadioEnabled(previousRadioState);

    return;
  }

  Future<void> addToQueue({
    required List<jellyfin_models.BaseItemDto> items,
    QueueItemSource? source,
    FinampPlaybackOrder? order,
  }) async {
    if (_audioHandler.audioSources.isEmpty) {
      return _replaceWholeQueue(
        itemList: items,
        order: order,
        source:
            source ??
            QueueItemSource.rawId(
              type: QueueItemSourceType.queue,
              name: const QueueItemSourceName(type: QueueItemSourceNameType.queue),
              id: "queue",
              item: null,
            ),
        beginPlaying: false,
      );
    }

    try {
      if (_savedQueueState == SavedQueueState.pendingSave) {
        _savedQueueState = SavedQueueState.saving;
      }
      if (order == FinampPlaybackOrder.shuffled) {
        List<jellyfin_models.BaseItemDto> clonedItems = List.from(items);
        clonedItems.shuffle();
        items = clonedItems;
      }
      List<FinampQueueItem> queueItems = [];
      for (final item in items) {
        queueItems.add(
          FinampQueueItem(
            item: await generateMediaItem(item, contextNormalizationGain: source?.contextNormalizationGain),
            source: source ?? _order.originalSource,
            type: QueueItemQueueType.queue,
          ),
        );
        _queueServiceLogger.fine(
          "Added '${queueItems.last.item.title}' to queue from '${source?.name}' (${source?.type})",
        );
      }

      await _audioHandler.appendFinampQueueItems(queueItems);

      _buildQueueFromNativePlayerQueue(); // update internal queues
    } catch (e) {
      _queueServiceLogger.severe(e);
      rethrow;
    }
  }

  Future<void> addNext({
    required List<jellyfin_models.BaseItemDto> items,
    QueueItemSource? source,
    FinampPlaybackOrder? order,
  }) async {
    if (_audioHandler.audioSources.isEmpty) {
      return _replaceWholeQueue(
        itemList: items,
        source:
            source ??
            QueueItemSource.rawId(
              type: QueueItemSourceType.queue,
              name: const QueueItemSourceName(type: QueueItemSourceNameType.queue),
              id: "queue",
              item: null,
            ),
        beginPlaying: false,
        order: order,
      );
    }

    try {
      if (_savedQueueState == SavedQueueState.pendingSave) {
        _savedQueueState = SavedQueueState.saving;
      }
      if (order == FinampPlaybackOrder.shuffled) {
        List<jellyfin_models.BaseItemDto> clonedItems = List.from(items);
        clonedItems.shuffle();
        items = clonedItems;
      }
      List<FinampQueueItem> queueItems = [];
      for (final item in items) {
        queueItems.add(
          FinampQueueItem(
            item: await generateMediaItem(item, contextNormalizationGain: source?.contextNormalizationGain),
            source:
                source ??
                QueueItemSource.rawId(
                  id: "next-up",
                  name: const QueueItemSourceName(type: QueueItemSourceNameType.nextUp),
                  type: QueueItemSourceType.nextUp,
                ),
            type: QueueItemQueueType.nextUp,
          ),
        );
      }

      int adjustedQueueIndex = getActualIndexByLinearIndex(_currentQueueIndex);
      int offset = min(_audioHandler.audioSources.length, 1);
      int offsetLog = offset;

      for (final queueItem in queueItems) {
        _queueServiceLogger.fine(
          "Prepended '${queueItem.item.title}' to Next Up (index ${adjustedQueueIndex + offsetLog})",
        );
        offsetLog++;
      }
      await _audioHandler.insertFinampQueueItems(adjustedQueueIndex + offset, queueItems);

      _buildQueueFromNativePlayerQueue(); // update internal queues
    } catch (e) {
      _queueServiceLogger.severe(e);
      rethrow;
    }
  }

  Future<void> addToNextUp({
    required List<jellyfin_models.BaseItemDto> items,
    QueueItemSource? source,
    FinampPlaybackOrder? order,
  }) async {
    if (_audioHandler.audioSources.isEmpty) {
      return _replaceWholeQueue(
        itemList: items,
        source:
            source ??
            QueueItemSource.rawId(
              type: QueueItemSourceType.queue,
              name: const QueueItemSourceName(type: QueueItemSourceNameType.queue),
              id: "queue",
              item: null,
            ),
        beginPlaying: false,
        order: order,
      );
    }

    try {
      if (_savedQueueState == SavedQueueState.pendingSave) {
        _savedQueueState = SavedQueueState.saving;
      }
      if (order == FinampPlaybackOrder.shuffled) {
        List<jellyfin_models.BaseItemDto> clonedItems = List.from(items);
        clonedItems.shuffle();
        items = clonedItems;
      }
      List<FinampQueueItem> queueItems = [];
      for (final item in items) {
        queueItems.add(
          FinampQueueItem(
            item: await generateMediaItem(item, contextNormalizationGain: source?.contextNormalizationGain),
            source:
                source ??
                QueueItemSource.rawId(
                  id: "next-up",
                  name: const QueueItemSourceName(type: QueueItemSourceNameType.nextUp),
                  type: QueueItemSourceType.nextUp,
                ),
            type: QueueItemQueueType.nextUp,
          ),
        );
      }

      _buildQueueFromNativePlayerQueue(logUpdate: false); // update internal queues
      int offset = _queueNextUp.length + min(_audioHandler.audioSources.length, 1);
      int offsetLog = offset;

      int adjustedQueueIndex = getActualIndexByLinearIndex(_currentQueueIndex);

      for (final queueItem in queueItems) {
        _queueServiceLogger.fine(
          "Appended '${queueItem.item.title}' to Next Up (index ${adjustedQueueIndex + offsetLog})",
        );
        offsetLog++;
      }
      await _audioHandler.insertFinampQueueItems(adjustedQueueIndex + offset, queueItems);

      _buildQueueFromNativePlayerQueue(); // update internal queues
    } catch (e) {
      _queueServiceLogger.severe(e);
      rethrow;
    }
  }

  Future<void> skipByOffset(int offset) async {
    await _audioHandler.skipByOffset(offset);
  }

  Future<void> removeAtOffset(int offset) async {
    int adjustedQueueIndex = getActualIndexByLinearIndex(_currentQueueIndex + offset);

    await _audioHandler.removeFinampQueueItemAt(adjustedQueueIndex);
    _buildQueueFromNativePlayerQueue();
  }

  /// This function removes all upcoming radio tracks.
  /// Callers should set up correct radio state synchronously before calling this,
  /// so that we will be ready for the radio to restart as soon as this function releases its lock.
  /// i.e., there's a chance for [maybeAddRadioTracks] to fire in the async gap after the lock releases before the caller regains execution, so the radio settings should be set up beforehand so that the state doesn't get invalidated immediately.
  Future<void> clearRadioTracks() async {
    _queueServiceLogger.finer("Clearing radio tracks from queue.");
    await withRadioLock(() async {
      final radioIndices = _queue
          .asMap()
          .entries
          .where((entry) {
            return entry.value.source.type == QueueItemSourceType.radio;
          })
          .map((entry) => entry.key)
          .toList();
      if (radioIndices.isEmpty) {
        return;
      }
      List<int> adjustedIndicesToRemove = [];
      for (final index in radioIndices) {
        int adjustedQueueIndex = getActualIndexByLinearIndex(_currentQueueIndex + _queueNextUp.length + index + 1);
        adjustedIndicesToRemove.add(adjustedQueueIndex);
      }
      int currentRangeEnd = adjustedIndicesToRemove.last;
      int currentRangeStart = currentRangeEnd;
      // remove from the back to avoid index shifting
      for (final adjustedIndex in adjustedIndicesToRemove.reversed.skip(1)) {
        if (adjustedIndex == currentRangeStart - 1 && adjustedIndex != adjustedIndicesToRemove.first) {
          currentRangeStart = adjustedIndex;
        } else {
          // remove in batches to improve performance
          await _audioHandler.removeFinampQueueItemRange(adjustedIndex, currentRangeEnd + 1);
          currentRangeStart = adjustedIndex;
          currentRangeEnd = adjustedIndex;
        }
      }
      _buildQueueFromNativePlayerQueue();
    });
  }

  Future<void> removeQueueItem(FinampQueueItem queueItem) async {
    int? offset = getQueue().getOffsetForQueueItem(queueItem);
    if (offset == null) {
      return;
    }
    return removeAtOffset(offset);
  }

  Future<void> reorderByOffset(int oldOffset, int newOffset) async {
    _queueServiceLogger.fine("Reordering queue item at offset $oldOffset to offset $newOffset");

    if (playbackOrder == FinampPlaybackOrder.shuffled) {
      final newShuffleOrder = [..._shuffleOrder.indices];
      final int itemToMove = newShuffleOrder.removeAt(_currentQueueIndex + oldOffset);
      newShuffleOrder.insert(
        oldOffset < newOffset ? _currentQueueIndex + newOffset - 1 : _currentQueueIndex + newOffset,
        itemToMove,
      );
      try {
        _shuffleOrder.overrideShuffle(newShuffleOrder);
        await _audioHandler.shuffle();
      } finally {
        _shuffleOrder.overrideShuffle(null);
      }
    } else {
      final oldIndex = _currentQueueIndex + oldOffset;
      final newIndex = oldOffset < newOffset ? _currentQueueIndex + newOffset - 1 : _currentQueueIndex + newOffset;

      await _audioHandler.moveFinampQueueItem(oldIndex, newIndex);
    }

    _buildQueueFromNativePlayerQueue();
  }

  Future<void> clearNextUp() async {
    int adjustedQueueIndex = getActualIndexByLinearIndex(_currentQueueIndex);

    // remove all items from Next Up
    if (_queueNextUp.isNotEmpty) {
      await _audioHandler.removeFinampQueueItemRange(
        adjustedQueueIndex + 1,
        adjustedQueueIndex + 1 + _queueNextUp.length,
      );
      _queueNextUp.clear();
    }

    _buildQueueFromNativePlayerQueue(); // update internal queues
  }

  FinampQueueInfo getQueue() {
    return FinampQueueInfo(
      id: _order.id,
      previousTracks: _queuePreviousTracks,
      currentTrack: _currentTrack,
      queue: _queue,
      nextUp: _queueNextUp,
      source: _order.originalSource,
      saveState: _savedQueueState,
      sourceLibrary: _order.sourceLibrary,
    );
  }

  BehaviorSubject<FinampQueueInfo?> getQueueStream() {
    return _queueStream;
  }

  static final _queueInfoStreamProvider = StreamProvider<FinampQueueInfo?>((ref) {
    final service = GetIt.instance<QueueService>();
    return service.getQueueStream();
  });

  static final queueProvider = Provider<FinampQueueInfo?>((ref) {
    return ref.watch(_queueInfoStreamProvider).value ?? GetIt.instance<QueueService>().getQueue();
  });

  void refreshQueueStream() {
    _queueStream.add(getQueue());
  }

  /// Returns the entire queue (Next Up + regular queue)
  /// If [next] is provided (and greater than 0), at most [next] QueueItems from Next Up and the regular queue will be returned
  /// If [previous] is provided (and greater than 0), at most [previous] QueueItems from previous tracks will be additionally returned.
  /// The length of the returned list may be less than the sum of [next] and [previous] if there are not enough items in the queue
  List<FinampQueueItem> peekQueue({int? next, int previous = 0, bool current = false}) {
    List<FinampQueueItem> nextTracks = [];
    if (_queuePreviousTracks.isNotEmpty && previous > 0) {
      nextTracks.addAll(
        _queuePreviousTracks.sublist(max(0, _queuePreviousTracks.length - previous), _queuePreviousTracks.length),
      );
    }
    if (_currentTrack != null && current) {
      nextTracks.add(_currentTrack!);
    }
    if (_queueNextUp.isNotEmpty) {
      if (next == null) {
        nextTracks.addAll(_queueNextUp);
      } else {
        nextTracks.addAll(_queueNextUp.sublist(0, min(next, _queueNextUp.length)));
        next -= _queueNextUp.length;
      }
    }
    if (_queue.isNotEmpty) {
      if (next == null) {
        nextTracks.addAll(_queue);
      } else if (next > 0) {
        nextTracks.addAll(_queue.sublist(0, min(next, _queue.length)));
      }
    }
    return nextTracks;
  }

  BehaviorSubject<FinampPlaybackOrder> getPlaybackOrderStream() {
    return _playbackOrderStream;
  }

  BehaviorSubject<FinampLoopMode> getLoopModeStream() {
    return _loopModeStream;
  }

  BehaviorSubject<double> getPlaybackSpeedStream() {
    return _playbackSpeedStream;
  }

  BehaviorSubject<FinampQueueItem?> getCurrentTrackStream() {
    return _currentTrackStream;
  }

  FinampQueueItem? getCurrentTrack() {
    return _currentTrack;
  }

  set playbackSpeed(double speed) {
    _playbackSpeed = speed;
    _playbackSpeedStream.add(speed);
    _audioHandler.setSpeed(speed);
    FinampSetters.setPlaybackSpeed(playbackSpeed);
    _queueServiceLogger.fine("Playback speed set to ${FinampSettingsHelper.finampSettings.playbackSpeed}");
    if (FinampSettingsHelper.finampSettings.syncPlaybackSpeedAndPitch) {
      playbackPitch = speed;
    }
  }

  double get playbackSpeed => _playbackSpeed;

  set playbackPitch(double pitch) {
    _playbackPitch = pitch;
    _playbackPitchStream.add(pitch);
    _audioHandler.setPitch(pitch);
    FinampSetters.setPlaybackPitch(playbackPitch);
    _queueServiceLogger.fine("Playback pitch set to ${FinampSettingsHelper.finampSettings.playbackPitch}");
  }

  double get playbackPitch => _playbackPitch;

  set loopMode(FinampLoopMode mode) {
    _loopMode = mode;

    _loopModeStream.add(mode);
    if (FinampSettingsHelper.finampSettings.radioEnabled) {
      // we disable looping in the player while the radio is enabled
      // so that we can pause on the current track if we ever run out of radio tracks
      _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
    } else {
      if (mode == FinampLoopMode.one) {
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
      } else if (mode == FinampLoopMode.all) {
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
      } else {
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
      }
    }

    FinampSetters.setLoopMode(loopMode);
    _queueServiceLogger.fine("Loop mode set to ${FinampSettingsHelper.finampSettings.loopMode}");
  }

  FinampLoopMode get loopMode => _loopMode;

  Future<void> setPlaybackOrder(FinampPlaybackOrder order, {List<int>? shuffleOrder}) async {
    _playbackOrder = order;
    _queueServiceLogger.fine("Playback order set to $order");

    _playbackOrderStream.add(order);

    // update queue accordingly and generate new shuffled order if necessary
    final AudioServiceShuffleMode mode;
    if (_playbackOrder == FinampPlaybackOrder.shuffled) {
      if (shuffleOrder != null) {
        // shuffleOrder does not need to be applied when switching to linear
        // mode, as we will reshuffle if we later switch over to shuffle mode.
        try {
          _shuffleOrder.overrideShuffle(shuffleOrder);
          await _audioHandler.shuffle();
        } finally {
          _shuffleOrder.overrideShuffle(null);
        }
      } else {
        await _audioHandler.shuffle();
      }
      mode = AudioServiceShuffleMode.all;
    } else {
      mode = AudioServiceShuffleMode.none;
    }
    await _audioHandler.setShuffleMode(mode);
    //await _audioHandler.playbackState.where((event) => event.shuffleMode == mode).first;
    _buildQueueFromNativePlayerQueue();
  }

  FinampPlaybackOrder get playbackOrder => _playbackOrder;

  Future<void> togglePlaybackOrder() {
    if (_playbackOrder == FinampPlaybackOrder.shuffled) {
      return setPlaybackOrder(FinampPlaybackOrder.linear);
    } else {
      return setPlaybackOrder(FinampPlaybackOrder.shuffled);
    }
  }

  void toggleLoopMode() {
    final radioMode = FinampSettingsHelper.finampSettings.radioMode;
    final radioEnabled = FinampSettingsHelper.finampSettings.radioEnabled;
    final radioSeed = _providers.read(getActiveRadioSeedProvider(radioMode));
    final radioAvailabilityStatus = _providers.read(radioModeAvailabilityStatusProvider((radioMode, radioSeed)));
    final radioActive = radioEnabled && radioAvailabilityStatus.isAvailable;

    // if we start toggling loop modes, the radio should be disabled, to prevent it kicking back in when it becomes available
    if (radioEnabled) {
      toggleRadio(false);
    }
    // if the radio was active, we also reset the loop mode
    if (radioActive) {
      loopMode = FinampLoopMode.none;
      return;
    }

    if (_loopMode == FinampLoopMode.all) {
      loopMode = FinampLoopMode.one;
    } else if (_loopMode == FinampLoopMode.one) {
      loopMode = FinampLoopMode.none;
    } else {
      loopMode = FinampLoopMode.all;
    }
  }

  Logger get queueServiceLogger => _queueServiceLogger;

  int getActualIndexByLinearIndex(int linearIndex) {
    if (_playbackOrder == FinampPlaybackOrder.shuffled && _audioHandler.shuffleIndices.isNotEmpty) {
      return _audioHandler.shuffleIndices[linearIndex];
    } else {
      return linearIndex;
    }
  }

  void _logQueues({String message = ""}) {
    // generate string for `_queue`
    String queueString = "";
    for (FinampQueueItem queueItem in _queuePreviousTracks) {
      queueString += "${queueItem.item.title}, ";
    }
    queueString += "[[${_currentTrack?.item.title}]], ";
    queueString += "{";
    for (FinampQueueItem queueItem in _queueNextUp) {
      queueString += "${queueItem.item.title}, ";
    }
    queueString += "} ";
    for (FinampQueueItem queueItem in _queue) {
      queueString += "${queueItem.item.title}, ";
    }

    // generate string for `_queueAudioSource`
    // String queueAudioSourceString = "";
    // queueAudioSourceString += "[${_queueAudioSource.sequence.firstOrNull?.toString()}], ";
    // for (AudioSource queueItem in _queueAudioSource.sequence.sublist(1)) {
    //   queueAudioSourceString += "${queueItem.toString()}, ";
    // }

    // log queues
    _queueServiceLogger.finer(
      "Queue $message [${_queuePreviousTracks.length}-1-${_queueNextUp.length}-${_queue.length}]: $queueString",
    );
    // _queueServiceLogger.finer(
    //   "Audio Source Queue $message [${_queue.length}]: $queueAudioSourceString"
    // )
  }

  /// [contextNormalizationGain] is the normalization gain of the context that the track is being played in, e.g. the album
  /// Should only be used when the tracks within that context come from the same source, e.g. the same album (or maybe artist?). Usually makes no sense for playlists.
  Future<MediaItem> generateMediaItem(
    jellyfin_models.BaseItemDto item, {
    double? contextNormalizationGain,
    MediaItemParentType? parentType,
    jellyfin_models.BaseItemId? parentId,
    bool Function({jellyfin_models.BaseItemDto? item, TabContentType? contentType})? isPlayable,
  }) async {
    const uuid = Uuid();

    MediaItemId? itemId;
    final tabContentType = TabContentType.fromItemType(item.type ?? "Audio");
    bool isAndroidAutoOrMediaBrowserRequest = false;

    if (parentType != null) {
      isAndroidAutoOrMediaBrowserRequest = true;
      itemId = MediaItemId(
        contentType: tabContentType,
        parentType: parentType,
        parentId: parentId ?? item.parentId,
        itemId: item.id,
      );
    }

    bool isDownloaded = false;
    bool isItemPlayable = isPlayable?.call(item: item) ?? true;
    DownloadItem? downloadedTrack;
    DownloadStub? downloadedCollection;

    if (item.type == "Audio") {
      downloadedTrack = _downloadsService.getTrackDownload(item: item);
      isDownloaded = downloadedTrack != null;
    } else {
      downloadedCollection = await _downloadsService.getCollectionInfo(item: item);
      if (downloadedCollection != null) {
        final downloadStatus = _downloadsService.getStatus(downloadedCollection, null);
        isDownloaded = downloadStatus != DownloadItemStatus.notNeeded;
      }
    }

    Uri? artUri = isAndroidAutoOrMediaBrowserRequest
        ? _providers.read(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 200, maxWidth: 200))).uri
        : null;

    // use content provider for handling media art on Android
    if (Platform.isAndroid && isAndroidAutoOrMediaBrowserRequest) {
      final packageInfo = await PackageInfo.fromPlatform();
      // replace with placeholder art
      if (artUri == null) {
        final applicationSupportDirectory = await getApplicationSupportDirectory();
        artUri = Uri(
          scheme: "content",
          host: packageInfo.packageName,
          path: path_helper.join(applicationSupportDirectory.absolute.path, Assets.images.albumWhite.path),
        );
      } else {
        // store the origin in fragment since it should be unused
        artUri = Uri(
          scheme: "content",
          host: packageInfo.packageName,
          path: artUri.path,
          fragment: ["http", "https"].contains(artUri.scheme) ? artUri.origin : null,
        );
      }
    }

    return MediaItem(
      id: itemId?.toString() ?? uuid.v4(),
      playable:
          isItemPlayable, // this dictates whether clicking on an item will try to play it or browse it in media browsers like Android Auto
      album: item.album,
      artist: item.artists?.join(", ") ?? item.albumArtist,
      title: item.name ?? "unknown",
      extras: {
        //!!! this ID has to be consistent across the transcoding URL and the playback reporting status, otherwise the server won't show that we're transcoding
        "playSessionId": uuid.v4(),
        "itemJson": item.toJson(setOffline: false),
        "shouldTranscode": FinampSettingsHelper.finampSettings.shouldTranscode,
        "downloadedTrackPath": downloadedTrack?.file?.path,
        "isDownloaded": isDownloaded,
        "android.media.extra.DOWNLOAD_STATUS": isDownloaded ? 2 : 0,
        "android.media.IS_EXPLICIT": item.isExplicit ? 1 : 0,
        "isOffline": FinampSettingsHelper.finampSettings.isOffline,
        "contextNormalizationGain": contextNormalizationGain,
      },
      // Jellyfin returns microseconds * 10 for some reason
      duration: item.runTimeTicksDuration(),
      artUri: artUri,
    );
  }
}

class NextUpShuffleOrder extends ShuffleOrder {
  final Random _random;
  final QueueService _queueService;
  @override
  List<int> indices = <int>[];
  List<int>? shuffleIndicesOverride;

  NextUpShuffleOrder({Random? random, required QueueService queueService})
    : _random = random ?? Random(),
      _queueService = queueService;

  @override
  void shuffle({int? initialIndex}) {
    assert(initialIndex == null || indices.contains(initialIndex));

    if (shuffleIndicesOverride != null) {
      if (shuffleIndicesOverride!.length == indices.length) {
        indices = shuffleIndicesOverride!;
        return;
      } else {
        throw Exception(
          "Invalid shuffleIndicesOverride length ${shuffleIndicesOverride!.length} indices length ${indices.length}.",
        );
      }
    }

    if (initialIndex == null) {
      throw Exception("NextUpShuffleOrder always expects an initialIndex.");
    }

    // calculate next up size manually insted of using _queueService._queueNextUp because that could be out of date, and we
    // don't want to call _queueService._buildQueueFromNativePlayerQueue on an in-progress queue with an invalid shuffle order.
    List<FinampQueueItem> allTracks = GetIt.instance<MusicPlayerBackgroundTask>().sequenceState.effectiveSequence
        .map((e) => e.tag as FinampQueueItem)
        .toList();
    assert(allTracks.length == indices.length);
    assert(initialIndex >= 0 && initialIndex < allTracks.length);

    if (indices.length <= 1) {
      return;
    }
    indices.shuffle(_random);

    _queueService.queueServiceLogger.finest("initialIndex: $initialIndex");

    // log indices
    String indicesString = "";
    for (int index in indices) {
      indicesString += "$index, ";
    }
    _queueService.queueServiceLogger.finest("Shuffled indices: $indicesString");
    _queueService.queueServiceLogger.finest("Current Track: ${allTracks[initialIndex]}");

    int nextUpLength = 0;
    for (int i = initialIndex + 1; i < allTracks.length; i++) {
      if (allTracks[i].type == QueueItemQueueType.nextUp) {
        nextUpLength++;
      } else {
        break;
      }
    }

    const initialPos = 0; // current item will always be at the front

    // move current track and next up tracks to the front, pushing all other tracks back while keeping their order
    // remove current track and next up tracks from indices and save them in a separate list
    List<int> currentTrackIndices = [];
    for (int i = 0; i < 1 + nextUpLength; i++) {
      currentTrackIndices.add(indices.removeAt(indices.indexOf(initialIndex + i)));
    }
    // insert current track and next up tracks at the front
    indices.insertAll(initialPos, currentTrackIndices);

    // log indices
    indicesString = "";
    for (int index in indices) {
      indicesString += "$index, ";
    }
    _queueService.queueServiceLogger.finest("Shuffled indices (swapped): $indicesString");
  }

  /// `index` is the linear index of the item in the ConcatenatingAudioSource
  @override
  void insert(int index, int count) {
    int insertionPoint = index;
    int linearIndexOfPreviousItem = index - 1;

    // _queueService!._queueFromConcatenatingAudioSource(logUpdate: false);
    // QueueInfo queueInfo = _queueService!.getQueue();

    // // log indices
    // String indicesString = "";
    // for (int index in indices) {
    //   indicesString += "$index, ";
    // }
    // _queueService!.queueServiceLogger.finest("Shuffled indices: $indicesString");
    // _queueService!.queueServiceLogger.finest("Current Track: ${queueInfo.currentTrack}");

    if (index >= indices.length) {
      // handle appending to the queue
      insertionPoint = indices.length;
    } else {
      // handle adding to Next Up
      int shuffledIndexOfPreviousItem = indices.indexOf(linearIndexOfPreviousItem);
      if (shuffledIndexOfPreviousItem != -1) {
        insertionPoint = shuffledIndexOfPreviousItem + 1;
      }
      _queueService.queueServiceLogger.finest(
        "Inserting $count items at index $index (shuffled indices insertion point: $insertionPoint) (index of previous item: $shuffledIndexOfPreviousItem)",
      );
    }

    // Offset indices after insertion point.
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= index) {
        indices[i] += count;
      }
    }

    // Insert new indices at the specified position.
    final newIndices = List.generate(count, (i) => index + i);
    indices.insertAll(insertionPoint, newIndices);
  }

  @override
  void removeRange(int start, int end) {
    // log indices
    String indicesString = "";
    for (int index in indices) {
      indicesString += "$index, ";
    }
    _queueService.queueServiceLogger.finest("Shuffled indices before removing: $indicesString");
    final count = end - start;
    // Remove old indices.
    final oldIndices = List.generate(count, (i) => start + i).toSet();
    indices.removeWhere(oldIndices.contains);
    // Offset indices after deletion point.
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= end) {
        indices[i] -= count;
      }
    }
    // log indices
    indicesString = "";
    for (int index in indices) {
      indicesString += "$index, ";
    }
    _queueService.queueServiceLogger.finest("Shuffled indices after removing: $indicesString");
  }

  void overrideShuffle(List<int>? shuffleOrder) {
    shuffleIndicesOverride = shuffleOrder;
  }

  @override
  void clear() {
    indices.clear();
  }
}

extension SequentialTracks on FinampQueueInfo {
  bool isCurrentlyPlayingTracksFromSameAlbum() {
    final currentTrackAlbum = currentTrack?.baseItem.parentId;
    if (currentTrackAlbum == null) return false;
    final previousTrackAlbum = previousTracks.lastOrNull?.baseItem.parentId;
    final nextTrackAlbum = (nextUp.firstOrNull ?? queue.firstOrNull)?.baseItem.parentId;

    return previousTrackAlbum == currentTrackAlbum || currentTrackAlbum == nextTrackAlbum;
  }
}
