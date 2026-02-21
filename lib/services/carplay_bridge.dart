import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'music_player_background_task.dart';

class CarPlayBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.unicornsonlsd.finamp/carplay',
  );
  static final Logger _log = Logger("CarPlayBridge");
  static StreamSubscription<MediaItem?>? _mediaItemSubscription;
  static StreamSubscription<PlaybackState>? _playbackStateSubscription;
  static bool _syncRegistered = false;
  static String? _lastSyncedFingerprint;

  static Future<void> initialize() async {
    if (!Platform.isIOS) {
      return;
    }

    _channel.setMethodCallHandler(_onMethodCall);
    _log.info("Initialized CarPlay method channel bridge");
    _registerNowPlayingSync();
  }

  static Future<dynamic> _onMethodCall(MethodCall call) async {
    if (!GetIt.instance.isRegistered<MusicPlayerBackgroundTask>()) {
      throw PlatformException(
        code: "unavailable",
        message: "Audio handler is not initialized yet.",
      );
    }

    final handler = GetIt.instance<MusicPlayerBackgroundTask>();

    switch (call.method) {
      case "getRootItems":
        return _serializeMediaItems(
          await handler.getChildren(AudioService.browsableRootId),
        );
      case "getChildren":
        final parentMediaId = _getRequiredStringArgument(
          call.arguments,
          "parentMediaId",
        );
        return _serializeMediaItems(await handler.getChildren(parentMediaId));
      case "playFromMediaId":
        final mediaId = _getRequiredStringArgument(call.arguments, "mediaId");
        await handler.playFromMediaId(mediaId);
        return null;
      default:
        throw MissingPluginException("Unknown method '${call.method}'");
    }
  }

  static String _getRequiredStringArgument(dynamic arguments, String key) {
    if (arguments is! Map) {
      throw PlatformException(
        code: "invalid-args",
        message: "Arguments must be a map.",
      );
    }

    final value = arguments[key];
    if (value is! String || value.isEmpty) {
      throw PlatformException(
        code: "invalid-args",
        message: "Missing or invalid '$key'.",
      );
    }
    return value;
  }

  static List<Map<String, dynamic>> _serializeMediaItems(
    List<MediaItem> items,
  ) {
    return items.map((item) {
      final subtitleParts = <String>[
        if ((item.artist ?? "").isNotEmpty) item.artist!,
        if ((item.album ?? "").isNotEmpty) item.album!,
      ];

      return {
        "id": item.id,
        "title": item.title,
        "subtitle": subtitleParts.isEmpty ? null : subtitleParts.join(" • "),
        "playable": item.playable,
      };
    }).toList();
  }

  static void _registerNowPlayingSync() {
    if (_syncRegistered ||
        _mediaItemSubscription != null ||
        _playbackStateSubscription != null) {
      return;
    }
    if (!GetIt.instance.isRegistered<MusicPlayerBackgroundTask>()) {
      _log.warning("Audio handler not available for now playing sync");
      return;
    }

    final handler = GetIt.instance<MusicPlayerBackgroundTask>();

    _mediaItemSubscription = handler.mediaItem.listen((_) {
      _syncNowPlayingState(handler);
    });
    _playbackStateSubscription = handler.playbackState.listen((_) {
      _syncNowPlayingState(handler);
    });

    _syncRegistered = true;
    _syncNowPlayingState(handler);
  }

  static void _syncNowPlayingState(MusicPlayerBackgroundTask handler) {
    final mediaItem = handler.mediaItem.valueOrNull;
    final playbackState = handler.playbackState.valueOrNull;

    final payload = <String, dynamic>{
      "playing": playbackState?.playing ?? false,
      "speed": playbackState?.speed ?? 1.0,
      "positionMs": playbackState?.updatePosition.inMilliseconds ?? 0,
      "title": mediaItem?.title,
      "artist": mediaItem?.artist,
      "album": mediaItem?.album,
      "durationMs": mediaItem?.duration?.inMilliseconds,
    };

    final fingerprint = [
      payload["playing"],
      payload["speed"],
      payload["positionMs"],
      payload["title"],
      payload["artist"],
      payload["album"],
      payload["durationMs"],
    ].join("|");

    if (fingerprint == _lastSyncedFingerprint) {
      return;
    }
    _lastSyncedFingerprint = fingerprint;

    unawaited(
      _channel.invokeMethod<void>("syncNowPlayingState", payload).catchError((Object error, StackTrace stackTrace) {
        _log.finer("syncNowPlayingState failed: $error");
      }),
    );
  }
}
