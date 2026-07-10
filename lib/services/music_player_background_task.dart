import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:finamp/services/offline_listen_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api_helper.dart';

enum SkipButtonVisibility {
  always,
  automatic,
  never,
}

class SkipControlSettings {
  final Duration forwardSkipDuration;
  final Duration backwardSkipDuration;
  final SkipButtonVisibility visibility;
  final bool showInNotification;

  const SkipControlSettings({
    this.forwardSkipDuration = const Duration(seconds: 30),
    this.backwardSkipDuration = const Duration(seconds: 10),
    this.visibility = SkipButtonVisibility.automatic,
    this.showInNotification = true,
  });
}

// Largely copied from just_audio's DefaultShuffleOrder, but with a mildly
// stupid hack to insert() to make Play Next work
class FinampShuffleOrder extends ShuffleOrder {
  final Random _random;
  @override
  final indices = <int>[];

  FinampShuffleOrder({Random? random}) : _random = random ?? Random();

  @override
  void shuffle({int? initialIndex}) {
    assert(initialIndex == null || indices.contains(initialIndex));
    if (indices.length <= 1) return;
    indices.shuffle(_random);
    if (initialIndex == null) return;

    const initialPos = 0;
    final swapPos = indices.indexOf(initialIndex);
    // Swap the indices at initialPos and swapPos.
    final swapIndex = indices[initialPos];
    indices[initialPos] = initialIndex;
    indices[swapPos] = swapIndex;
  }

  @override
  void insert(int index, int count) {
    // Offset indices after insertion point.
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= index) {
        indices[i] += count;
      }
    }

    final newIndices = List.generate(count, (i) => index + i);
    // This is the only modification from DefaultShuffleOrder: Only shuffle
    // inserted indices amongst themselves, but keep them contiguous
    newIndices.shuffle(_random);
    indices.insertAll(index, newIndices);
  }

  @override
  void removeRange(int start, int end) {
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
  }

  @override
  void clear() {
    indices.clear();
  }
}

