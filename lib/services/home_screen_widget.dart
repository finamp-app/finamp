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
        case "repeat_increment":
          return await _audioHandler.customAction("incrementRepeat");
      }
    });

    // Update the widget data when there's MediaItem or PlaybackState changed
    _audioHandler.mediaItem.listen((MediaItem? item) {
      HomeScreenWidget.updateWidgetData();
      HomeScreenWidget.reloadWidget();
    });

    _audioHandler.playbackState.listen((PlaybackState? state) {
      // Does this run unnecessarily?
      HomeScreenWidget.updateWidgetData();
      HomeScreenWidget.reloadWidget();
    });

    _queueService.getLoopModeStream().listen((FinampLoopMode loopMode) {
      HomeWidget.saveWidgetData("repeatMode", loopMode.name);
      HomeScreenWidget.reloadWidget();
    });
  }

  // The save data keys needs to match the values in SharedComponents
  static Future<void> updateWidgetData() async {
    // Save audio player states
    await HomeWidget.saveWidgetData("playing", !_audioHandler.paused);
    await HomeWidget.saveWidgetData("repeatMode", _queueService.loopMode.name);
    await HomeWidget.saveWidgetData("shuffled", _audioHandler.shuffled);

    final currentTrack = _queueService.getCurrentTrack();
    if (currentTrack == null) {
      return;
    }
    final isFavorite = _providers.read(isFavoriteProvider(currentTrack.baseItem));
    await HomeWidget.saveWidgetData("favorited", isFavorite);

    // Save current album art
    final request = AlbumImageRequest(item: currentTrack.baseItem);
    final albumImage = _providers.refresh(albumImageProvider(request));
    FinampImage track = albumImage.asTheme(ThemeInfo(currentTrack.baseItem, useIsolate: true));
    var art = track.image;
    if (art != null) {
      await HomeWidget.saveImage("albumArt", art);
      _logger.info("saved album art");
    }

    // Save now playing info
    await HomeWidget.saveWidgetData("arist", currentTrack.item.artist);
    await HomeWidget.saveWidgetData("album", currentTrack.item.album);
    await HomeWidget.saveWidgetData("title", currentTrack.item.title);
  }

  static void reloadWidget() {
    HomeWidget.updateWidget(qualifiedAndroidName: "com.unicornsonlsd.finamp.widget.receiver.CircularWidgetReceiver");
    HomeWidget.updateWidget(qualifiedAndroidName: "com.unicornsonlsd.finamp.widget.receiver.RectangularWidgetReceiver");
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
