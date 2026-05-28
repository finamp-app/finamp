import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

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
      _logger.info("message received: ${message}");
      // These must match the Strings defined in PlayerAction
      switch (message) {
        case "skip_previous":
          await _audioHandler.skipToPrevious();
          break;
        case "skip_next":
          await _audioHandler.skipToNext();
          break;
        case "pause":
          await _audioHandler.pause();
          break;
        case "play":
          await _audioHandler.play();
          break;
        case "favorite_toggle":
          await _audioHandler.toggleFavoriteStatusOfCurrentTrack();
          await HomeScreenWidget.saveFavorite();
          break;
      }
    });

    // Save the now playing info when the item changes
    _audioHandler.mediaItem.listen((MediaItem? item) {
      _logger.info("updated to media item ${item}");
      HomeScreenWidget.saveFavorite();
      HomeScreenWidget.saveNowPlaying();
      HomeScreenWidget.reloadWidget();
    });

    _audioHandler.playbackState.listen((PlaybackState? state) {
      _logger.info("playbackState changed ${state}");
      // Does this run unnecessarily?
      HomeWidget.saveWidgetData("playing", state?.playing);
      HomeScreenWidget.reloadWidget();
    });
  }

  static void reloadWidget() {
    HomeWidget.updateWidget(qualifiedAndroidName: "com.unicornsonlsd.finamp.widget.receiver.CircularWidgetReceiver");
    HomeWidget.updateWidget(qualifiedAndroidName: "com.unicornsonlsd.finamp.widget.receiver.RectangularWidgetReceiver");
  }

  static Future<void> saveFavorite() async {
    final currentTrack = _queueService.getCurrentTrack();
    if (currentTrack == null) {
      return;
    }
    final isFavorite = _providers.read(isFavoriteProvider(currentTrack.baseItem));
    await HomeWidget.saveWidgetData("favorited", isFavorite);
  }

  static Future<void> saveNowPlaying() async {
    final currentTrack = _queueService.getCurrentTrack();
    if (currentTrack == null) {
      return;
    }
    _logger.info('started album art saving for: ${currentTrack.item.album} ${currentTrack.item.title}');

    final request = AlbumImageRequest(item: currentTrack.baseItem);
    final albumImage = _providers.refresh(albumImageProvider(request));
    FinampImage track = albumImage.asTheme(ThemeInfo(currentTrack.baseItem, useIsolate: true));
    var art = track.image;
    if (art != null) {
      await HomeWidget.saveImage("albumArt", art);
      _logger.info("saved album art");
    }
  }
}

// called when the user clicks on the widget
// sends the command over a port so it can excute with the main audio handler
@pragma("vm:entry-point")
FutureOr<void> _userInteraction(Uri? data) async {
  if (data == null) {
    return;
  }
  final SendPort? sendPort = IsolateNameServer.lookupPortByName("main_audio_handler");
  sendPort?.send(data.host);
}
