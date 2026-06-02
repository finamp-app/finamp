import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:finamp/services/favorite_provider.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/album_image_provider.dart';

import 'package:logging/logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:home_widget/home_widget.dart';
import 'package:audio_service/audio_service.dart';

class HomeScreenWidget {
  static final _logger = Logger("HomeScreenWidget");
  static final _providers = GetIt.instance<ProviderContainer>();
  static final _queueService = GetIt.instance<QueueService>();
  static final _audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

  static void initialize() {
    HomeWidget.registerInteractivityCallback(_userInteraction);

    final receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping("main_audio_handler");
    IsolateNameServer.registerPortWithName(receivePort.sendPort, "main_audio_handler");

    // receives the command from the widget and excutes the action
    receivePort.listen((message) async {
      _logger.info("command from home widget received: ${message}");
      // These must match the Strings defined in MediaControls
      switch (message) {
        case "skip_previous":
          return await _audioHandler.skipToPrevious();
        case "skip_next":
          return await _audioHandler.skipToNext();
        case "pause":
          return await _audioHandler.pause();
        case "play":
          return await _audioHandler.play();
        case "favorite_toggle":
          return await _audioHandler.customAction("toggleFavorite");
        case "shuffle_toggle":
          return await _audioHandler.customAction("shuffle");
        case "toggle_loop":
          return await _audioHandler.customAction("toggleLoopMode");
      }
    });

    // This handles updates on play/pause/favorite actions
    _audioHandler.playbackState.listen(_updatePlaybackState);

    // Listens for changes to loop mode and updates the widget
    _queueService.getLoopModeStream().listen(_updateLoopMode);

    // This runs when a new tracks plays or shuffle mode is toggled
    _queueService.getCurrentTrackStream().listen(_updateAllData);
  }

  // Updates favorite and playing status on PlaybackState change
  static Future<void> _updatePlaybackState(PlaybackState? state) async {
    if (state?.processingState != AudioProcessingState.ready || !await isInstalled()) {
      return;
    }

    _logger.info("updating playing/favorite data");

    await HomeWidget.saveWidgetData("playing", !_audioHandler.paused);
    final currentTrack = _queueService.getCurrentTrack();
    final isFavorite = _providers.read(isFavoriteProvider(currentTrack?.baseItem));
    await HomeWidget.saveWidgetData("favorited", isFavorite);
    await HomeScreenWidget.reloadWidget();
  }

  // Update on LoopMode changes
  static Future<void> _updateLoopMode(FinampLoopMode loopMode) async {
    if (!await isInstalled()) {
      return;
    }
    _logger.info("updating loop mode");

    await HomeWidget.saveWidgetData("repeatMode", loopMode.name);
    await HomeScreenWidget.reloadWidget();
  }

  // Saves all data on new track
  static Future<void> _updateAllData(FinampQueueItem? currentTrack) async {
    if (!await isInstalled()) {
      return;
    }

    _logger.info("updating all data");

    // Save audio player states
    await HomeWidget.saveWidgetData("playing", !_audioHandler.paused);
    await HomeWidget.saveWidgetData("repeatMode", _queueService.loopMode.name);
    await HomeWidget.saveWidgetData("shuffled", _audioHandler.shuffled);

    if (currentTrack == null) {
      return;
    }

    // Save now playing info
    await HomeWidget.saveWidgetData("arist", currentTrack.item.artist);
    await HomeWidget.saveWidgetData("album", currentTrack.item.album);
    await HomeWidget.saveWidgetData("title", currentTrack.item.title);

    // Save current album art
    final request = AlbumImageRequest(item: currentTrack.baseItem);
    final albumImage = _providers.refresh(albumImageProvider(request));
    FinampImage track = albumImage.asTheme(ThemeInfo(currentTrack.baseItem, useIsolate: true));
    var art = track.image;
    if (art != null) {
      await HomeWidget.saveImage("albumArt", art);
      _logger.info("saved album art");
    }

    // Save favorite status
    final isFavorite = _providers.read(isFavoriteProvider(currentTrack.baseItem));
    await HomeWidget.saveWidgetData("favorited", isFavorite);

    await HomeScreenWidget.reloadWidget();
  }

  static Future<void> reloadWidget() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: "com.unicornsonlsd.finamp.widget.receiver.CircularWidgetReceiver");
    await HomeWidget.updateWidget(qualifiedAndroidName: "com.unicornsonlsd.finamp.widget.receiver.RectangularWidgetReceiver");
  }

  static Future<bool> isInstalled() async {
    final List<HomeWidgetInfo> info = await HomeWidget.getInstalledWidgets();
    return info.isNotEmpty;
  }
}

// Called when the user clicks on the widget
// sends the command over a port so it can excute with the main audio handler
// Using an IsolatedAudioHandler here was getting this error
// https://github.com/ryanheise/audio_service/issues/817
@pragma("vm:entry-point")
FutureOr<void> _userInteraction(Uri? data) async {
  if (data == null) {
    return;
  }
  final SendPort? sendPort = IsolateNameServer.lookupPortByName("main_audio_handler");
  sendPort?.send(data.host);
}