/// This provider handles the currently playing music so that multiple widgets
/// can control music.
class MusicPlayerBackgroundTask extends BaseAudioHandler {
  final _player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: FinampSettingsHelper.finampSettings.bufferDuration,
        maxBufferDuration: FinampSettingsHelper.finampSettings.bufferDuration,
        prioritizeTimeOverSizeThresholds: true,
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration:
            FinampSettingsHelper.finampSettings.bufferDuration,
      ),
    ),
  );
  
  final _skipControlSettings = SkipControlSettings();
  ConcatenatingAudioSource _queueAudioSource = ConcatenatingAudioSource(
    children: [],
    shuffleOrder: FinampShuffleOrder(),
  );
  final _audioServiceBackgroundTaskLogger = Logger("MusicPlayerBackgroundTask");
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _offlineListenLogHelper = GetIt.instance<OfflineListenLogHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  bool shuffleNextQueue = false;
  int? nextInitialIndex;
  bool _isStopping = false;
  bool _sleepTimerIsSet = false;
  Duration _sleepTimerDuration = Duration.zero;
  final ValueNotifier<Timer?> _sleepTimer = ValueNotifier<Timer?>(null);

  List<int>? get shuffleIndices => _player.shuffleIndices;
  ValueListenable<Timer?> get sleepTimer => _sleepTimer;

  MusicPlayerBackgroundTask() {
    _audioServiceBackgroundTaskLogger.info("Starting audio service");

    _player.playbackEventStream.listen((event) async {
      final prevState = playbackState.valueOrNull;
      final prevIndex = prevState?.queueIndex;
      final prevItem = mediaItem.valueOrNull;
      final currentState = _transformEvent(event);
      final currentIndex = currentState.queueIndex;

      playbackState.add(currentState);

      if (currentIndex != null) {
        final currentItem = _getQueueItem(currentIndex);

        if (currentIndex != prevIndex || currentItem.id != prevItem?.id) {
          mediaItem.add(currentItem);
          onTrackChanged(currentItem, currentState, prevItem, prevState);
        }
      }

      if (playbackState.valueOrNull != null &&
          playbackState.valueOrNull?.processingState != AudioProcessingState.idle &&
          playbackState.valueOrNull?.processingState != AudioProcessingState.completed &&
          !FinampSettingsHelper.finampSettings.isOffline &&
          !_isStopping) {
        await _updatePlaybackProgress();
      }
    });

    _player.processingStateStream.listen((event) {
      if (event == ProcessingState.completed) {
        stop();
      }
    });

    _player.shuffleModeEnabledStream.listen(
        (_) => playbackState.add(_transformEvent(_player.playbackEvent)));
    _player.loopModeStream.listen(
        (_) => playbackState.add(_transformEvent(_player.playbackEvent)));
  }

  @override
  Future<void> play() {
    // If a sleep timer has been set and the timer went off
    //  causing play to pause, if the user starts to play
    //  audio again, and the sleep timer hasn't been explicitly
    //  turned off, then reset the sleep timer.
    // This is useful if the sleep timer pauses play too early
    //  and the user wants to continue listening
    if (_sleepTimerIsSet && _sleepTimer.value == null) {
      // restart the sleep timer for another period
      setSleepTimer(_sleepTimerDuration);
    }

    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    try {
      _audioServiceBackgroundTaskLogger.info("Stopping audio service");

      _isStopping = true;

      // Tell Jellyfin we're no longer playing audio if we're online
      if (!FinampSettingsHelper.finampSettings.isOffline) {
        final playbackInfo = generateCurrentPlaybackProgressInfo();
        if (playbackInfo != null) {
          await _jellyfinApiHelper.stopPlaybackProgress(playbackInfo);
        }
      } else {
        final currentIndex = _player.currentIndex;
        if (_queueAudioSource.length != 0 && currentIndex != null) {
          final item = _getQueueItem(currentIndex);
          _offlineListenLogHelper.logOfflineListen(item);
        }
      }

      // Stop playing audio.
      await _player.stop();

      // Seek to the start of the first item in the queue
      await _player.seek(Duration.zero, index: 0);

      _sleepTimerIsSet = false;
      _sleepTimerDuration = Duration.zero;

      _sleepTimer.value?.cancel();
      _sleepTimer.value = null;

      await super.stop();

      // await _player.dispose();
      // await _eventSubscription?.cancel();
      // // It is important to wait for this state to be broadcast before we shut
      // // down the task. If we don't, the background task will be destroyed before
      // // the message gets sent to the UI.
      // await _broadcastState();
      // // Shut down this background task
      // await super.stop();

      _isStopping = false;
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  @Deprecated("Use addQueueItems instead")
  Future<void> addQueueItem(MediaItem mediaItem) async {
    addQueueItems([mediaItem]);
  }
  
  bool _shouldShowSkipControls(MediaItem mediaItem) {
    switch (_skipControlSettings.visibility) {
      case SkipButtonVisibility.always:
        return true;
      case SkipButtonVisibility.never:
        return false;
      case SkipButtonVisibility.automatic:
        return _shouldAutoShowSkipControls(mediaItem);
    }
  }

  /// Determine if skip controls should be automatically shown based on content
  bool _shouldAutoShowSkipControls(MediaItem mediaItem) {
    final duration = mediaItem.duration;
    final genre = mediaItem.genre?.toLowerCase();
    
    return (duration != null && duration > const Duration(minutes: 10)) ||
           (genre != null && (
             genre.contains('podcast') || 
             genre.contains('audiobook') ||
             genre.contains('speech')
           ));
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    try {
      final sources =
          await Future.wait(mediaItems.map((i) => _mediaItemToAudioSource(i)));
      await _queueAudioSource.addAll(sources);
      queue.add(_queueFromSource());
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  Future<void> insertQueueItemsNext(List<MediaItem> mediaItems) async {
    try {
      var idx = _player.currentIndex;
      if (idx != null) {
        if (_player.shuffleModeEnabled) {
          var next = _player.shuffleIndices?.indexOf(idx);
          idx = next == -1 || next == null ? null : next + 1;
        } else {
          ++idx;
        }
      }
      idx ??= 0;

      final sources =
          await Future.wait(mediaItems.map((i) => _mediaItemToAudioSource(i)));
      await _queueAudioSource.insertAll(idx, sources);
      queue.add(_queueFromSource());
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    try {
      // Convert the MediaItems to AudioSources
      List<AudioSource> audioSources = [];
      for (final mediaItem in newQueue) {
        audioSources.add(await _mediaItemToAudioSource(mediaItem));
      }

      // Create a new ConcatenatingAudioSource with the new queue.
      _queueAudioSource = ConcatenatingAudioSource(
        children: audioSources,
        shuffleOrder: FinampShuffleOrder(),
      );

      try {
        await _player.setAudioSource(
          _queueAudioSource,
          initialIndex: nextInitialIndex,
        );
      } on PlayerException catch (e) {
        _audioServiceBackgroundTaskLogger
            .severe("Player error code ${e.code}: ${e.message}");
      } on PlayerInterruptedException catch (e) {
        _audioServiceBackgroundTaskLogger
            .warning("Player interrupted: ${e.message}");
      } catch (e) {
        _audioServiceBackgroundTaskLogger
            .severe("Player error ${e.toString()}");
      }
      queue.add(_queueFromSource());

      // Sets the media item for the new queue. This will be whatever is
      // currently playing from the new queue (for example, the first song in
      // an album). If the player is shuffling, set the index to the player's
      // current index. Otherwise, set it to nextInitialIndex. nextInitialIndex
      // is much more stable than the current index as we know the value is set
      // when running this function.
      if (_player.shuffleModeEnabled) {
        if (_player.currentIndex == null) {
          _audioServiceBackgroundTaskLogger.severe(
              "_player.currentIndex is null during onUpdateQueue, not setting new media item");
        } else {
          mediaItem.add(_getQueueItem(_player.currentIndex!));
        }
      } else {
        if (nextInitialIndex == null) {
          _audioServiceBackgroundTaskLogger.severe(
              "nextInitialIndex is null during onUpdateQueue, not setting new media item");
        } else {
          mediaItem.add(_getQueueItem(nextInitialIndex!));
        }
      }

      shuffleNextQueue = false;
      nextInitialIndex = null;
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }
  
  Future<void> skipForward() async {
    try {
      final position = _player.position;
      final duration = _player.duration;
      
      if (duration != null) {
        final newPosition = position + _skipControlSettings.forwardSkipDuration;
        // Ensure we don't seek past the end
        await _player.seek(newPosition > duration ? duration : newPosition);
      }
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  /// Skip backward by the configured duration
  Future<void> skipBackward() async {
    try {
      final position = _player.position;
      final newPosition = position - _skipControlSettings.backwardSkipDuration;
      // Ensure we don't seek before the start
      await _player.seek(newPosition.isNegative ? Duration.zero : newPosition);
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (!_player.hasPrevious || _player.position.inSeconds >= 5) {
        await _player.seek(Duration.zero, index: _player.currentIndex);
      } else {
        await _player.seek(Duration.zero, index: _player.previousIndex);
      }
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      await _player.seekToNext();
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  Future<void> skipToIndex(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    try {
      switch (shuffleMode) {
        case AudioServiceShuffleMode.all:
          await _player.setShuffleModeEnabled(true);
          shuffleNextQueue = true;
          break;
        case AudioServiceShuffleMode.none:
          await _player.setShuffleModeEnabled(false);
          shuffleNextQueue = false;
          break;
        default:
          return Future.error(
              "Unsupported AudioServiceRepeatMode! Recieved ${shuffleMode.toString()}, requires all or none.");
      }
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    try {
      switch (repeatMode) {
        case AudioServiceRepeatMode.all:
          await _player.setLoopMode(LoopMode.all);
          break;
        case AudioServiceRepeatMode.none:
          await _player.setLoopMode(LoopMode.off);
          break;
        case AudioServiceRepeatMode.one:
          await _player.setLoopMode(LoopMode.one);
          break;
        default:
          return Future.error(
            "Unsupported AudioServiceRepeatMode! Received ${repeatMode.toString()}, requires all, none, or one.",
          );
      }
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    try {
      await _queueAudioSource.removeAt(index);
      queue.add(_queueFromSource());
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  /// Report track changes to the Jellyfin Server if the user is not offline.
  Future<void> onTrackChanged(
    MediaItem currentItem,
    PlaybackState currentState,
    MediaItem? previousItem,
    PlaybackState? previousState,
  ) async {
    final isOffline = FinampSettingsHelper.finampSettings.isOffline;

    if (previousItem != null &&
        previousState != null &&
        // don't submit stop events for idle tracks (at position 0 and not playing)
        (previousState.playing ||
            previousState.updatePosition != Duration.zero)) {
      if (!isOffline) {
        final playbackData = generatePlaybackProgressInfoFromState(
          previousItem,
          previousState,
        );

        if (playbackData != null) {
          try {
            await _jellyfinApiHelper.stopPlaybackProgress(playbackData);
          } catch (e) {
            _offlineListenLogHelper.logOfflineListen(previousItem);
          }
        }
      } else {
        _offlineListenLogHelper.logOfflineListen(previousItem);
      }
    }

    if (!isOffline) {
      final playbackData = generatePlaybackProgressInfoFromState(
        currentItem,
        currentState,
      );

      if (playbackData != null) {
        await _jellyfinApiHelper.reportPlaybackStart(playbackData);
      }
    }
  }

  /// Generates PlaybackProgressInfo for the supplied item and player info.
  PlaybackProgressInfo? generatePlaybackProgressInfo(
    MediaItem item, {
    required bool isPaused,
    required bool isMuted,
    required Duration playerPosition,
    required String repeatMode,
    required bool includeNowPlayingQueue,
  }) {
    try {
      return PlaybackProgressInfo(
        itemId: item.extras!["itemJson"]["Id"],
        isPaused: isPaused,
        isMuted: isMuted,
        positionTicks: playerPosition.inMicroseconds * 10,
        repeatMode: repeatMode,
        playMethod: item.extras!["shouldTranscode"] ?? false
            ? "Transcode"
            : "DirectPlay",
        // We don't send the queue since it seems useless and it can cause
        // issues with large queues.
        // https://github.com/jmshrv/finamp/issues/387

        // nowPlayingQueue: includeNowPlayingQueue
        //     ? _queueFromSource()
        //         .map(
        //           (e) => QueueItem(
        //               id: e.extras!["itemJson"]["Id"], playlistItemId: e.id),
        //         )
        //         .toList()
        //     : null,
      );
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      rethrow;
    }
  }

  /// Generates PlaybackProgressInfo from current player info.
  /// Returns null if _queue is empty.
  /// If an item is not supplied, the current queue index will be used.
  PlaybackProgressInfo? generateCurrentPlaybackProgressInfo() {
    final currentIndex = _player.currentIndex;
    if (_queueAudioSource.length == 0 || currentIndex == null) {
      // This function relies on _queue having items,
      // so we return null if it's empty or no index is played
      // and no custom item was passed to avoid more errors.
      return null;
    }
    final item = _getQueueItem(currentIndex);

    return generatePlaybackProgressInfo(
      item,
      isPaused: !_player.playing,
      isMuted: _player.volume == 0,
      playerPosition: _player.position,
      repeatMode: _jellyfinRepeatModeFromLoopMode(_player.loopMode),
      includeNowPlayingQueue: false,
    );
  }

  /// Generates PlaybackProgressInfo for the supplied item and playback state.
  PlaybackProgressInfo? generatePlaybackProgressInfoFromState(
    MediaItem item,
    PlaybackState state,
  ) {
    final duration = item.duration;
    return generatePlaybackProgressInfo(
      item,
      isPaused: !state.playing,
      // always consider as unmuted
      isMuted: false,
      // ensure the (extrapolated) position doesn't exceed the duration
      playerPosition: duration != null && state.position > duration
          ? duration
          : state.position,
      repeatMode: _jellyfinRepeatModeFromRepeatMode(state.repeatMode),
      includeNowPlayingQueue: true,
    );
  }

  void setNextInitialIndex(int index) {
    nextInitialIndex = index;
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    // When we're moving an item forwards, we need to reduce newIndex by 1
    // to account for the current item being removed before re-insertion.
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    await _queueAudioSource.move(oldIndex, newIndex);
    queue.add(_queueFromSource());
    _audioServiceBackgroundTaskLogger.log(Level.INFO, "Published queue");
  }

  /// Sets the sleep timer with the given [duration].
  Timer setSleepTimer(Duration duration) {
    _sleepTimerIsSet = true;
    _sleepTimerDuration = duration;

    _sleepTimer.value = Timer(duration, () async {
      _sleepTimer.value = null;
      return await pause();
    });
    return _sleepTimer.value!;
  }

  /// Cancels the sleep timer and clears it.
  void clearSleepTimer() {
    _sleepTimerIsSet = false;
    _sleepTimerDuration = Duration.zero;

    _sleepTimer.value?.cancel();
    _sleepTimer.value = null;
  }

  /// Transform a just_audio event into an audio_service state.
  ///
  /// This method is used from the constructor. Every event received from the
  /// just_audio player will be transformed into an audio_service state so that
  /// it can be broadcast to audio_service clients.
  PlaybackState _transformEvent(PlaybackEvent event) {
    final mediaItem = event.currentIndex != null 
        ? _getQueueItem(event.currentIndex!)
        : null;
    
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
    ];
    
    if (mediaItem != null && _shouldShowSkipControls(mediaItem)) {
      controls.add(MediaControl(
        androidIcon: 'drawable/ic_skip_back_10',
        label: 'Skip Back',
        action: skipBackward,
      ));
    }
    
    controls.addAll([
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
    ]);
    
    if (mediaItem != null && _shouldShowSkipControls(mediaItem)) {
      controls.add(MediaControl(
        androidIcon: 'drawable/ic_skip_forward_30',
        label: 'Skip Forward',
        action: skipForward,
      ));
    }
    
    controls.add(MediaControl.skipToNext);

    return PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 4], // Updated indices to account for skip controls
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: _audioServiceRepeatMode(_player.loopMode),
    );
}

  Future<void> _updatePlaybackProgress() async {
    try {
      JellyfinApiHelper jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

      final playbackInfo = generateCurrentPlaybackProgressInfo();
      if (playbackInfo != null) {
        await jellyfinApiHelper.updatePlaybackProgress(playbackInfo);
      }
    } catch (e) {
      _audioServiceBackgroundTaskLogger.severe(e);
      return Future.error(e);
    }
  }

  MediaItem _getQueueItem(int index) {
    return _queueAudioSource.sequence[index].tag as MediaItem;
  }

  List<MediaItem> _queueFromSource() {
    return _queueAudioSource.sequence.map((e) => e.tag as MediaItem).toList();
  }

  /// Syncs the list of MediaItems (_queue) with the internal queue of the player.
  /// Called by onAddQueueItem and onUpdateQueue.
  Future<AudioSource> _mediaItemToAudioSource(MediaItem mediaItem) async {
    if (mediaItem.extras!["downloadedSongJson"] == null) {
      // If DownloadedSong wasn't passed, we assume that the item is not
      // downloaded.

      // If offline, we throw an error so that we don't accidentally stream from
      // the internet. See the big comment in _songUri() to see why this was
      // passed in extras.
      if (mediaItem.extras!["isOffline"]) {
        return Future.error(
            "Offline mode enabled but downloaded song not found.");
      } else {
        if (mediaItem.extras!["shouldTranscode"] == true) {
          return HlsAudioSource(await _songUri(mediaItem), tag: mediaItem);
        } else {
          return AudioSource.uri(await _songUri(mediaItem), tag: mediaItem);
        }
      }
    } else {
      // We have to deserialize this because Dart is stupid and can't handle
      // sending classes through isolates.
      final downloadedSong =
          DownloadedSong.fromJson(mediaItem.extras!["downloadedSongJson"]);

      // Path verification and stuff is done in AudioServiceHelper, so this path
      // should be valid.
      final downloadUri = Uri.file(downloadedSong.file.path);
      return AudioSource.uri(downloadUri, tag: mediaItem);
    }
  }

  Future<Uri> _songUri(MediaItem mediaItem) async {
    // We need the platform to be Android or iOS to get device info
    assert(Platform.isAndroid || Platform.isIOS,
        "_songUri() only supports Android and iOS");

    // When creating the MediaItem (usually in AudioServiceHelper), we specify
    // whether or not to transcode. We used to pull from FinampSettings here,
    // but since audio_service runs in an isolate (or at least, it does until
    // 0.18), the value would be wrong if changed while a song was playing since
    // Hive is bad at multi-isolate stuff.

    final androidId =
        Platform.isAndroid ? await const AndroidId().getId() : null;
    final iosDeviceInfo =
        Platform.isIOS ? await DeviceInfoPlugin().iosInfo : null;

    final parsedBaseUrl = Uri.parse(_finampUserHelper.currentUser!.baseUrl);

    List<String> builtPath = List.from(parsedBaseUrl.pathSegments);

    Map<String, String> queryParameters =
        Map.from(parsedBaseUrl.queryParameters);

    // We include the user token as a query parameter because just_audio used to
    // have issues with headers in HLS, and this solution still works fine
    queryParameters["ApiKey"] = _finampUserHelper.currentUser!.accessToken;

    if (mediaItem.extras!["shouldTranscode"]) {
      builtPath.addAll([
        "Audio",
        mediaItem.extras!["itemJson"]["Id"],
        "main.m3u8",
      ]);

      queryParameters.addAll({
        "audioCodec": "aac",
        // Ideally we'd use 48kHz when the source is, realistically it doesn't
        // matter too much
        "audioSampleRate": "44100",
        "maxAudioBitDepth": "16",
        "audioBitRate":
            FinampSettingsHelper.finampSettings.transcodeBitrate.toString(),
      });
    } else {
      builtPath.addAll([
        "Items",
        mediaItem.extras!["itemJson"]["Id"],
        "File",
      ]);
    }

    return Uri(
      host: parsedBaseUrl.host,
      port: parsedBaseUrl.port,
      scheme: parsedBaseUrl.scheme,
      userInfo: parsedBaseUrl.userInfo,
      pathSegments: builtPath,
      queryParameters: queryParameters,
    );
  }
}

AudioServiceRepeatMode _audioServiceRepeatMode(LoopMode loopMode) {
  switch (loopMode) {
    case LoopMode.off:
      return AudioServiceRepeatMode.none;
    case LoopMode.one:
      return AudioServiceRepeatMode.one;
    case LoopMode.all:
      return AudioServiceRepeatMode.all;
  }
}

String _jellyfinRepeatModeFromLoopMode(LoopMode loopMode) {
  switch (loopMode) {
    case LoopMode.off:
      return "RepeatNone";
    case LoopMode.one:
      return "RepeatOne";
    case LoopMode.all:
      return "RepeatAll";
  }
}

String _jellyfinRepeatModeFromRepeatMode(AudioServiceRepeatMode repeatMode) {
  switch (repeatMode) {
    case AudioServiceRepeatMode.none:
      return "RepeatNone";
    case AudioServiceRepeatMode.one:
      return "RepeatOne";
    case AudioServiceRepeatMode.all:
    case AudioServiceRepeatMode.group:
      return "RepeatAll";
  }
}
