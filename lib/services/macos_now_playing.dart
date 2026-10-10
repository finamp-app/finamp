import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// Publishes complete snapshots from the handler, including null media items.
///
/// The stock platform adapter ignores null items and publishes item/state changes
/// separately. Replacing it on macOS keeps a single owner of the native center.
class MacosNowPlaying extends AudioServicePlatform {
  static const channel = MethodChannel('com.unicornsonlsd.finamp/now_playing');
  final _logger = Logger('MacosNowPlaying');
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _scheduled = false;

  void attach(AudioHandler handler) {
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'play':
          await handler.play();
        case 'pause':
          await handler.pause();
        case 'toggle':
          if (handler.playbackState.value.playing) {
            await handler.pause();
          } else {
            await handler.play();
          }
        case 'next':
          await handler.skipToNext();
        case 'previous':
          await handler.skipToPrevious();
        case 'seek':
          final seconds = (call.arguments as num).toDouble();
          if (!seconds.isFinite || seconds < 0) {
            throw PlatformException(code: 'invalid_position');
          }
          await handler.seek(Duration(microseconds: (seconds * 1000000).round()));
        default:
          throw MissingPluginException('Unknown Now Playing command: ${call.method}');
      }
    });

    void schedulePublish(dynamic _) {
      if (_scheduled) return;
      _scheduled = true;
      scheduleMicrotask(() async {
        _scheduled = false;
        try {
          await channel.invokeMethod<void>('publish', snapshot(handler.mediaItem.value, handler.playbackState.value));
        } catch (error, stack) {
          _logger.warning('Could not publish macOS Now Playing', error, stack);
        }
      });
    }

    _subscriptions.add(handler.mediaItem.listen(schedulePublish));
    _subscriptions.add(handler.playbackState.listen(schedulePublish));
  }

  static Map<String, Object?>? snapshot(MediaItem? item, PlaybackState state) {
    if (item == null) return null;
    final advancing = state.playing && state.processingState == AudioProcessingState.ready;
    final duration = item.duration?.inMicroseconds;
    final validSpeed = state.speed.isFinite && state.speed > 0;
    final position = (advancing && validSpeed ? state.position : state.updatePosition).inMicroseconds;
    final actions = {...state.systemActions, ...state.controls.map((control) => control.action)};
    return {
      'id': item.id,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'duration': duration != null && duration > 0 ? duration / 1000000 : null,
      'elapsed': position < 0 ? 0.0 : position / 1000000,
      'rate': advancing && validSpeed ? state.speed : 0.0,
      'state': switch (state.processingState) {
        AudioProcessingState.idle || AudioProcessingState.completed => 'stopped',
        _ => advancing ? 'playing' : 'paused',
      },
      // Artwork is already downloaded by Finamp's authenticated image cache.
      'artPath': item.artUri?.scheme == 'file' ? item.artUri!.toFilePath() : null,
      'canPlay': actions.contains(MediaAction.play) || actions.contains(MediaAction.pause),
      'canNext': actions.contains(MediaAction.skipToNext),
      'canPrevious': actions.contains(MediaAction.skipToPrevious),
      'canSeek': actions.contains(MediaAction.seek) && duration != null && duration > 0,
    };
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    channel.setMethodCallHandler(null);
    await channel.invokeMethod<void>('publish');
  }

  // AudioService still initializes its shared handler/position streams. Native
  // publication and commands use the complete snapshots above instead.
  @override
  Future<void> configure(ConfigureRequest request) async {}
  @override
  Future<void> setState(SetStateRequest request) async {}
  @override
  Future<void> setMediaItem(SetMediaItemRequest request) async {}
  @override
  Future<void> setQueue(SetQueueRequest request) async {}
  @override
  Future<void> stopService(StopServiceRequest request) async {}
  @override
  Future<void> notifyChildrenChanged(NotifyChildrenChangedRequest request) async {}
  @override
  void setHandlerCallbacks(AudioHandlerCallbacks callbacks) {}
}
